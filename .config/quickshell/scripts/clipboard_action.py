import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

STATE = Path.home() / '.local/state/quickshell/clipboard'
HISTORY = STATE / 'clipboard-history.json'


def initialize():
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    if HISTORY.exists():
        return
    entries = []
    result = subprocess.run(['cliphist', 'list'], capture_output=True, check=True)
    for line in result.stdout.splitlines()[:80]:
        identifier, separator, preview = line.partition(b'\t')
        if not separator or not identifier.isdigit():
            continue
        decoded = subprocess.run(['cliphist', 'decode', identifier.decode()], capture_output=True)
        if decoded.returncode or not decoded.stdout:
            continue
        if b'[[ binary data' in preview:
            data = decoded.stdout
            if data.startswith(b'\x89PNG'):
                extension, mime = 'png', 'image/png'
            elif data.startswith(b'\xff\xd8'):
                extension, mime = 'jpg', 'image/jpeg'
            elif data.startswith(b'GIF8'):
                extension, mime = 'gif', 'image/gif'
            elif data.startswith(b'RIFF') and data[8:12] == b'WEBP':
                extension, mime = 'webp', 'image/webp'
            else:
                continue
            folder = STATE / 'clipboard-images'
            folder.mkdir(exist_ok=True, mode=0o700)
            path = folder / (hashlib.sha256(data).hexdigest() + '.' + extension)
            path.write_bytes(data)
            entries.append(dict(type='image', path=str(path), mime=mime))
        else:
            text = decoded.stdout.decode('utf-8', errors='replace')
            if text.strip():
                entries.append(dict(type='text', text=text))
    HISTORY.write_text(json.dumps(entries))
    HISTORY.chmod(0o600)


def main():
    mode = sys.argv[1]
    if mode == 'init':
        initialize()
        return
    if mode not in ('copy', 'paste', 'open'):
        raise ValueError('Unknown clipboard action')
    entries = json.loads(HISTORY.read_text())
    index = int(sys.argv[2])
    if index < 0 or index >= len(entries):
        raise ValueError('Clipboard entry no longer exists')
    entry = entries[index]
    if mode == 'open':
        if entry['type'] == 'image':
            target = entry['path']
        else:
            text = entry['text'].strip()
            if text.startswith(('https://', 'http://', 'file://')) and '\n' not in text:
                target = text
            else:
                fd, target = tempfile.mkstemp(prefix='clipboard-', suffix='.txt', dir=STATE)
                with os.fdopen(fd, 'w') as stream:
                    stream.write(entry['text'])
        subprocess.Popen(['xdg-open', target], start_new_session=True)
        return
    if entry['type'] == 'image':
        data = Path(entry['path']).read_bytes()
        mime = entry.get('mime', 'image/png')
    else:
        data = entry['text'].encode()
        mime = 'text/plain;charset=utf-8'
    subprocess.run(['wl-copy', '--type', mime], input=data, check=True)
    if mode == 'paste':
        time.sleep(0.2)
        subprocess.run(['hyprctl', 'dispatch', 'sendshortcut', 'SHIFT, Insert,'], check=True,
                       stdout=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
