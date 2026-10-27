import hashlib
import logging
import threading
from pathlib import Path

def start_mpris(engine):
    thread = threading.Thread(target=_run, args=(engine,), daemon=True, name='music-mpris')
    thread.start()
    return thread

def _run(engine):
    try:
        import dbus
        import dbus.service
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
        from player import cover_path, cover_uri
        DBusGMainLoop(set_as_default=True)
        bus = dbus.SessionBus()
        player_iface = 'org.mpris.MediaPlayer2.Player'
        root_iface = 'org.mpris.MediaPlayer2'
        props_iface = 'org.freedesktop.DBus.Properties'
        name = dbus.service.BusName('org.mpris.MediaPlayer2.y_music', bus=bus, do_not_queue=True)

        class Player(dbus.service.Object):
            def __init__(self):
                super().__init__(name, '/org/mpris/MediaPlayer2')
                self.previous = None

            def properties(self):
                state = engine.execute('state')
                path = state['path']
                tags = state['metadata']
                track_id = '/org/mpris/MediaPlayer2/track/' + hashlib.sha256(path.encode()).hexdigest()
                metadata = dbus.Dictionary({}, signature='sv')
                if path:
                    metadata.update({
                        'mpris:trackid': dbus.ObjectPath(track_id),
                        'mpris:length': dbus.Int64(state['duration'] * 1_000_000),
                        'xesam:url': Path(path).as_uri(),
                        'xesam:title': tags.get('TITLE') or tags.get('title') or Path(path).stem,
                        'xesam:artist': dbus.Array([tags.get('ARTIST') or tags.get('artist') or ''], signature='s'),
                        'xesam:album': tags.get('ALBUM') or tags.get('album') or '',
                    })
                    cover = cover_path(path)
                    if cover.is_file():
                        metadata['mpris:artUrl'] = cover_uri(cover)
                return {
                    'PlaybackStatus': 'Stopped' if not path else 'Paused' if state['paused'] else 'Playing',
                    'LoopStatus': engine.loop, 'Rate': dbus.Double(1), 'Shuffle': engine.shuffle,
                    'Metadata': metadata, 'Volume': dbus.Double(state['volume'] / 100),
                    'Position': dbus.Int64(state['position'] * 1_000_000),
                    'MinimumRate': dbus.Double(1), 'MaximumRate': dbus.Double(1),
                    'CanGoNext': bool(engine.queue), 'CanGoPrevious': bool(engine.queue),
                    'CanPlay': bool(engine.queue), 'CanPause': True, 'CanSeek': bool(path), 'CanControl': True,
                }

            @dbus.service.method(props_iface, in_signature='ss', out_signature='v')
            def Get(self, interface, prop):
                return self.GetAll(interface)[prop]

            @dbus.service.method(props_iface, in_signature='s', out_signature='a{sv}')
            def GetAll(self, interface):
                if interface == player_iface:
                    return self.properties()
                if interface == root_iface:
                    return {'CanQuit': False, 'CanRaise': False, 'HasTrackList': False,
                            'Identity': 'Music', 'SupportedUriSchemes': dbus.Array(['file'], signature='s'),
                            'SupportedMimeTypes': dbus.Array(['audio/mpeg', 'audio/flac', 'audio/ogg'], signature='s')}
                return {}

            @dbus.service.method(props_iface, in_signature='ssv', out_signature='')
            def Set(self, interface, prop, value):
                if interface == player_iface and prop == 'Volume':
                    engine.execute('volume', float(value) * 100)
                elif interface == player_iface and prop == 'Shuffle':
                    engine.execute('shuffle', bool(value))
                elif interface == player_iface and prop == 'LoopStatus' and value in ('None', 'Track', 'Playlist'):
                    with engine.lock:
                        engine.loop = str(value)

            @dbus.service.signal(props_iface, signature='sa{sv}as')
            def PropertiesChanged(self, interface, changed, invalidated):
                pass

            @dbus.service.signal(player_iface, signature='x')
            def Seeked(self, position):
                pass

            @dbus.service.method(player_iface)
            def Next(self): engine.execute('next')

            @dbus.service.method(player_iface)
            def Previous(self): engine.execute('previous')

            @dbus.service.method(player_iface)
            def PlayPause(self): engine.execute('toggle')

            @dbus.service.method(player_iface)
            def Play(self): engine.execute('resume')

            @dbus.service.method(player_iface)
            def Pause(self): engine.execute('pause')

            @dbus.service.method(player_iface)
            def Stop(self): engine.execute('stop')

            @dbus.service.method(player_iface, in_signature='x')
            def Seek(self, offset):
                state = engine.execute('state')
                position = state['position'] + int(offset) / 1_000_000
                engine.execute('seek', position)
                self.Seeked(dbus.Int64(max(0, position) * 1_000_000))

            @dbus.service.method(player_iface, in_signature='ox')
            def SetPosition(self, track, position):
                if track == self.properties()['Metadata'].get('mpris:trackid'):
                    engine.execute('seek', int(position) / 1_000_000)
                    self.Seeked(dbus.Int64(position))

            def publish(self):
                if not engine.running:
                    loop.quit()
                    return False
                try:
                    values = self.properties()
                    values.pop('Position')
                    changed = {key: value for key, value in values.items()
                               if self.previous is None or self.previous.get(key) != value}
                    if changed:
                        self.PropertiesChanged(player_iface, changed, [])
                    self.previous = values
                except Exception:
                    logging.exception('Could not update media controls')
                return True

        player = Player()
        loop = GLib.MainLoop()
        GLib.timeout_add(500, player.publish)
        logging.info('Media controls registered as y_music')
        loop.run()
    except Exception:
        logging.exception('Could not register media controls')
