import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'quickshell/bluetooth-last-audio.json'


def last_audio():
    try:
        value = json.loads(STATE.read_text()).get('address', '')
        return value if re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', value) else ''
    except (OSError, ValueError, TypeError, AttributeError):
        return ''


def remember_audio(address):
    try:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        temporary = STATE.with_name(STATE.name + f'.{os.getpid()}.tmp')
        temporary.write_text(json.dumps({'address': address}))
        temporary.chmod(0o600)
        temporary.replace(STATE)
    except OSError:
        pass


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=4, check=False)
    if result.returncode:
        raise RuntimeError('Could not route Bluetooth audio.')
    return result.stdout.strip()


def normalize(value):
    return re.sub(r'[^0-9a-f]', '', str(value).lower())


def target_sink(sinks, address, preferred_name=''):
    target = normalize(address)
    for sink in sinks:
        properties = sink.get('properties', {})
        name = sink.get('name', '')
        if 'bluez' not in name.lower() and properties.get('device.api') != 'bluez5':
            continue
        values = [name, properties.get('api.bluez5.address', ''),
                  properties.get('bluez5.address', ''), properties.get('device.string', '')]
        if any(target in normalize(value) for value in values) or (preferred_name and name == preferred_name):
            return sink
    return None


def playback_stream(stream):
    properties = stream.get('properties', {})
    node_name = str(properties.get('node.name', '')).lower()
    binary = str(properties.get('application.process.binary', '')).lower()
    return not (node_name.startswith('omarchy_speaker_tuning')
                or binary in ('pw-loopback', 'pipewire')
                or properties.get('media.role') == 'filter')


def route(address, preferred_name='', attempts=12):
    if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', address):
        raise ValueError('Invalid Bluetooth address.')
    for attempt in range(attempts):
        try:
            sinks = json.loads(run(['pactl', '-f', 'json', 'list', 'sinks']))
            sink = target_sink(sinks, address, preferred_name)
            if sink:
                run(['pactl', 'set-default-sink', sink['name']])
                streams = json.loads(run(['pactl', '-f', 'json', 'list', 'sink-inputs']))
                failed = []
                for stream in streams:
                    if not playback_stream(stream) or str(stream.get('sink')) == str(sink['index']):
                        continue
                    try:
                        run(['pactl', 'move-sink-input', str(stream['index']), sink['name']])
                    except RuntimeError:
                        failed.append(str(stream['index']))
                if failed:
                    current = json.loads(run(['pactl', '-f', 'json', 'list', 'sink-inputs']))
                    if any(str(stream.get('index')) in failed and str(stream.get('sink')) != str(sink['index']) for stream in current):
                        raise RuntimeError('Audio stream is still on another output.')
                remember_audio(address)
                return True
        except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired):
            pass
        if attempt + 1 < attempts:
            time.sleep(0.5)
    return False


if __name__ == '__main__':
    if sys.argv[1:] == ['--last']:
        print(last_audio())
        sys.exit(0)
    try:
        success = route(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '')
    except (IndexError, ValueError):
        success = False
    sys.exit(0 if success else 1)
