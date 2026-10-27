import array
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
import logging
import math
import os
import random
from pathlib import Path
import signal
import socket
import socketserver
import statistics
import subprocess
import threading
import time

RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
SOCKET = RUNTIME / 'y-music-engine.sock'
CACHE = Path.home() / '.cache/omarchy/local-music'
LIBRARY = Path.home() / '0/music'
FADE_SECONDS = 5.0

def boundaries(path):

    source = Path(path)
    stat = source.stat()
    signature = [stat.st_mtime_ns, stat.st_size]
    key = hashlib.sha256(str(source.resolve()).encode()).hexdigest()
    cached = CACHE / 'boundaries' / f'{key}.json'
    try:
        record = json.loads(cached.read_text())
        if record['signature'] == signature:
            return record['start'], record['end']
    except (OSError, ValueError, KeyError, TypeError):
        pass
    from mutagen import File
    audio = File(source)
    duration = float(audio.info.length)
    window = min(30, duration)

    def levels(start):
        raw = subprocess.check_output([
            'ffmpeg', '-nostdin', '-v', 'error', '-ss', str(start), '-i', str(source),
            '-t', str(window), '-ac', '2', '-ar', '2000', '-f', 's16le', '-',
        ], stderr=subprocess.DEVNULL, timeout=15)
        samples = array.array('h')
        samples.frombytes(raw)
        envelope = []
        for offset in range(0, len(samples), 1000):
            segment = samples[offset:offset + 1000]
            rms = math.sqrt(sum(value * value for value in segment) / len(segment)) / 32768
            envelope.append(20 * math.log10(max(rms, 1e-8)))
        return envelope

    start, end = 0.0, duration
    head = levels(0)
    reference = [v for v in head[len(head) // 2:] if v > -60]
    if reference:
        threshold = max(-50, statistics.median(reference) - 5)
        onset = next((i for i in range(len(head) - 2)
                      if all(v >= threshold for v in head[i:i + 3])), 0)
        start = max(0, onset * 0.25 - 0.15)
    tail = levels(duration - window)
    reference = [v for v in tail[:len(tail) // 2] if v > -60]
    if reference:
        threshold = max(-50, statistics.median(reference) - 5)
        cutoff = next((i for i in range(len(tail) // 2, len(tail) - 3)
                       if all(v < threshold for v in tail[i:i + 4])), len(tail))
        end = min(duration, duration - window + cutoff * 0.25)
    if end <= start:
        start, end = 0.0, duration
    cached.parent.mkdir(parents=True, exist_ok=True)
    temporary = cached.with_suffix(f'.{os.getpid()}.tmp')
    temporary.write_text(json.dumps({'signature': signature, 'start': start, 'end': end}))
    temporary.replace(cached)
    return start, end

class IPC:
    def __init__(self, path):
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.settimeout(1)
        self.socket.connect(str(path))
        self.stream = self.socket.makefile('r')
        self.sequence = 0

    def command(self, *args):
        self.sequence += 1
        self.socket.sendall((json.dumps({'command': args, 'request_id': self.sequence}) + '\n').encode())
        while line := self.stream.readline():
            reply = json.loads(line)
            if reply.get('request_id') == self.sequence:
                return reply.get('data')
        raise ConnectionError('Audio deck disconnected')

    def close(self):
        self.stream.close()
        self.socket.close()

class Deck:
    def __init__(self, path, audio_output=None):
        self.path = path
        args = ['mpv', '--no-config', '--no-video', '--audio-display=no', '--idle=yes',
                '--terminal=no', '--pause=yes', '--keep-open=yes', '--volume=0',
                '--audio-client-name=y.music', f'--input-ipc-server={path}']

        scrobbler = Path.home() / '.config/mpv/scripts/scrobbler.lua'
        if scrobbler.is_file():
            args.append(f'--script={scrobbler}')
        if audio_output:
            args.append(f'--ao={audio_output}')
        self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                try:
                    self.ipc = IPC(path)
                    break
                except OSError:
                    if self.process.poll() is not None:
                        raise RuntimeError('Audio deck failed to start')
                    time.sleep(0.03)
            else:
                raise RuntimeError('Audio deck startup timed out')
        except Exception:
            self.process.terminate()
            self.process.wait(timeout=3)
            raise
        self.duration = 0.0
        self.metadata = {}
        self.filename = ''

    def command(self, *args):
        return self.ipc.command(*args)

    def set(self, name, value):
        self.command('set_property', name, value)

    def get(self, name):
        return self.command('get_property', name)

    def load(self, path, start=0):
        self.set('pause', True)
        self.set('volume', 0)
        self.command('loadfile', path, 'replace', -1, {'start': str(start)})
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if self.get('path') == path and self.get('time-pos') is not None:
                self.set('ao-volume', 100)
                self.duration = float(self.get('duration') or 0)
                self.metadata = self.get('metadata') or {}
                self.filename = path
                return
            time.sleep(0.015)
        self.command('stop')
        raise RuntimeError(f'Cannot load audio: {path}')

    def stop(self):
        self.set('volume', 0)
        self.set('pause', True)
        self.command('stop')
        self.filename = ''

    def close(self):
        try:
            self.command('quit')
        except (OSError, ConnectionError):
            pass
        self.ipc.close()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.path.unlink(missing_ok=True)

class Engine:
    def __init__(self, runtime=RUNTIME, library=LIBRARY, audio_output=None,
                 fade_seconds=FADE_SECONDS, analyze=True):
        self.lock = threading.RLock()
        self.library = Path(library).resolve()
        self.audio_output = audio_output
        self.decks = []
        try:
            for index in range(2):
                self.decks.append(Deck(Path(runtime) / f'y-music-deck-{index}.sock', audio_output))
        except Exception:
            self.close()
            raise
        self.active = 0
        self.queue = []
        self.ordered_queue = []
        from player import preferences
        self.shuffle = preferences()["shuffle"]
        self.index = -1
        self.volume = 60.0
        self.paused = True
        self.fade_seconds = fade_seconds
        self.fade = None
        self.prepared = None
        self.position = 0.0
        self.loop = 'Playlist'
        self.running = True
        self.pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix='music-boundaries')
        self.analysis = {}
        self.analysis_signatures = {}
        self.analyze = analyze

    @property
    def deck(self):
        return self.decks[self.active]

    def schedule_analysis(self):
        if not self.analyze or not self.queue:
            return
        wanted = list(dict.fromkeys([self.queue[self.index], self.queue[(self.index + 1) % len(self.queue)]]))
        for path, future in list(self.analysis.items()):
            if path not in wanted and not future.done() and future.cancel():
                del self.analysis[path]
        for path in wanted:
            try:
                stat = Path(path).stat()
            except OSError:
                continue
            signature = (stat.st_mtime_ns, stat.st_size)
            if path not in self.analysis or self.analysis_signatures.get(path) != signature:
                self.analysis_signatures[path] = signature
                self.analysis[path] = self.pool.submit(boundaries, path)

    def edge(self, path, duration):
        future = self.analysis.get(path)
        if future and future.done() and not future.cancelled():
            try:
                start, end = future.result()
                return start, min(duration, end) if duration else end
            except Exception:
                logging.debug('Boundary analysis unavailable for %s', path, exc_info=True)
        return 0.0, duration

    def cancel_fade(self):
        self.decks[1 - self.active].stop()
        self.fade = None
        self.prepared = None
        self.deck.set('volume', self.volume)

    def play_index(self, index, start=0, paused=False):
        if not self.queue:
            return
        self.cancel_fade()
        self.index = index % len(self.queue)
        self.deck.load(self.queue[self.index], start)
        self.position = start
        self.paused = paused
        self.deck.set('volume', self.volume)
        self.deck.set('pause', paused)
        self.schedule_analysis()

    def snapshot(self):
        return {'path': self.deck.filename, 'metadata': self.deck.metadata,
                'paused': self.paused or self.deck.process.poll() is not None, 'position': self.position,
                'duration': self.deck.duration if self.deck.filename else 0,
                'volume': self.volume, 'crossfading': self.fade is not None,
                'shuffle': self.shuffle}

    def shuffle_queue(self, current):
        self.cancel_fade()
        remaining = [path for path in self.ordered_queue if path != current]
        random.shuffle(remaining)
        self.queue = ([current] if current in self.ordered_queue else []) + remaining
        self.index = 0 if self.queue else -1

    def set_shuffle(self, enabled):
        if self.shuffle == enabled:
            return
        current = self.deck.filename
        if enabled:
            self.shuffle_queue(current)
        else:
            self.cancel_fade()
            self.queue = list(self.ordered_queue)
            self.index = self.queue.index(current) if current in self.queue else -1
        self.shuffle = enabled
        if self.queue and self.index >= 0:
            self.schedule_analysis()

    def following_index(self, direction=1):
        if self.shuffle and direction > 0 and self.index == len(self.queue) - 1 and len(self.queue) > 1:
            self.shuffle_queue(self.deck.filename)
            self.schedule_analysis()
            return 1
        return (self.index + direction) % len(self.queue) if self.queue else -1

    def prepare(self, index):
        incoming = self.decks[1 - self.active]
        path = self.queue[index]
        if self.prepared != index:
            start, _ = self.edge(path, 0)
            incoming.load(path, start)
            self.prepared = index
        start, end = self.edge(path, incoming.duration)
        if abs(float(incoming.get('time-pos') or 0) - start) > 0.1:
            incoming.command('seek', start, 'absolute+exact')
        return incoming, start, end

    def start_fade(self, index, seconds, start):
        incoming = self.decks[1 - self.active]
        incoming.set('volume', 0)
        incoming.set('pause', False)
        self.active = 1 - self.active
        self.index = index
        self.position = start
        self.fade = {'start': start, 'seconds': seconds}
        self.prepared = None
        self.schedule_analysis()

    def transition_to(self, index):
        if not self.queue:
            return
        index %= len(self.queue)
        if self.paused or not self.deck.filename:
            self.play_index(index, paused=self.paused)
            return
        if self.fade:
            self.cancel_fade()
        incoming, start, end = self.prepare(index)
        position = float(self.deck.get('time-pos') or self.position)
        seconds = min(self.fade_seconds, max(0, self.deck.duration - position),
                      max(0, end - start) / 2)
        if seconds < 0.05:
            self.play_index(index)
        else:
            self.start_fade(index, seconds, start)

    def delete_track(self, filename):
        target = Path(filename)
        extensions = {'.mp3', '.flac', '.m4a', '.ogg', '.opus', '.wav', '.aac', '.webm'}
        if target.is_symlink() or not target.is_file() or target.suffix.lower() not in extensions or not target.resolve().is_relative_to(self.library):
            raise ValueError('Track is outside the music library or is not an audio file')
        filename = str(target)
        current = self.deck.filename
        outgoing = self.decks[1 - self.active].filename
        old_index = self.index
        paused = self.paused

        target.unlink()
        remaining = [path for path in self.queue if path != filename]
        future = self.analysis.pop(filename, None)
        self.analysis_signatures.pop(filename, None)
        if future:
            future.cancel()
        if filename == current or filename == outgoing or not self.fade:
            self.cancel_fade()
        self.queue = remaining
        self.ordered_queue = [path for path in self.ordered_queue if path != filename]
        self.prepared = None
        if filename == current:
            self.deck.stop()
            if remaining:
                try:
                    self.play_index(old_index % len(remaining), paused=paused)
                except (OSError, RuntimeError, ConnectionError):
                    logging.exception('Could not play the track following a deleted file')
                    self.execute('stop')
            else:
                self.execute('stop')
        elif current in remaining:
            self.index = remaining.index(current)
            self.schedule_analysis()
        return self.snapshot()

    def gains(self):
        if not self.fade:
            self.deck.set('volume', self.volume)
            return
        progress = max(0, min(1, (self.position - self.fade['start']) / self.fade['seconds']))
        self.deck.set('volume', self.volume * math.sin(progress * math.pi / 2))
        self.decks[1 - self.active].set('volume', self.volume * math.cos(progress * math.pi / 2))
        if progress >= 1:
            self.decks[1 - self.active].stop()
            self.fade = None

    def tick(self):
        with self.lock:
            if any(deck.process.poll() is not None for deck in self.decks):
                self.paused = True
                return
            if self.index < 0 or self.paused:
                return
            self.position = float(self.deck.get('time-pos') or self.position)
            if self.fade:
                self.gains()
                return
            start, end = self.edge(self.queue[self.index], self.deck.duration)
            if end <= 0:
                return
            if self.loop == 'None' and self.index == len(self.queue) - 1:
                if self.deck.get('eof-reached'):
                    self.paused = True
                return
            next_index = self.index if self.loop == 'Track' else self.following_index()
            remaining = end - self.position
            if remaining > self.fade_seconds + 3:
                return
            incoming, next_start, next_end = self.prepare(next_index)
            seconds = min(self.fade_seconds, (end - start) / 2,
                          max(0, next_end - next_start) / 2)
            if remaining <= seconds and seconds > 0:
                seconds = max(0.05, min(seconds, max(remaining, 0.05)))
                self.start_fade(next_index, seconds, next_start)
            elif self.deck.get('eof-reached'):
                self.play_index(next_index)

    def recover_decks(self):
        disconnected = [index for index, deck in enumerate(self.decks)
                        if deck.process.poll() is not None]
        if not disconnected:
            return
        active_disconnected = self.active in disconnected
        self.fade = None
        self.prepared = None
        for index in disconnected:
            path = self.decks[index].path
            self.decks[index].close()
            self.decks[index] = Deck(path, self.audio_output)
        if active_disconnected:
            self.paused = True
            if self.index >= 0 and self.queue:
                self.play_index(self.index, self.position, paused=True)
        logging.info('Recovered disconnected audio decks')

    def execute(self, command, *args):
        with self.lock:
            if command == 'ping':
                return 'ok'
            if command == 'state':
                return self.snapshot()
            self.recover_decks()
            if command == 'delete':
                return self.delete_track(args[0])
            if command == 'play':
                path, songs = args
                if not songs or path not in songs or any(not Path(p).is_file() or not Path(p).resolve().is_relative_to(self.library) for p in songs):
                    raise ValueError('Track is outside the music library')
                self.ordered_queue = list(songs)
                self.queue = list(songs)
                if self.shuffle:
                    self.shuffle_queue(path)
                self.play_index(self.queue.index(path))
            elif command == 'shuffle':
                self.set_shuffle(bool(args[0]) if args else not self.shuffle)
                from player import set_preference
                set_preference('shuffle', self.shuffle)
            elif command in ('next', 'previous'):
                self.transition_to(self.following_index(1 if command == 'next' else -1))
            elif command in ('toggle', 'pause', 'resume'):
                if self.index < 0 and self.queue and command != 'pause':
                    self.play_index(0)
                    return self.snapshot()
                self.paused = not self.paused if command == 'toggle' else command == 'pause'
                self.deck.set('pause', self.paused)
                if self.fade:
                    self.decks[1 - self.active].set('pause', self.paused)
            elif command == 'volume':
                self.volume = max(0, min(100, float(args[0])))
                self.gains()
            elif command == 'seek':
                self.cancel_fade()
                self.position = max(0, min(self.deck.duration, float(args[0])))
                self.deck.command('seek', self.position, 'absolute+exact')
            elif command == 'stop':
                self.cancel_fade()
                self.deck.stop()
                self.paused = True
                self.index = -1
                self.position = 0
            else:
                raise ValueError('Unknown audio command')
            return self.snapshot()

    def adopt(self):
        session_path = RUNTIME / 'y-music-session.json'
        if session_path.is_file():
            try:
                session = json.loads(session_path.read_text())
                songs = [path for path in session['queue'] if Path(path).is_file()
                         and Path(path).resolve().is_relative_to(self.library)]
                if session['path'] in songs:
                    self.queue = songs
                    order = session.get('ordered_queue', songs)
                    self.ordered_queue = list(dict.fromkeys([path for path in order if path in songs] + songs))
                    self.shuffle = bool(session.get('shuffle', self.shuffle))
                    self.volume = float(session['volume'])
                    self.play_index(songs.index(session['path']), session['position'], session['paused'])
                    logging.info('Resumed playback after engine reload')
                    return
            except (OSError, ValueError, KeyError, TypeError):
                logging.exception('Could not restore music session')
            finally:
                session_path.unlink(missing_ok=True)
        for path in (Path('/tmp/mpv_music_socket'), RUNTIME / 'omarchy-local-music.sock'):
            try:
                old = IPC(path)
            except OSError:
                continue
            try:
                playlist = old.command('get_property', 'playlist') or []
                songs = [entry['filename'] for entry in playlist
                         if Path(entry['filename']).is_file()
                         and Path(entry['filename']).resolve().is_relative_to(self.library)]
                current = old.command('get_property', 'path')
                if current not in songs:
                    continue
                self.queue = songs
                self.ordered_queue = list(songs)
                if self.shuffle:
                    self.shuffle_queue(current)
                self.volume = float(old.command('get_property', 'volume') or 0)
                paused = bool(old.command('get_property', 'pause'))
                position = float(old.command('get_property', 'time-pos') or 0)
                self.play_index(songs.index(current), position, paused=True)
                position = float(old.command('get_property', 'time-pos') or position)
                self.deck.command('seek', position, 'absolute+exact')
                old.command('set_property', 'pause', True)
                self.execute('pause' if paused else 'resume')
                try:
                    old.command('quit')
                except (OSError, ConnectionError):
                    pass
                logging.info('Resumed existing playback with crossfade enabled')
                break
            except (OSError, ValueError, ConnectionError):
                logging.exception('Could not adopt existing playback')
            finally:
                old.close()

    def close(self):
        self.running = False
        if hasattr(self, 'pool'):
            self.pool.shutdown(wait=False, cancel_futures=True)
        for deck in self.decks:
            deck.close()

def serve(engine, path=SOCKET):
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            try:
                request = json.loads(self.rfile.readline(8_000_000))
                result = engine.execute(request['command'], *request.get('args', []))
                response = {'data': result}
            except Exception as error:
                logging.exception('Audio command failed')
                response = {'error': str(error)}
            try:
                self.wfile.write((json.dumps(response) + '\n').encode())
            except (BrokenPipeError, ConnectionResetError):
                pass
    class Server(socketserver.ThreadingUnixStreamServer):
        daemon_threads = True
    Path(path).unlink(missing_ok=True)
    server = Server(str(path), Handler)
    os.chmod(path, 0o600)
    threading.Thread(target=server.serve_forever, daemon=True, name='music-ipc').start()
    return server

def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    with (RUNTIME / 'y-music-engine.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        engine = Engine()
        server = None
        def terminate(*_):
            engine.running = False
        signal.signal(signal.SIGTERM, terminate)
        signal.signal(signal.SIGINT, terminate)
        try:
            engine.adopt()
            server = serve(engine)
            from music_mpris import start_mpris
            start_mpris(engine)
            while engine.running:
                try:
                    engine.tick()
                except Exception:
                    logging.exception('Crossfade tick failed')
                    with engine.lock:
                        engine.cancel_fade()
                time.sleep(0.04 if engine.fade else 0.15)
        finally:
            if engine.index >= 0 and engine.queue:
                with engine.lock:
                    session = dict(engine.snapshot(), queue=engine.queue, ordered_queue=engine.ordered_queue)
                    (RUNTIME / 'y-music-session.json').write_text(json.dumps(session))
            if server:
                server.shutdown()
                server.server_close()
            engine.close()
            SOCKET.unlink(missing_ok=True)

if __name__ == '__main__':
    main()
