import json
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime
from html.parser import HTMLParser
import urllib.parse
import urllib.request


class SearchPage(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.cells = None
        self.cell = None
        self.title = ''
        self.magnet = ''
        self.pages = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'tr':
            self.cells, self.title, self.magnet = [], '', ''
        elif tag == 'td' and self.cells is not None:
            self.cell = ''
        elif tag == 'a':
            href = attrs.get('href', '')
            params = urllib.parse.parse_qs(urllib.parse.urlsplit(href).query)
            if params.get('p', [''])[0].isdigit():
                self.pages.add(int(params['p'][0]))
            if self.cells is not None:
                if re.fullmatch(r'/view/\d+', href) and attrs.get('title'):
                    self.title = attrs['title']
                if href.startswith('magnet:?'):
                    self.magnet = href

    def handle_data(self, data):
        if self.cell is not None:
            self.cell += data

    def handle_endtag(self, tag):
        if tag == 'td' and self.cell is not None:
            self.cells.append(self.cell.strip())
            self.cell = None
        elif tag == 'tr' and self.cells is not None:
            if self.title and self.magnet and len(self.cells) >= 6:
                self.rows.append({'title': self.title, 'magnet': self.magnet,
                                  'size': self.cells[3],
                                  'seeds': int(self.cells[5]) if self.cells[5].isdigit() else 0})
            self.cells = None
            self.cell = None


def fetch_search(query):
    results = []
    seen = set()
    page_number = 1
    while page_number <= 10:
        params = urllib.parse.urlencode({'q': query, 'c': '1_0', 'f': '0', 'p': page_number})
        request = urllib.request.Request('https://nyaa.si/?' + params,
                                         headers={'User-Agent': 'nyaa-cli/2.0'})
        with urllib.request.urlopen(request, timeout=25) as response:
            source = response.read(8 * 1024 * 1024).decode('utf-8', errors='replace')
        page = SearchPage()
        page.feed(source)
        for item in page.rows:
            if item['magnet'] not in seen:
                seen.add(item['magnet'])
                results.append(item)
        if page_number + 1 not in page.pages:
            return results, False
        page_number += 1
    return results, True


def normalize(value):
    return ' '.join(re.findall(r'\w+', value.casefold()))


def organize_results(results, query):
    groups = re.findall(r'\[([^\]]+)\]', query)
    title_query = normalize(re.sub(r'\[[^\]]+\]', ' ', query))
    organized = []
    for item in results:
        title = item['title']
        release_groups = re.findall(r'\[([^\]]+)\]', title)
        if any(normalize(group) not in [normalize(value) for value in release_groups] for group in groups):
            continue
        plain_title = re.sub(r'\[[^\]]+\]', ' ', title)
        if title_query and not set(title_query.split()).issubset(set(normalize(plain_title).split())):
            continue
        episode = re.search(r'\s-\s*(\d+(?:\.\d+)?)(?:v\d+)?(?:\s|$|\[|\()', plain_title)
        series = plain_title[:episode.start()] if episode else plain_title
        series = re.sub(r'\([^)]*\)', '', series).strip(' -._')
        entry = dict(item)
        entry['series'] = series or title
        entry['group'] = release_groups[0] if release_groups else 'Other releases'
        entry['episode'] = episode[1] if episode else ''
        organized.append(entry)
    def order(item):
        natural_title = tuple((1, int(part)) if part.isdigit() else (0, part.casefold())
                              for part in re.split(r'(\d+)', item['title']))
        return (normalize(item['series']), normalize(item['group']),
                float(item['episode']) if item['episode'] else float('inf'), natural_title)
    return sorted(organized, key=order)


def transfer(magnet):
    if not re.match(r'^magnet:\?xt=urn(?:%3A|:)btih(?:%3A|:)[a-fA-F0-9]{40}(?:&|$)', magnet, re.I):
        raise ValueError('Invalid magnet link')
    destination = Path.home() / 'Downloads/Anime'
    destination.mkdir(parents=True, exist_ok=True)
    folder = Path.home() / '.local/state/nyaa/logs'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.log')
    command = ['aria2c', '--dir=' + str(destination), '--seed-time=0',
               '--enable-color=false', '--summary-interval=1', '--console-log-level=notice', magnet]
    with path.open('w') as log:
        print(json.dumps({'log': str(path)}), flush=True)
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, errors='replace') as process:
            for line in process.stdout:
                log.write(line)
                log.flush()
                print(json.dumps({'line': line.strip()}), flush=True)
            code = process.wait()
        log.write(f'\nExit code: {code}\n')
    return code


def main():
    try:
        if sys.argv[1] == '--download':
            return transfer(sys.argv[2])
        results, limited = fetch_search(sys.argv[1])
        results = organize_results(results, sys.argv[1])
        print(json.dumps({'results': results, 'limited': limited}, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
