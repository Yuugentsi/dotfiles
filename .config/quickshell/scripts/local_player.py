import json
from pathlib import Path
import runpy
import sys


def main(args):
    backend = runpy.run_path(str(Path(__file__).with_name('player.py')))
    request = backend['audio_request']
    if args == ['state']:
        try:
            state = request('state', start=False)
            path = state.get('path') or ''
            tags = state.get('metadata') or {}
            cover = backend['cover_path'](path) if path else None
            print(json.dumps({'path': path,
                              'title': tags.get('TITLE') or tags.get('title') or (Path(path).stem if path else ''),
                              'artist': tags.get('ARTIST') or tags.get('artist') or '',
                              'cover': backend['cover_uri'](cover) if cover and cover.is_file() else '',
                              'paused': state.get('paused', True),
                              'position': state.get('position', 0), 'duration': state.get('duration', 0)}))
        except (OSError, ConnectionError, RuntimeError):
            print(json.dumps({'path': ''}))
        return 0
    if len(args) == 1 and args[0] in ('next', 'previous', 'toggle', 'stop'):
        request(args[0], start=False)
        return 0
    if len(args) == 2 and args[0] == 'seek':
        request('seek', max(0, float(args[1])), start=False)
        return 0
    return 2


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
