import json
import re
import subprocess
import sys
from urllib.parse import urlencode, urlsplit, parse_qs


def search(query, page=1, kind='videos'):
    if not 1 <= page <= 100 or kind not in ('videos', 'playlists', 'tracks'):
        raise ValueError('Invalid search request')
    start = (page - 1) * 12 + 1
    end = page * 12
    if kind == 'playlists':
        target = 'https://www.youtube.com/results?' + urlencode({'search_query': query, 'sp': 'EgIQAw=='})
    elif kind == 'tracks':
        parsed = urlsplit(query)
        playlist_id = parse_qs(parsed.query).get('list', [''])[0]
        if parsed.hostname != 'www.youtube.com' or not re.fullmatch(r'[A-Za-z0-9_-]+', playlist_id):
            raise ValueError('Invalid playlist')
        target = 'https://www.youtube.com/playlist?' + urlencode({'list': playlist_id})
    else:
        target = f'ytsearch{end + 1}:' + query
    result = subprocess.run(
        ['yt-dlp', '--ignore-config', '--flat-playlist', '--dump-single-json',
         '--no-warnings', '--socket-timeout', '15', '--retries', '1',
         '--playlist-start', str(start), '--playlist-end', str(end + 1), '--', target],
        capture_output=True, text=True, timeout=60, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip()[-600:] or 'YouTube request failed')
    data = json.loads(result.stdout)
    entries = data.get('entries') or []
    items = []
    for item in entries:
        if not item:
            continue
        identifier = item.get('id') or ''
        thumbnails = item.get('thumbnails') or []
        thumbnail = next((entry.get('url', '') for entry in reversed(thumbnails) if entry.get('url', '').startswith('https://')), '')
        if kind == 'playlists':
            if not re.fullmatch(r'[A-Za-z0-9_-]+', identifier) or (item.get('ie_key') or '').lower() not in ('youtubetab', 'youtubeplaylist'):
                continue
            url = 'https://www.youtube.com/playlist?' + urlencode({'list': identifier})
            duration = str(item.get('playlist_count') or item.get('n_entries') or '')
        else:
            if not re.fullmatch(r'[A-Za-z0-9_-]{11}', identifier):
                continue
            if item.get('availability') in ('private', 'unavailable') or item.get('title') in ('[Private video]', '[Deleted video]'):
                continue
            seconds = item.get('duration')
            seconds = int(seconds) if isinstance(seconds, (int, float)) and seconds >= 0 else 0
            duration = (f'{seconds // 3600}:{seconds % 3600 // 60:02d}:{seconds % 60:02d}'
                        if seconds >= 3600 else f'{seconds // 60}:{seconds % 60:02d}' if seconds else '')
            url = 'https://www.youtube.com/watch?v=' + identifier
            thumbnail = 'https://i.ytimg.com/vi/' + identifier + '/mqdefault.jpg'
        items.append({'title': item.get('title') or 'Untitled',
                      'channel': item.get('channel') or item.get('uploader') or '',
                      'duration': duration, 'url': url, 'thumbnail': thumbnail})
    return {'results': items[:12], 'page': page, 'hasMore': len(entries) > 12,
            'title': data.get('title') or ''}


def main():
    try:
        print(json.dumps(search(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1,
                                sys.argv[3] if len(sys.argv) > 3 else 'videos'), ensure_ascii=False))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
