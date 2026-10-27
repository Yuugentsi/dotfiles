import json
from pathlib import Path
import re
import runpy
import sys
import tempfile
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen


def api(endpoint, params=None):
    url = 'https://wallhaven.cc/api/v1/' + endpoint
    if params:
        url += '?' + urlencode(params)
    with urlopen(Request(url, headers={'User-Agent': 'Quickshell-Wallhaven/1.0'}), timeout=25) as response:
        return json.load(response)


def search(query, page, sorting='toplist'):
    if page < 1:
        raise ValueError('Invalid page')
    if sorting not in ('toplist', 'date_added', 'random', 'relevance'):
        raise ValueError('Invalid sorting')
    data = api('search', {'q': query, 'page': page, 'purity': '100', 'categories': '111',
                          'sorting': sorting, 'order': 'desc', 'topRange': '1M'})
    return {'images': [{'id': item['id'], 'thumbnail': item['thumbs']['large'],
                         'resolution': item['resolution']} for item in data['data']],
            'page': data['meta']['current_page'], 'pages': data['meta']['last_page']}


def save(identifier):
    if not re.fullmatch(r'[a-z0-9]{6}', identifier):
        raise ValueError('Invalid wallpaper')
    data = api('w/' + identifier)['data']
    source = data['path']
    parsed = urlsplit(source)
    if parsed.scheme != 'https' or parsed.hostname != 'w.wallhaven.cc':
        raise ValueError('Invalid image source')
    extension = Path(parsed.path).suffix.lower()
    if extension not in ('.jpg', '.jpeg', '.png', '.webp'):
        raise ValueError('Unsupported image format')
    folder = Path.home() / '0/pictures/wallpapers'
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / ('wallhaven-' + identifier + extension)
    if not target.exists():
        with urlopen(Request(source, headers={'User-Agent': 'Quickshell-Wallhaven/1.0'}), timeout=30) as response:
            content = response.read(40 * 1024 * 1024 + 1)
        if len(content) > 40 * 1024 * 1024:
            raise ValueError('Image exceeds 40 MB')
        with tempfile.NamedTemporaryFile(dir=folder, delete=False) as temporary:
            path = Path(temporary.name)
            temporary.write(content)
        try:
            path.replace(target)
        finally:
            path.unlink(missing_ok=True)
    return target


def main(args):
    try:
        if args[0] == 'search':
            result = search(args[1], int(args[2]), args[3] if len(args) > 3 else 'toplist')
        elif args[0] in ('save', 'apply'):
            path = save(args[1])
            if args[0] == 'apply':
                backend = runpy.run_path(str(Path(__file__).with_name('wallpapers.py')))
                backend['apply'](str(path), 'normal')
            result = {'message': 'Wallpaper applied' if args[0] == 'apply' else 'Saved to ~/0/pictures/wallpapers'}
        else:
            raise ValueError('Invalid command')
        print(json.dumps(result))
        return 0
    except Exception as error:
        print(json.dumps({'error': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
