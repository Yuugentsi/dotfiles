#!/bin/bash

for b in zen-browser brave-origin librewolf firefox chromium; do
    if command -v "$b" &>/dev/null; then
        BROWSER="$b"
        break
    fi
done

# ----- cache -----
MANGA_DIR="${HOME}"
MANGA_CACHE_DIR="$HOME/.cache/scripts/manga"
MANGA_CACHE_FILE="$MANGA_CACHE_DIR/cache.txt"
MANGA_CACHE_MTIME="$MANGA_CACHE_DIR/cache-mtime.txt"
MANGA_HISTORY="$MANGA_CACHE_DIR/history.txt"

VIDEO_DIR="${HOME}"
VIDEO_CACHE_DIR="$HOME/.cache/scripts/video"
VIDEO_CACHE_FILE="$VIDEO_CACHE_DIR/cache.txt"
VIDEO_CACHE_MTIME="$VIDEO_CACHE_DIR/cache-mtime.txt"
VIDEO_HISTORY="$VIDEO_CACHE_DIR/history.txt"

IMAGE_DIR="${HOME}"
IMAGE_CACHE_DIR="$HOME/.cache/scripts/image"
IMAGE_CACHE_FILE="$IMAGE_CACHE_DIR/cache.txt"
IMAGE_CACHE_MTIME="$IMAGE_CACHE_DIR/cache-mtime.txt"
IMAGE_HISTORY="$IMAGE_CACHE_DIR/history.txt"

FILES_CACHE_DIR="$HOME/.cache/scripts/files"
FILES_CACHE_FILE="$FILES_CACHE_DIR/cache.txt"
FILES_CACHE_MTIME="$FILES_CACHE_DIR/cache-mtime.txt"
FILES_HISTORY="$FILES_CACHE_DIR/history.txt"
FILES_LIMIT=5000

_rofi_filterable_entries() {
    local entry
    while IFS= read -r entry || [[ -n "$entry" ]]; do
        printf '%s\0permanent\x1ffalse\n' "$entry"
    done
}

rofi_menu() {
    local lines="${2:-10}"
    _rofi_filterable_entries | rofi -dmenu -i -format s -auto-select \
        -theme-str "listview { columns: 1; lines: ${lines}; fixed-height: false; dynamic: true; }" \
        -p "$1"
}

open_all() {
    for url in "$@"; do
        "$BROWSER" "$url" &
    done
}

open_private() {
    local url="$1"
    case "$BROWSER" in
        zen-browser|librewolf|firefox)
            if [ -n "$url" ]; then
                "$BROWSER" --private-window "$url" &>/dev/null &
            else
                "$BROWSER" --private-window &>/dev/null &
            fi
            ;;
        brave-origin|brave|chromium|google-chrome|chrome)
            if [ -n "$url" ]; then
                "$BROWSER" --incognito "$url" &>/dev/null &
            else
                "$BROWSER" --incognito &>/dev/null &
            fi
            ;;
        *)
            if [ -n "$url" ]; then
                "$BROWSER" "$url" &>/dev/null &
            else
                "$BROWSER" &>/dev/null &
            fi
            ;;
    esac
}

_manga_rofi_menu() {
    _rofi_filterable_entries | rofi -dmenu -i -no-custom -selected-row 0 -format i \
        -theme-str 'listview { columns: 1; lines: 12; fixed-height: false; dynamic: true; }' \
        -p "$1"
}

# ----- sites search -----
ai_urls=(
    "https://chatgpt.com"
    "https://claude.ai"
    "https://duck.ai/"
    "https://kimi.com"
    "https://grok.com"
    "https://gemini.google.com/"
    "https://aistudio.google.com/"
    "https://chat.deepseek.com/"
    "https://chat.qwen.ai/"
)

anime_urls=(
    "https://animekai.to/home"
    "https://www.miruro.tv/"
    "https://kuudere.ru"
    "https://kaa.lt/"
)

web_urls=(
    "https://reddit.com"
    "https://letterboxd.com/yuugentsi/"
    "https://myanimelist.net"
    "https://anilist.co"
    "https://www.privacyguides.org/en/tools/"
    "https://news.ycombinator.com/"
    "https://lobste.rs/"
    "https://www.techmeme.com/"
    "https://apt.izzysoft.de/fdroid/"
    "https://f-droid.org/"
    "https://danbooru.donmai.us/"
    "https://www.deepl.com/en"
    "https://mail.google.com"
    "https://github.com"
    "https://wikipedia.org"
    "https://mail.proton.me/u/0/inbox"
    "https://pass.proton.me/u/0"
    "https://citywalks.live"
    "https://www.lofi.cafe/"
)

streaming_urls=(
    "https://www.cineby.sc/"
    "https://67movies.net"
    "https://popcornmovies.org/home"
    "https://shuttletv.su"
)

favorites_urls=(
    "https://wallhaven.cc/toplist"
    "https://youtube.com"
    "https://music.youtube.com"
    "https://last.fm"
    "https://pinterest.com"
    "https://fmhy.net/beginners-guide"
    "https://x.com"
    "https://addons.mozilla.org"
    "https://store.steampowered.com"
)

tech_urls=(
    "https://hackernoon.com/"
    "https://www.reuters.com/technology/"
    "https://www.wsj.com/tech"
    "https://www.androidpolice.com/"
    "https://techcrunch.com/"
)

open_site_choice() {
    case "$1" in
        *ChatGPT) "$BROWSER" "https://chatgpt.com" ;;
        *Claude) "$BROWSER" "https://claude.ai" ;;
        *DuckAI) "$BROWSER" "https://duck.ai/" ;;
        *Kimi) "$BROWSER" "https://kimi.com" ;;
        *Grok) "$BROWSER" "https://grok.com" ;;
        *Gemini) "$BROWSER" "https://gemini.google.com/" ;;
        *AI\ Studio) "$BROWSER" "https://aistudio.google.com/" ;;
        *DeepSeek) "$BROWSER" "https://chat.deepseek.com/" ;;
        *Qwen) "$BROWSER" "https://chat.qwen.ai/" ;;
        *AnimeKai) "$BROWSER" "https://animekai.to/home" ;;
        *Miruro) "$BROWSER" "https://www.miruro.tv/" ;;
        *Kuudere) "$BROWSER" "https://kuudere.ru" ;;
        *Kaa) "$BROWSER" "https://kaa.lt/" ;;
        *MyAnimeList) "$BROWSER" "https://myanimelist.net" ;;
        *AniList) "$BROWSER" "https://anilist.co" ;;
        *Twitter) "$BROWSER" "https://x.com" ;;
        *Reddit) "$BROWSER" "https://reddit.com" ;;
        *Letterboxd) "$BROWSER" "https://letterboxd.com/yuugentsi/" ;;
        *Pinterest) "$BROWSER" "https://pinterest.com" ;;
        *Last.fm) "$BROWSER" "https://last.fm/user/yuugentsi" ;;
        *Privacy\ Guides) "$BROWSER" "https://www.privacyguides.org/en/tools/" ;;
        *Hacker\ News) "$BROWSER" "https://news.ycombinator.com/" ;;
        *Lobsters) "$BROWSER" "https://lobste.rs/" ;;
        *Techmeme) "$BROWSER" "https://www.techmeme.com/" ;;
        *FMHY) "$BROWSER" "https://fmhy.net/beginners-guide" ;;
        *IzzyOnDroid) "$BROWSER" "https://apt.izzysoft.de/fdroid/" ;;
        *FDroid) "$BROWSER" "https://f-droid.org/" ;;
        *YouTube|*yt) "$BROWSER" "https://youtube.com" ;;
        *YouTube\ Music|*music) "$BROWSER" "https://music.youtube.com" ;;
        *Danbooru) "$BROWSER" "https://danbooru.donmai.us/" ;;
        *Wallhaven) "$BROWSER" "https://wallhaven.cc/toplist" ;;
        *DeepL) "$BROWSER" "https://www.deepl.com/en" ;;
        *Gmail) "$BROWSER" "https://mail.google.com" ;;
        *GitHub) "$BROWSER" "https://github.com/repos" ;;
        *Wikipedia) "$BROWSER" "https://wikipedia.org" ;;
        *Proton\ Mail) "$BROWSER" "https://mail.proton.me/u/0/inbox" ;;
        *Proton\ Pass) "$BROWSER" "https://pass.proton.me/u/0" ;;
        *CityWalks) "$BROWSER" "https://citywalks.live" ;;
        *Lofi\ Cafe) "$BROWSER" "https://www.lofi.cafe/" ;;
        *X.com) "$BROWSER" "https://x.com" ;;
        *Extensions) "$BROWSER" "https://addons.mozilla.org" ;;
        *Steam) "$BROWSER" "https://store.steampowered.com" ;;
        *HackerNoon) "$BROWSER" "https://hackernoon.com/" ;;
        *Reuters\ Tech) "$BROWSER" "https://www.reuters.com/technology/" ;;
        *WSJ\ Tech) "$BROWSER" "https://www.wsj.com/tech" ;;
        *Android\ Police) "$BROWSER" "https://www.androidpolice.com/" ;;
        *TechCrunch) "$BROWSER" "https://techcrunch.com/" ;;
        *Cineby) "$BROWSER" "https://www.cineby.sc/" ;;
        *67Movies) "$BROWSER" "https://67movies.net" ;;
        *PopcornMovies) "$BROWSER" "https://popcornmovies.org/home" ;;
        *ShuttleTV) "$BROWSER" "https://shuttletv.su" ;;
        *aria2) zeditor "$HOME/.config/aria2" ;;
        *gallery-dl) zeditor "$HOME/.config/gallery-dl" ;;
        *kitty) zeditor "$HOME/.config/kitty" ;;
        *waybar) zeditor "$HOME/.config/waybar" ;;
        *rofi) zeditor "$HOME/.config/rofi" ;;
        *hypr) zeditor "$HOME/.config/hypr" ;;
        *mpv) zeditor "$HOME/.config/mpv" ;;
        *swayimg) zeditor "$HOME/.config/swayimg" ;;
        *yt-dlp) zeditor "$HOME/.config/yt-dlp" ;;
        *swaync) zeditor "$HOME/.config/swaync" ;;
        *zathura) zeditor "$HOME/.config/zathura" ;;
        *fish) zeditor "$HOME/.config/fish" ;;
    esac
}

handle_bang() {
    local input="$1"
    local bang query encoded
    bang=${input%% *}
    query=${input#* }
    [ "$bang" = "$query" ] && query=""
    encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$query" 2>/dev/null || printf '%s' "$query")

    case "$bang" in
        .youtube|.yt)
            if [ -n "$query" ]; then
                "$BROWSER" "https://www.youtube.com/results?search_query=$encoded"
            else
                "$BROWSER" "https://youtube.com"
            fi
            ;;
        .x|.twitter)
            if [ -n "$query" ]; then
                "$BROWSER" "https://x.com/search?q=$encoded&src=typed_query"
            else
                "$BROWSER" "https://x.com"
            fi
            ;;
        .dan|.danbooru)
            if [ -n "$query" ]; then
                "$BROWSER" "https://danbooru.donmai.us/posts?tags=$encoded&z=5"
            else
                "$BROWSER" "https://danbooru.donmai.us"
            fi
            ;;
        .lastfm|.last)
            if [ -n "$query" ]; then
                "$BROWSER" "https://last.fm/user/$encoded"
            else
                "$BROWSER" "https://last.fm/user/yuugentsi"
            fi
            ;;
        .walltop|.wall) "$BROWSER" "https://wallhaven.cc/toplist" ;;
        .wallhot)       "$BROWSER" "https://wallhaven.cc/hot" ;;
        .github)
            if [ -n "$query" ]; then
                "$BROWSER" "https://github.com/$encoded"
            else
                "$BROWSER" "https://github.com/yuugentsi"
            fi
            ;;
        .git)
            if [ -n "$query" ]; then
                "$BROWSER" "https://github.com/$encoded"
            else
                "$BROWSER" "https://github.com/yuugentsi"
            fi
            ;;
        .gh)
            if [ -n "$query" ]; then
                "$BROWSER" "https://github.com/$encoded"
            else
                "$BROWSER" "https://github.com/Yuugentsi?tab=repositories"
            fi
            ;;
        .g)
            if [ -n "$query" ]; then
                "$BROWSER" "https://www.google.com/search?q=$encoded"
            else
                "$BROWSER" "https://google.com"
            fi
            ;;
        .d|.ddg)
            if [ -n "$query" ]; then
                "$BROWSER" "https://duckduckgo.com/?q=$encoded"
            else
                "$BROWSER" "https://duckduckgo.com"
            fi
            ;;
        .p) open_private "$query" ;;
        .reddit)
            if [ -n "$query" ]; then
                "$BROWSER" "https://www.reddit.com/search/?q=$encoded"
            else
                "$BROWSER" "https://reddit.com"
            fi
            ;;
        .r)
            if [ -n "$query" ]; then
                "$BROWSER" "https://www.reddit.com/r/$encoded"
            else
                "$BROWSER" "https://reddit.com"
            fi
            ;;
        .pin)
            if [ -n "$query" ]; then
                "$BROWSER" "https://www.pinterest.com/search/pins/?q=$encoded"
            else
                "$BROWSER" "https://pinterest.com"
            fi
            ;;
        .mpv) mpv "$query" &>/dev/null & ;;
        .webm) (
            IFS= read -r -d '' video < <(find "$HOME" -type d \( -path "*/\.*" -o -name node_modules \) -prune -o -type f -iname "*.webm" -print0 2>/dev/null | shuf -z -n 1)
            [[ -n "$video" ]] || exit 0
            mpv -- "$video"
        ) &>/dev/null & ;;
        .mp4) ("$HOME/.config/hypr/scripts/quickshell.sh" notify 5 2000 "rgb(a6e3a1)" "󰄬" && yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" -o "$HOME/videos/yt/%(title)s.%(ext)s" "$query" && "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 3000 "rgb(a6e3a1)" "󰄬") &>/dev/null & ;;
        .mp3) ("$HOME/.config/hypr/scripts/quickshell.sh" notify 5 2000 "rgb(a6e3a1)" "󰄬" && yt-dlp -x --audio-format mp3 -o "$HOME/music/yt/%(title)s.%(ext)s" "$query" && "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 3000 "rgb(a6e3a1)" "󰄬") &>/dev/null & ;;
        .dl) ("$HOME/.config/hypr/scripts/quickshell.sh" notify 5 2000 "rgb(a6e3a1)" "󰄬" && gallery-dl "$query" && "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 3000 "rgb(a6e3a1)" "󰄬") &>/dev/null & ;;
        .zed)
            if [ -n "$query" ]; then
                zeditor "$HOME/$query" &>/dev/null &
            else
                zeditor "$HOME" &>/dev/null &
            fi
            ;;
        .ins) kitty -e sudo pacman -S --noconfirm "$query" &>/dev/null & ;;
        .play) (pgrep -x mpv | xargs -r kill -9 2>/dev/null; sleep 0.1; /usr/bin/mpv --shuffle --no-video "$HOME/0/music"/**/*) &>/dev/null & ;;
        .manga) (
            MANGA_HISTORY="$HOME/.cache/scripts/manga/random_history.txt"
            mkdir -p "$(dirname "$MANGA_HISTORY")"
            all_manga=$(find "$HOME" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f -iname "*.cbz" -print 2>/dev/null)
            [[ -z "$all_manga" ]] && exit 0
            unplayed=$(grep -Fxvf "$MANGA_HISTORY" <<< "$all_manga" 2>/dev/null)
            [[ -z "$unplayed" ]] && : > "$MANGA_HISTORY" && unplayed="$all_manga"
            manga=$(echo "$unplayed" | shuf -n 1)
            echo "$manga" >> "$MANGA_HISTORY"
            zathura "$manga" &>/dev/null &
        ) &>/dev/null & ;;
        .wallpaper|.wp) (
            cache="$HOME/.cache/scripts/wallpapers"
            mkdir -p "$cache"
            wp=$(find "$HOME/0/pictures/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)
            [[ -z "$wp" ]] && exit 1
            cp -- "$wp" "$cache/current"
            printf "splash = false\nipc = true\npreload = %s\nwallpaper = ,%s,cover\n" "$cache/current" "$cache/current" > "$cache/hyprpaper.conf"
            pgrep -x hyprpaper >/dev/null || hyprpaper -c "$cache/hyprpaper.conf" &>/dev/null & sleep 0.5
            hyprctl hyprpaper preload "$cache/current" &>/dev/null
            hyprctl hyprpaper wallpaper ",$cache/current,cover" &>/dev/null
            hyprctl hyprpaper unload unused &>/dev/null
            "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 2200 "rgb(cba6f7)" "󰄬 wallpaper set"
        ) &>/dev/null & ;;
        .wallpaperblur|.wpb) (
            cache="$HOME/.cache/scripts/wallpapers"
            mkdir -p "$cache"
            wp=$(find "$HOME/0/pictures/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)
            [[ -z "$wp" ]] && exit 1
            magick "$wp" -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 "$cache/current"
            printf "splash = false\nipc = true\npreload = %s\nwallpaper = ,%s,cover\n" "$cache/current" "$cache/current" > "$cache/hyprpaper.conf"
            pgrep -x hyprpaper >/dev/null || hyprpaper -c "$cache/hyprpaper.conf" &>/dev/null & sleep 0.5
            hyprctl hyprpaper preload "$cache/current" &>/dev/null
            hyprctl hyprpaper wallpaper ",$cache/current,cover" &>/dev/null
            hyprctl hyprpaper unload unused &>/dev/null
            "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 2200 "rgb(cba6f7)" "󰄬 wallpaper set (blur)"
        ) &>/dev/null & ;;
    esac
}

run_manga_reader() {
    python3 -B - <<'MANGA_READER_PYTHON'
import json
import mimetypes
import os
from pathlib import Path
import random
import re
import secrets
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import zipfile

HOME = Path.home()
CACHE = HOME / '.cache/scripts/manga'
RANDOM_HISTORY = CACHE / 'random_history.txt'
SHUFFLE_HISTORY = CACHE / 'shuffle_history.txt'
MENU_HISTORY = CACHE / 'history.txt'
PROGRESS = CACHE / 'progress.json'
IMAGE_TYPES = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'}


def find_mangas(root=HOME):
    files = []
    for directory, folders, names in os.walk(root):
        folders[:] = [name for name in folders if not name.startswith('.') and name != 'node_modules']
        files.extend(Path(directory) / name for name in names if name.lower().endswith('.cbz'))
    return sorted(files)


def read_history(path):
    return path.read_text().splitlines() if path.exists() else []


def save_history(path, entries):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(''.join(f'{entry}\n' for entry in entries))
    temporary.replace(path)


def page_order(name):
    return [int(part) if part.isdigit() else part.casefold() for part in re.split(r'(\d+)', name)]


class MangaLibrary:
    def __init__(self, folder):
        self.folder = Path(folder)
        self.files = []
        self.copies = {}
        groups = {}
        for path in sorted(find_mangas(), key=lambda path: (len(path.name), str(path))):
            try:
                with zipfile.ZipFile(path) as archive:
                    images = sorted((info for info in archive.infolist() if not info.is_dir() and Path(info.filename).suffix.lower() in IMAGE_TYPES and not info.filename.startswith('__MACOSX/')), key=lambda info: page_order(info.filename))
                    if not images:
                        continue
                    signature = tuple((info.CRC, info.file_size) for info in images)
            except (OSError, ValueError, zipfile.BadZipFile):
                continue
            representative = groups.get(signature)
            if representative is None:
                groups[signature] = path
                self.files.append(path)
                self.copies[path] = []
                representative = path
            self.copies[representative].append(path)
        self.current = None
        self.images = []
        self.pick_id = ''
        self.state = {}
        self.lock = threading.Lock()

    def was_selected(self, path, history):
        return any(str(copy) in history for copy in self.copies[path])

    def progress(self):
        data = json.loads(PROGRESS.read_text()) if PROGRESS.exists() else {}
        entries = [data[str(path)] for path in self.copies.get(self.current, []) if isinstance(data.get(str(path)), dict)]
        saved = max(entries, key=lambda entry: entry.get('updated', 0), default={})
        page = max(0, min(len(self.images) - 1, int(saved.get('page', 0))))
        offset = max(0, min(1, float(saved.get('offset', 0))))
        return {'page': page, 'offset': offset}

    def save_progress(self, pick_id, page, offset):
        if pick_id != self.pick_id or self.current is None or not self.images:
            raise ValueError('Reading selection changed')
        data = json.loads(PROGRESS.read_text()) if PROGRESS.exists() else {}
        saved = {
            'page': max(0, min(len(self.images) - 1, int(page))),
            'offset': max(0, min(1, float(offset))),
            'updated': time.time(),
        }
        for path in self.copies[self.current]:
            data[str(path)] = saved
        PROGRESS.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=PROGRESS.parent, prefix='mangas-', suffix='.tmp', delete=False) as output:
            temporary = Path(output.name)
            json.dump(data, output, ensure_ascii=False)
        try:
            temporary.replace(PROGRESS)
        finally:
            temporary.unlink(missing_ok=True)
        return saved

    def choose(self):
        self.images = []
        self.pick_id = secrets.token_hex(8)
        self.files = [path for path in self.files if path.is_file()]
        if not self.files:
            self.current = None
            self.state = {'title': 'Your library is empty', 'error': 'Add CBZ files to your home folders to get started.', 'total': 0, 'remaining': 0, 'pages': 0, 'size': '', 'folder': '', 'cover': ''}
            return self.state
        history = set(read_history(SHUFFLE_HISTORY if SHUFFLE_HISTORY.exists() else RANDOM_HISTORY))
        available = [path for path in self.files if not self.was_selected(path, history)]
        if not available:
            history.clear()
            available = self.files
        candidates = [path for path in available if path != self.current] or available
        self.current = random.choice(candidates)
        history.update(str(path) for path in self.copies[self.current])
        save_history(SHUFFLE_HISTORY, sorted(history))
        cover = ''
        pages = 0
        error = ''
        try:
            with zipfile.ZipFile(self.current) as archive:
                images = sorted((info for info in archive.infolist() if not info.is_dir() and Path(info.filename).suffix.lower() in IMAGE_TYPES and not info.filename.startswith('__MACOSX/')), key=lambda info: page_order(info.filename))
                pages = len(images)
                self.images = [info.filename for info in images]
                if images:
                    preview = self.folder / f'{secrets.token_hex(8)}{Path(images[0].filename).suffix.lower()}'
                    preview.write_bytes(archive.read(images[0]))
                    cover = preview.as_uri()
        except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, NotImplementedError):
            error = 'The cover could not be loaded. You can still try opening the file.'
        self.state = {
            'title': self.current.stem, 'cover': cover, 'pages': pages,
            'size': f'{self.current.stat().st_size / 1024 / 1024:.1f} MB',
            'folder': str(self.current.parent.relative_to(HOME)),
            'total': len(self.files), 'remaining': len(available), 'error': error,
            'pick': self.pick_id,
            'progress': self.progress(),
        }
        return self.state

    def open(self):
        if self.current is None:
            return self.state
        if not self.current.is_file():
            self.state['error'] = 'This file no longer exists. Choose another manga.'
            return self.state
        if not self.images:
            self.state['error'] = 'No readable pages were found in this CBZ.'
            return self.state
        self.state['error'] = ''
        self.state['progress'] = self.progress()
        history = read_history(RANDOM_HISTORY)
        if all(self.was_selected(path, history) for path in self.files):
            history = []
        if str(self.current) not in history:
            history.append(str(self.current))
        save_history(RANDOM_HISTORY, history)
        relative = str(self.current.relative_to(HOME))
        save_history(MENU_HISTORY, [entry for entry in read_history(MENU_HISTORY) if entry != relative] + [relative])
        self.state['remaining'] = sum(not self.was_selected(path, history) for path in self.files)
        return self.state

    def page(self, pick_id, index):
        if pick_id != self.pick_id or self.current is None or not 0 <= index < len(self.images):
            raise FileNotFoundError('Page not found')
        filename = self.images[index]
        with zipfile.ZipFile(self.current) as archive:
            content = archive.read(filename)
        return content, mimetypes.guess_type(filename)[0] or 'application/octet-stream'


QML = r'''
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: false
    width: 760; height: 820
    minimumWidth: 580; minimumHeight: 580
    title: "Mangas"
    color: "#000000"
    font.family: "Adwaita Sans"
    property color accent: "#0a84ff"
    property color ink: "#f5f5f7"
    property color secondaryInk: "#98989d"
    property color separator: "#38383a"
    property var manga: ({title: "Finding your next read", total: 0, remaining: 0, pages: 0, size: "", folder: "", cover: "", error: ""})
    property bool busy: false
    property bool reading: false
    property int pageIndex: 0
    property real zoom: 1
    property bool fitWidth: true
    property bool showControls: false
    property bool warmFilter: false
    property bool autoScrollEnabled: false
    property real autoScrollSpeed: 150
    property bool restoringProgress: false
    property bool allowClose: false
    property string lastSavedProgress: ""
    property int resumePage: 0
    property real resumeOffset: 0
    function toggleAutoScroll() {
        smoothScroll.stop()
        autoScrollEnabled = !autoScrollEnabled
    }
    function saveProgress(callback) {
        if (!reading || restoringProgress || !manga.pick) {
            if (callback) callback()
            return
        }
        let index = reader.indexAt(reader.contentX + reader.width / 2, reader.contentY + 1)
        if (index < 0) index = pageIndex
        let item = reader.itemAtIndex(index)
        let offset = item && item.height > 0 ? Math.max(0, Math.min(1, (reader.contentY - item.y) / item.height)) : 0
        let payload = JSON.stringify({pick: manga.pick, page: index, offset: offset})
        if (payload === lastSavedProgress) {
            if (callback) callback()
            return
        }
        let request = new XMLHttpRequest()
        request.open("POST", API_URL + "progress")
        request.setRequestHeader("Content-Type", "application/json")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status === 200) root.lastSavedProgress = payload
            if (callback) callback()
        }
        request.send(payload)
    }
    function returnToLibrary() {
        saveProgress(function() { root.reading = false })
    }
    function goToStart() {
        smoothScroll.stop()
        resumePage = 0
        resumeOffset = 0
        reader.positionViewAtBeginning()
        pageIndex = 0
        saveProgress()
    }
    Timer {
        interval: 16
        repeat: true
        property real lastTick: 0
        running: root.autoScrollEnabled && root.reading && !root.restoringProgress
        onRunningChanged: lastTick = Date.now()
        onTriggered: {
            let now = Date.now()
            let elapsed = Math.min(0.05, Math.max(0, (now - lastTick) / 1000))
            lastTick = now
            let maximum = reader.originY + Math.max(0, reader.contentHeight - reader.height)
            let distance = root.autoScrollSpeed * elapsed
            if (smoothScroll.running) smoothScroll.to = Math.min(maximum, smoothScroll.to + distance)
            else reader.contentY = Math.min(maximum, reader.contentY + distance)
        }
    }
    Timer {
        interval: 1500; repeat: true
        running: root.reading && !root.restoringProgress
        onTriggered: root.saveProgress()
    }
    Timer {
        interval: 100; repeat: true
        running: root.reading && root.restoringProgress
        onTriggered: {
            reader.forceLayout()
            reader.positionViewAtIndex(root.resumePage, ListView.Beginning)
            let item = reader.itemAtIndex(root.resumePage)
            if (!item || !item.ready) return
            reader.forceLayout()
            let maximum = reader.originY + Math.max(0, reader.contentHeight - reader.height)
            reader.contentY = Math.min(maximum, item.y + item.height * root.resumeOffset)
            root.pageIndex = root.resumePage
            root.restoringProgress = false
        }
    }
    onClosing: event => {
        if (root.reading && !root.allowClose) {
            event.accepted = false
            root.saveProgress(function() {
                root.allowClose = true
                Qt.callLater(function() { root.close() })
            })
        }
    }
    function setZoom(value, x = reader.width / 2, y = reader.height / 2) {
        let nextZoom = Math.max(0.5, Math.min(4, value))
        if (nextZoom === zoom) return
        smoothScroll.stop()
        let ratio = nextZoom / zoom
        let oldX = reader.contentX
        let oldY = reader.contentY
        let index = reader.indexAt(oldX + x, oldY + y)
        let item = reader.itemAtIndex(index)
        let offset = item ? oldY + y - item.y : 0
        zoom = nextZoom
        reader.forceLayout()
        item = reader.itemAtIndex(index)
        reader.contentX = Math.max(0, Math.min(reader.contentWidth - reader.width, (oldX + x) * ratio - x))
        let targetY = item ? item.y + offset * ratio - y : (oldY + y) * ratio - y
        let maximum = reader.originY + Math.max(0, reader.contentHeight - reader.height)
        reader.contentY = Math.max(reader.originY, Math.min(maximum, targetY))
    }
    function toggleFullScreen() {
        if (visibility === Window.FullScreen) showMaximized()
        else showFullScreen()
    }
    function turnPage(offset) {
        smoothScroll.stop()
        let nextIndex = Math.max(0, Math.min(manga.pages - 1, pageIndex + offset))
        reader.positionViewAtIndex(nextIndex, ListView.Beginning)
        pageIndex = nextIndex
    }
    function scrollPage(delta) {
        if (!delta) return
        let position = smoothScroll.running ? smoothScroll.to : reader.contentY
        let start = reader.contentY
        smoothScroll.stop()
        let minimum = reader.originY
        let maximum = minimum + Math.max(0, reader.contentHeight - reader.height)
        smoothScroll.from = start
        smoothScroll.to = Math.max(minimum, Math.min(maximum, position - delta))
        smoothScroll.start()
    }
    NumberAnimation {
        id: smoothScroll
        target: reader; property: "contentY"
        duration: 180
        easing.type: Easing.OutCubic
    }
    function request(action, readAfter = false) {
        if (busy) return
        if (action === "next" && reading) {
            saveProgress(function() { root.reading = false; root.request(action, readAfter) })
            return
        }
        busy = true
        let request = new XMLHttpRequest()
        request.open("POST", API_URL + action)
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            root.busy = false
            if (request.status === 200) {
                root.manga = JSON.parse(request.responseText)
                if (root.manga.error || root.manga.total === 0) root.visible = true
                if (action === "open" && !root.manga.error) {
                    root.pageIndex = 0
                    root.resumePage = root.manga.progress ? root.manga.progress.page : 0
                    root.resumeOffset = root.manga.progress ? root.manga.progress.offset : 0
                    root.restoringProgress = true
                    root.lastSavedProgress = ""
                    root.zoom = 1
                    root.fitWidth = true
                    root.showControls = false
                    smoothScroll.stop()
                    root.reading = true
                    root.showFullScreen()
                    Qt.callLater(function() { reader.positionViewAtIndex(root.resumePage, ListView.Beginning) })
                }
                if (action === "next") {
                    root.reading = false
                    if (readAfter && root.manga.total > 0) root.request("open")
                }
            } else {
                root.manga = Object.assign({}, root.manga, {error: "Could not load the library. Please reopen this window."})
                root.visible = true
            }
        }
        request.send()
    }
    Component.onCompleted: request("next", true)
    Shortcut { sequence: "Escape"; onActivated: shortcutsHelp.visible ? shortcutsHelp.close() : root.reading ? root.returnToLibrary() : root.close() }
    Shortcut { id: helpShortcut; sequence: "H"; context: Qt.ApplicationShortcut; autoRepeat: false; onActivated: shortcutsHelp.visible ? shortcutsHelp.close() : shortcutsHelp.open() }
    Shortcut { id: quitShortcut; sequence: "Q"; enabled: !shortcutsHelp.visible; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+R"; enabled: !shortcutsHelp.visible && !root.reading; onActivated: root.request("next") }
    Shortcut { id: randomMangaShortcut; sequence: "R"; autoRepeat: false; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.request("next", true) }
    Shortcut { sequence: "Return"; enabled: !shortcutsHelp.visible && !root.reading && root.manga.total > 0; onActivated: root.request("open") }
    Shortcut { id: nextPageShortcut; sequences: ["Right", "D", "Space", "PgDown"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.turnPage(1) }
    Shortcut { id: previousPageShortcut; sequences: ["Left", "A", "PgUp"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.turnPage(-1) }
    Shortcut { sequences: ["Up", "W"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.scrollPage(reader.height * 0.15) }
    Shortcut { sequences: ["Down", "S"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.scrollPage(-reader.height * 0.15) }
    Shortcut { id: autoScrollShortcut; sequence: "P"; autoRepeat: false; enabled: root.reading && !root.restoringProgress && !shortcutsHelp.visible; onActivated: root.toggleAutoScroll() }
    Shortcut { id: firstPageShortcut; sequences: ["I", "Home"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.goToStart() }
    Shortcut { sequence: "End"; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.turnPage(root.manga.pages) }
    Shortcut { sequences: ["Ctrl++", "Ctrl+="]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.setZoom(root.zoom + 0.25) }
    Shortcut { sequence: "Ctrl+-"; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.setZoom(root.zoom - 0.25) }
    Shortcut { id: resetZoomShortcut; sequences: ["Z", "Ctrl+0"]; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.setZoom(1) }
    Shortcut { id: fullScreenShortcut; sequences: ["F", "F11"]; enabled: !shortcutsHelp.visible; onActivated: root.toggleFullScreen() }
    Shortcut { sequence: "Tab"; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.showControls = !root.showControls }
    Shortcut { id: lightFilterShortcut; sequence: "L"; enabled: root.reading && !shortcutsHelp.visible; onActivated: root.warmFilter = !root.warmFilter }
    component Caption: Text { color: root.secondaryInk; font.family: root.font.family; font.pixelSize: 13 }
    component Heading: Text { color: root.ink; font.family: root.font.family; font.pixelSize: 18; font.weight: Font.DemiBold }
    component ReaderPanel: Rectangle {
        property bool revealed: false
        radius: 20
        border.color: root.separator
        color: "#f21c1c1e"
        opacity: revealed ? 1 : 0
        visible: opacity > 0
        enabled: revealed
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    component ReaderButton: Button {
        property bool selected: false
        property string hint: ""
        implicitWidth: Math.max(36, contentItem.implicitWidth + 24)
        implicitHeight: 36
        hoverEnabled: true
        opacity: enabled ? 1 : 0.35
        background: Rectangle {
            radius: 10
            color: parent.down ? "#19436b" : parent.selected ? "#102e4d" : parent.hovered ? "#2c2c2e" : "transparent"
            border.width: parent.selected || parent.hovered ? 1 : 0
            border.color: "#245a8c"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: Text {
            text: parent.text
            color: parent.selected ? root.accent : root.ink
            font.family: root.font.family
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        ToolTip.visible: hovered && hint.length > 0
        ToolTip.text: hint
        ToolTip.delay: 500
    }
    Popup {
        id: shortcutsHelp
        anchors.centerIn: Overlay.overlay
        width: Math.min(root.width - 48, 620)
        height: Math.min(root.height - 48, 740)
        padding: 24
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: smoothScroll.stop()
        Overlay.modal: Rectangle { color: "#66000000" }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }
        background: Rectangle {
            radius: 24
            border.color: root.separator
            color: "#2c2c2e"
        }
        contentItem: ColumnLayout {
            spacing: 18
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Caption { text: "READER GUIDE"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    Heading { text: "Keyboard shortcuts"; font.pixelSize: 26 }
                    Caption { text: "Keep your hands on the keyboard." }
                }
                ReaderButton { text: "×"; hint: "Close help · H / Esc"; onClicked: shortcutsHelp.close() }
            }
            ScrollView {
                id: shortcutsScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: shortcutsScroll.availableWidth
                    spacing: 12
                    Repeater {
                        model: [
                            {title: "GENERAL", rows: [
                                {keys: ["H"], action: "Toggle this guide"},
                                {keys: ["Esc"], action: "Close help · back to library · close menu"},
                                {keys: ["Q"], action: "Close reader"}
                            ]},
                            {title: "LIBRARY", rows: [
                                {keys: ["Enter"], action: "Read selected manga"},
                                {keys: ["Ctrl+R"], action: "Pick another manga"},
                                {keys: ["R"], action: "Read a random manga while reading"}
                            ]},
                            {title: "NAVIGATION", rows: [
                                {keys: ["→", "D", "Space", "PgDown"], action: "Next page"},
                                {keys: ["←", "A", "PgUp"], action: "Previous page"},
                                {keys: ["↑", "W"], action: "Scroll up smoothly"},
                                {keys: ["↓", "S"], action: "Scroll down smoothly"},
                                {keys: ["P"], action: "Start / pause automatic scrolling"},
                                {keys: ["Home", "I"], action: "First page"},
                                {keys: ["End"], action: "Last page"},
                                {keys: ["Wheel"], action: "Scroll with the mouse"}
                            ]},
                            {title: "VIEW & COMFORT", rows: [
                                {keys: ["Ctrl++", "Ctrl+="], action: "Zoom in"},
                                {keys: ["Ctrl+−"], action: "Zoom out"},
                                {keys: ["Z", "Ctrl+0"], action: "Reset zoom"},
                                {keys: ["Ctrl+wheel", "Pinch"], action: "Zoom with mouse or touchpad"},
                                {keys: ["F", "F11"], action: "Toggle fullscreen"},
                                {keys: ["Tab"], action: "Toggle controls"},
                                {keys: ["L"], action: "Toggle warm filter"}
                            ]}
                        ]
                        delegate: Rectangle {
                            id: shortcutSection
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: sectionContent.implicitHeight + 28
                            radius: 14
                            color: "#1c1c1e"
                            border.color: root.separator
                            ColumnLayout {
                                id: sectionContent
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10
                                Caption { text: shortcutSection.modelData.title; color: root.secondaryInk; font.pixelSize: 10; font.letterSpacing: 1.5 }
                                Repeater {
                                    model: shortcutSection.modelData.rows
                                    delegate: RowLayout {
                                        id: shortcutRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 12
                                        Caption { text: shortcutRow.modelData.action; color: root.ink; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12 }
                                        Flow {
                                            Layout.preferredWidth: shortcutsHelp.width < 560 ? 160 : 228
                                            Layout.preferredHeight: implicitHeight
                                            layoutDirection: Qt.RightToLeft
                                            spacing: 5
                                            Repeater {
                                                model: shortcutRow.modelData.keys
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    implicitWidth: keyLabel.implicitWidth + 16
                                                    implicitHeight: 26
                                                    radius: 6
                                                    color: "#2c2c2e"
                                                    border.color: root.separator
                                                    Text {
                                                        id: keyLabel
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        font.family: "JetBrains Mono"
                                                        font.pixelSize: 11
                                                        color: root.ink
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    implicitWidth: 28; implicitHeight: 26
                    radius: 6; color: "#102e4d"; border.color: "#19436b"
                    Heading { anchors.centerIn: parent; text: "H"; font.pixelSize: 12 }
                }
                Caption { text: "Press again to close"; Layout.fillWidth: true }
                Caption { text: "Esc also closes"; font.pixelSize: 11 }
            }
        }
    }
    ColumnLayout {
        visible: !root.reading
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 5
                Caption { text: "LIBRARY"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                Heading { text: "Your next read"; font.pixelSize: 32; font.weight: Font.Bold; font.letterSpacing: -0.8 }
                Caption { text: "A little time for a good story."; font.pixelSize: 14 }
            }
            Item { Layout.fillWidth: true }
            ToolButton {
                text: "×"; font.pixelSize: 26
                onClicked: root.close()
                background: Rectangle { color: parent.hovered ? "#2c2c2e" : "transparent"; radius: 10 }
                contentItem: Heading { text: "×"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                Accessible.name: "Close"
            }
        }
        RowLayout {
            spacing: 12
            Repeater {
                model: [{label: "In your library", value: root.manga.total || 0}, {label: "Unread picks", value: root.manga.remaining || 0}]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 86
                    color: "#1c1c1e"; radius: 20; border.color: root.separator
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter; spacing: 7
                        Caption { text: modelData.label }
                        Heading { text: modelData.value; font.pixelSize: 24 }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumHeight: 180
            color: "#1c1c1e"; radius: 24; border.color: root.separator; clip: true
            Image {
                id: cover
                anchors.fill: parent; anchors.margins: 18
                source: root.manga.cover || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 1000; sourceSize.height: 1400
            }
            Caption {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: root.busy ? "Loading…" : root.manga.total ? "No cover available" : "No CBZ files found"
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 7
            Heading { Layout.fillWidth: true; text: root.manga.title || ""; font.pixelSize: 21; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
            Caption { Layout.fillWidth: true; text: root.manga.total ? root.manga.pages + " pages   ·   " + root.manga.size : "" }
            Caption { Layout.fillWidth: true; text: root.manga.folder || ""; elide: Text.ElideMiddle; font.pixelSize: 11 }
            Caption { Layout.fillWidth: true; visible: !!root.manga.error; text: root.manga.error || ""; color: "#ff453a"; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Button {
                Layout.fillWidth: true; Layout.preferredHeight: 54
                enabled: !root.busy && root.manga.total > 0
                onClicked: root.request("next")
                background: Rectangle { color: parent.down ? "#3a3a3c" : parent.hovered ? "#2c2c2e" : "#1c1c1e"; border.color: root.separator; radius: 16; opacity: parent.enabled ? 1 : 0.4; Behavior on color { ColorAnimation { duration: 120 } } }
                contentItem: Heading { text: "Another manga"; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                Layout.fillWidth: true; Layout.preferredHeight: 54
                enabled: !root.busy && root.manga.total > 0
                onClicked: root.request("open")
                background: Rectangle { color: parent.hovered ? "#0062cc" : root.accent; radius: 16; opacity: parent.enabled ? 1 : 0.4; Behavior on color { ColorAnimation { duration: 120 } } }
                contentItem: Heading { text: root.manga.progress && (root.manga.progress.page > 0 || root.manga.progress.offset > 0) ? "Continue reading" : "Read manga"; color: "#ffffff"; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Caption { Layout.alignment: Qt.AlignHCenter; text: "Ctrl+R  Shuffle    ·    Enter  Read    ·    H  Help"; font.pixelSize: 11 }
    }
    Item {
        visible: root.reading
        anchors.fill: parent
        ListView {
            id: reader
            anchors.fill: parent
            model: root.reading ? root.manga.pages || 0 : 0
            contentWidth: Math.max(width, width * root.zoom)
            flickableDirection: Flickable.AutoFlickIfNeeded
            spacing: 12
            cacheBuffer: height * 2
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onContentYChanged: {
                let index = indexAt(contentX + width / 2, contentY + Math.min(height / 3, 200))
                if (index >= 0) root.pageIndex = index
            }
            onMovementStarted: smoothScroll.stop()
            delegate: Item {
                required property int index
                property bool ready: pageImage.status === Image.Ready || pageImage.status === Image.Error
                width: reader.contentWidth
                height: pageImage.height
                Image {
                    id: pageImage
                    property real pageRatio: implicitWidth > 0 && implicitHeight > 0 ? implicitWidth / implicitHeight : cover.implicitWidth > 0 && cover.implicitHeight > 0 ? cover.implicitWidth / cover.implicitHeight : 2 / 3
                    width: (root.fitWidth ? reader.width : Math.min(reader.width, reader.height * pageRatio)) * root.zoom
                    height: width / pageRatio
                    x: (parent.width - width) / 2
                    source: API_URL + "page/" + root.manga.pick + "/" + parent.index
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                Caption {
                    anchors.centerIn: parent
                    visible: pageImage.status !== Image.Ready
                    text: pageImage.status === Image.Error ? "This page could not be loaded." : "Loading page…"
                }
            }
        }
        MouseArea {
            id: readerMouse
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                let delta = wheel.pixelDelta.y || wheel.angleDelta.y
                if ((wheel.modifiers & Qt.ControlModifier) && delta) {
                    root.setZoom(root.zoom * Math.exp(delta * 0.0015), wheel.x, wheel.y)
                    wheel.accepted = true
                } else if (wheel.pixelDelta.y) {
                    smoothScroll.stop()
                    wheel.accepted = false
                } else if (wheel.angleDelta.y) {
                    root.scrollPage(wheel.angleDelta.y * 0.75)
                    wheel.accepted = true
                } else wheel.accepted = false
            }
        }
        Rectangle {
            id: warmOverlay
            anchors.fill: parent
            visible: root.warmFilter
            color: "#ffb568"
            opacity: 0.14
            enabled: false
        }
        Rectangle {
            id: dimOverlay
            anchors.fill: parent
            visible: root.warmFilter
            color: "black"
            opacity: 0.16
            enabled: false
        }
        PinchHandler {
            id: pinchZoom
            target: null
            enabled: root.reading
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.TouchScreen
            rotationAxis.enabled: false
            xAxis.enabled: false
            yAxis.enabled: false
            onScaleChanged: delta => root.setZoom(root.zoom * delta, centroid.position.x, centroid.position.y)
        }
        Item {
            anchors.top: parent.top
            width: parent.width; height: 60
            HoverHandler { id: headerHover }
            ReaderPanel {
                id: readerHeader
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                width: Math.min(parent.width - 32, 900)
                height: 44
                revealed: root.showControls || headerHover.hovered
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 12
                    ReaderButton { text: "‹ Library"; hint: "Library · Esc"; onClicked: root.returnToLibrary() }
                    Heading { Layout.fillWidth: true; text: root.manga.title || ""; elide: Text.ElideRight; font.pixelSize: 16 }
                    ReaderButton { text: "×"; hint: "Close · Q"; onClicked: root.close() }
                }
            }
        }
        Item {
            anchors.bottom: parent.bottom
            width: parent.width; height: 132
            HoverHandler { id: footerHover }
            ReaderPanel {
                id: readerFooter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: Math.min(parent.width - 32, 680)
                height: 104
                revealed: root.showControls || footerHover.hovered
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        ReaderButton { text: "‹ Previous"; hint: "Previous page · A / ←"; enabled: root.pageIndex > 0; onClicked: root.turnPage(-1) }
                        Item { Layout.fillWidth: true }
                        Heading { text: (root.pageIndex + 1) + " / " + (root.manga.pages || 0); font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        ReaderButton { text: "Next ›"; hint: "Next page · D / →"; enabled: root.pageIndex + 1 < root.manga.pages; onClicked: root.turnPage(1) }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 2
                        radius: 1
                        color: root.separator
                        Rectangle {
                            width: parent.width * (root.pageIndex + 1) / Math.max(1, root.manga.pages || 0)
                            height: parent.height
                            radius: 1
                            color: root.accent
                            Behavior on width { NumberAnimation { duration: 160 } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Item { Layout.fillWidth: true }
                        ReaderButton {
                            text: root.fitWidth ? "Fit page" : "Fit width"
                            hint: "Switch page sizing"
                            onClicked: { root.fitWidth = !root.fitWidth; root.zoom = 1; Qt.callLater(function() { reader.positionViewAtIndex(root.pageIndex, ListView.Beginning) }) }
                        }
                        Rectangle { implicitWidth: 1; implicitHeight: 18; color: root.separator; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                        ReaderButton { text: "−"; hint: "Zoom out · Ctrl+−"; enabled: root.zoom > 0.5; onClicked: root.setZoom(root.zoom - 0.25) }
                        ReaderButton { text: Math.round(root.zoom * 100) + "%"; hint: "Reset zoom · Z"; onClicked: root.setZoom(1) }
                        ReaderButton { text: "+"; hint: "Zoom in · Ctrl++"; enabled: root.zoom < 4; onClicked: root.setZoom(root.zoom + 0.25) }
                        Rectangle { implicitWidth: 1; implicitHeight: 18; color: root.separator; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                        ReaderButton { text: "Auto"; selected: root.autoScrollEnabled; hint: "Automatic scrolling · P"; enabled: !root.restoringProgress; onClicked: root.toggleAutoScroll() }
                        ReaderButton { text: "Warm"; selected: root.warmFilter; hint: "Reading filter · L"; onClicked: root.warmFilter = !root.warmFilter }
                        ReaderButton { text: root.visibility === Window.FullScreen ? "Window" : "Full screen"; hint: "Toggle fullscreen · F"; onClicked: root.toggleFullScreen() }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
'''


def show_menu():
    CACHE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mangas-', dir=CACHE) as directory:
        library = MangaLibrary(directory)
        token = secrets.token_urlsafe(24)

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                match = re.fullmatch(rf'/{re.escape(token)}/page/([a-f0-9]+)/([0-9]+)', self.path)
                if not match:
                    self.send_error(404)
                    return
                try:
                    with library.lock:
                        content, content_type = library.page(match[1], int(match[2]))
                except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, NotImplementedError):
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(content)))
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                self.wfile.write(content)

            def do_POST(self):
                action = self.path.removeprefix(f'/{token}/')
                if self.path != f'/{token}/{action}' or action not in ('next', 'open', 'progress'):
                    self.send_error(404)
                    return
                try:
                    with library.lock:
                        if action == 'progress':
                            length = int(self.headers.get('Content-Length', 0))
                            if not 0 < length <= 4096:
                                raise ValueError('Invalid reading progress')
                            progress = json.loads(self.rfile.read(length))
                            state = library.save_progress(progress['pick'], progress['page'], progress['offset'])
                        else:
                            state = library.choose() if action == 'next' else library.open()
                    payload = json.dumps(state).encode()
                except (OSError, ValueError) as error:
                    payload = json.dumps(dict(library.state, error=str(error))).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = f'http://127.0.0.1:{server.server_port}/{token}/'
            source = QML.replace('API_URL', json.dumps(url))
            path = Path(directory) / 'menu.qml'
            path.write_text(source)
            subprocess.run(['/usr/bin/qml6', str(path)], check=True)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == '__main__':
    show_menu()

MANGA_READER_PYTHON
}

if [[ -n "$1" ]]; then
    case "$1" in
        manga-reader|.manga-reader) run_manga_reader ;;
        manga|.manga) handle_bang ".manga" ;;
        .*) handle_bang "$1" ;;
        *) handle_bang ".$1" ;;
    esac
    wait
    exit 0
fi

anime_entries='❀  AnimeKai
❀  Miruro
❀  Kuudere
❀  Kaa'
anime_count=$(printf '%s\n' "$anime_entries" | wc -l)

ai_entries='❀  ChatGPT
❀  Claude
❀  DuckAI
❀  Kimi
❀  Grok
❀  Gemini
❀  AI Studio
❀  DeepSeek
❀  Qwen'
ai_count=$(printf '%s\n' "$ai_entries" | wc -l)

web_entries='❀  Reddit
❀  Letterboxd
❀  MyAnimeList
❀  AniList
❀  Privacy Guides
❀  Hacker News
❀  Lobsters
❀  Techmeme
❀  IzzyOnDroid
❀  FDroid
❀  Danbooru
❀  DeepL
❀  Gmail
❀  GitHub
❀  Wikipedia
❀  Proton Mail
❀  Proton Pass
❀  CityWalks
❀  Lofi Cafe'
web_count=$(printf '%s\n' "$web_entries" | wc -l)

streaming_entries='❀  Cineby
❀  67Movies
❀  PopcornMovies
❀  ShuttleTV'
streaming_count=$(printf '%s\n' "$streaming_entries" | wc -l)

tech_entries='❀  HackerNoon
❀  Reuters Tech
❀  WSJ Tech
❀  Android Police
❀  TechCrunch'
tech_count=$(printf '%s\n' "$tech_entries" | wc -l)

favorites_entries='❀  Wallhaven
❀  yt
❀  music
❀  Last.fm
❀  Pinterest
❀  FMHY
❀  X.com
❀  Extensions
❀  Steam'
favorites_count=$(printf '%s\n' "$favorites_entries" | wc -l)

config_entries='❀  aria2
❀  gallery-dl
❀  kitty
❀  waybar
❀  rofi
❀  hypr
❀  mpv
❀  swayimg
❀  yt-dlp
❀  swaync
❀  zathura
❀  fish'

all_entries=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s' "$favorites_entries" "$ai_entries" "$anime_entries" "$tech_entries" "$web_entries" "$streaming_entries" "$config_entries")
all_count=$(printf '%s\n' "$all_entries" | wc -l)

websites_count=$((favorites_count + ai_count + anime_count + tech_count + web_count + streaming_count))
config_count=$(printf '%s\n' "$config_entries" | wc -l)
manga_count=0
video_count=0
image_count=0
[[ -f "$MANGA_CACHE_FILE" ]] && manga_count=$(wc -l < "$MANGA_CACHE_FILE" 2>/dev/null)
[[ -f "$VIDEO_CACHE_FILE" ]] && video_count=$(wc -l < "$VIDEO_CACHE_FILE" 2>/dev/null)
[[ -f "$IMAGE_CACHE_FILE" ]] && image_count=$(wc -l < "$IMAGE_CACHE_FILE" 2>/dev/null)
manga_count=${manga_count:-0}
video_count=${video_count:-0}
image_count=${image_count:-0}

run_search_all() {
    pkill -x rofi 2>/dev/null

    local all_choice
    all_choice=$(printf '%s\n' "$all_entries" | rofi_menu "❀  All:")
    [[ -z "$all_choice" ]] && exit 0

    case "$all_choice" in
        '.'*)
            handle_bang "$all_choice"
            exit 0
            ;;
        *)
            open_site_choice "$all_choice"
            ;;
    esac
}

run_websites_menu() {
    pkill -x rofi 2>/dev/null

    local ws_choice
    ws_choice=$(printf '❀  Favorites (%s)\n❀  Web (%s)\n❀  Tech (%s)\n❀  AI (%s)\n❀  Anime (%s)\n❀  Streaming (%s)' \
        "$favorites_count" "$web_count" "$tech_count" "$ai_count" "$anime_count" "$streaming_count" \
        | rofi_menu "❀  Websites:" 6)
    [[ -z "$ws_choice" ]] && exit 0

    case "$ws_choice" in
        *"Favorites ("*")")
            local fav_choice
            fav_choice=$(printf '❀  Open All\n%s' "$favorites_entries" | rofi_menu "❀  Favorites:")
            [[ -z "$fav_choice" ]] && exit 0
            if [[ "$fav_choice" == *"Open All" ]]; then
                open_all "${favorites_urls[@]}"
            else
                open_site_choice "$fav_choice"
            fi
            ;;
        *"Web ("*")")
            local web_choice
            web_choice=$(printf '❀  Open All\n%s' "$web_entries" | rofi_menu "❀  Web:")
            [[ -z "$web_choice" ]] && exit 0
            if [[ "$web_choice" == *"Open All" ]]; then
                open_all "${web_urls[@]}"
            else
                open_site_choice "$web_choice"
            fi
            ;;
        *"Tech ("*")")
            local tech_choice
            tech_choice=$(printf '❀  Open All\n%s' "$tech_entries" | rofi_menu "❀  Tech:")
            [[ -z "$tech_choice" ]] && exit 0
            if [[ "$tech_choice" == *"Open All" ]]; then
                open_all "${tech_urls[@]}"
            else
                open_site_choice "$tech_choice"
            fi
            ;;
        *"AI ("*")")
            local ai_choice
            ai_choice=$(printf '❀  Open All\n%s' "$ai_entries" | rofi_menu "❀  AI:")
            [[ -z "$ai_choice" ]] && exit 0
            if [[ "$ai_choice" == *"Open All" ]]; then
                open_all "${ai_urls[@]}"
            else
                open_site_choice "$ai_choice"
            fi
            ;;
        *"Anime ("*")")
            local anime_choice
            anime_choice=$(printf '❀  Open All\n%s' "$anime_entries" | rofi_menu "❀  Anime:")
            [[ -z "$anime_choice" ]] && exit 0
            if [[ "$anime_choice" == *"Open All" ]]; then
                open_all "${anime_urls[@]}"
            else
                open_site_choice "$anime_choice"
            fi
            ;;
        *"Streaming ("*")")
            local streaming_choice
            streaming_choice=$(printf '❀  Open All\n%s' "$streaming_entries" | rofi_menu "❀  Streaming:")
            [[ -z "$streaming_choice" ]] && exit 0
            if [[ "$streaming_choice" == *"Open All" ]]; then
                open_all "${streaming_urls[@]}"
            else
                open_site_choice "$streaming_choice"
            fi
            ;;
    esac
}

run_config_menu() {
    pkill -x rofi 2>/dev/null

    local config_choice
    config_choice=$(printf '󰁯  Backup → dotfiles.zip\n❀  Open All\n%s' "$config_entries" | rofi_menu "❀  Cfg:" 14)
    [[ -z "$config_choice" ]] && exit 0
    if [[ "$config_choice" == *Backup* ]]; then
        cd "$HOME/.config" && zip -rq "$HOME/dotfiles.zip" aria2 gallery-dl kitty waybar rofi hypr mpv swayimg yt-dlp swaync zathura fish \
            && "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 3000 "rgb(a6e3a1)" "󰁯  Backup saved → ~/dotfiles.zip" \
            || "$HOME/.config/hypr/scripts/quickshell.sh" notify 3 3000 "rgb(f38ba8)" "󰅗  Backup failed"
        exit 0
    fi
    if [[ "$config_choice" == *"Emoji Picker" ]]; then
        rofi -modi emoji -show emoji -emoji-format '{emoji}' -emoji-mode copy
        exit 0
    fi
    if [[ "$config_choice" == *"Open All" ]]; then
        zeditor "$HOME/.config/aria2" "$HOME/.config/gallery-dl" "$HOME/.config/kitty" "$HOME/.config/waybar" "$HOME/.config/rofi" "$HOME/.config/hypr" "$HOME/.config/mpv" "$HOME/.config/swayimg" "$HOME/.config/yt-dlp" "$HOME/.config/swaync" "$HOME/.config/zathura" "$HOME/.config/fish" &>/dev/null &
        exit 0
    fi
    local cfg
    cfg=$(echo "$config_choice" | sed 's/^❀  //')
    zeditor "$HOME/.config/$cfg" &
}

# ----- manga -----
_manga_find() {
    if command -v fd &>/dev/null; then
        fd -e cbz --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude '.*' --base-directory "$MANGA_DIR" 2>/dev/null
    else
        find "$MANGA_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f -iname "*.cbz" -print 2>/dev/null | sed "s|^$HOME/||"
    fi
}

_manga_size() {
    du -h "$1" 2>/dev/null | awk '{print $1}'
}

_manga_pages() {
    zipinfo -1 "$1" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|webp|gif|bmp)$' | wc -l
}

_manga_get_mtime() {
    if command -v fd &>/dev/null; then
        fd -e cbz --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude '.*' -x stat --printf='%Y %s %n\n' . "$MANGA_DIR" 2>/dev/null | sort | md5sum
    else
        find "$MANGA_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f -iname "*.cbz" -printf '%T@ %s %p\n' 2>/dev/null | sort | md5sum
    fi
}

_manga_build_cache() {
    local tmp
    tmp=$(mktemp)
    mkdir -p "$MANGA_CACHE_DIR"
    local old_cache="$MANGA_CACHE_FILE"
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local cached_line=""
        if [[ -f "$old_cache" ]]; then
            cached_line=$(grep -F "$path	" "$old_cache" 2>/dev/null | head -1)
        fi
        if [[ -n "$cached_line" ]]; then
            printf '%s\n' "$cached_line" >> "$tmp"
        else
            local size pages
            size=$(_manga_size "$HOME/$path")
            pages=$(_manga_pages "$HOME/$path")
            printf '%s\t%s\t%s\n' "$path" "$size" "$pages" >> "$tmp"
        fi
    done < <(_manga_find)
    mv "$tmp" "$MANGA_CACHE_FILE"
    _manga_get_mtime > "$MANGA_CACHE_MTIME"
}

_manga_refresh_cache() {
    if [[ ! -f "$MANGA_CACHE_FILE" ]] || [[ ! -f "$MANGA_CACHE_MTIME" ]]; then
        _manga_build_cache
        return
    fi
    local current cached
    current=$(_manga_get_mtime)
    cached=$(cat "$MANGA_CACHE_MTIME")
    [[ "$current" != "$cached" ]] && _manga_build_cache
}

_manga_sort() {
    local all hist
    all=$(mktemp)
    hist=$(mktemp)
    cut -f1 "$MANGA_CACHE_FILE" | sort > "$all"
    if [[ -f "$MANGA_HISTORY" ]]; then
        cat "$MANGA_HISTORY" > "$hist"
        grep -Fxv -f "$hist" "$all" | sort
        grep -Fx -f "$all" "$hist"
    else
        cat "$all"
    fi
    rm -f "$all" "$hist"
}

_manga_add_history() {
    mkdir -p "$(dirname "$MANGA_HISTORY")"
    local tmp
    tmp=$(mktemp)
    grep -Fxv "$1" "$MANGA_HISTORY" 2>/dev/null > "$tmp"
    printf '%s\n' "$1" >> "$tmp"
    mv "$tmp" "$MANGA_HISTORY"
}

run_manga_menu() {
    pkill -x rofi 2>/dev/null
    _manga_refresh_cache
    [[ ! -f "$MANGA_CACHE_FILE" ]] && exit 0

    declare -a MANGA_PATHS MANGA_LABELS

    LAST_READ=$(tail -n 1 "$MANGA_HISTORY" 2>/dev/null)
    [[ -n "$LAST_READ" ]] && MANGA_PATHS+=("$LAST_READ") && MANGA_LABELS+=("➜ last")

    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local info size pages
        info=$(grep -F "$path" "$MANGA_CACHE_FILE" | head -1)
        [[ -z "$info" ]] && continue
        size=$(printf '%s' "$info" | cut -f2)
        pages=$(printf '%s' "$info" | cut -f3)
        MANGA_PATHS+=("$path")
        MANGA_LABELS+=("$(printf '%-7s %-4s %s' "$size" "$pages" "$path")")
    done < <(_manga_sort)

    [[ ${#MANGA_PATHS[@]} -eq 0 ]] && exit 0

    idx=$(printf '%s\n' "${MANGA_LABELS[@]}" | _manga_rofi_menu "manga")
    [[ -z "$idx" ]] && exit 0

    choice="${MANGA_PATHS[$idx]}"
    [[ -z "$choice" ]] && exit 0

    file="$HOME/$choice"
    [[ -f "$file" ]] || exit 0

    if [[ "${MANGA_LABELS[$idx]}" == "➜ last" ]]; then
        zathura "$file" >/dev/null 2>&1 &
    else
        _manga_add_history "$choice"
        zathura "$file" >/dev/null 2>&1 &
    fi
}

# ----- video -----
VIDEO_DIR="${HOME}"
VIDEO_CACHE_DIR="$HOME/.cache/scripts/video"
VIDEO_CACHE_FILE="$VIDEO_CACHE_DIR/cache.txt"
VIDEO_CACHE_MTIME="$VIDEO_CACHE_DIR/cache-mtime.txt"
VIDEO_HISTORY="$VIDEO_CACHE_DIR/history.txt"
VIDEO_GROUP_BY_FOLDER=true

_video_find() {
    if command -v fd &>/dev/null; then
        fd -e mp4 -e mkv -e webm --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude '.*' --base-directory "$VIDEO_DIR" 2>/dev/null
    else
        find "$VIDEO_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -print 2>/dev/null | sed "s|^$HOME/||"
    fi
}

_video_size() {
    du -h "$1" 2>/dev/null | awk '{print $1}'
}

_video_duration() {
    local dur
    dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)
    if [[ -n "$dur" ]]; then
        local sec min hour
        sec=${dur%.*}
        min=$((sec / 60))
        hour=$((min / 60))
        sec=$((sec % 60))
        min=$((min % 60))
        printf '%02d:%02d:%02d' "$hour" "$min" "$sec"
    fi
}

_video_get_mtime() {
    if command -v fd &>/dev/null; then
        fd -e mp4 -e mkv -e webm --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude '.*' -x stat --printf='%Y %s %n\n' . "$VIDEO_DIR" 2>/dev/null | sort | md5sum
    else
        find "$VIDEO_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -printf '%T@ %s %p\n' 2>/dev/null | sort | md5sum
    fi
}

_video_build_cache() {
    local tmp
    tmp=$(mktemp)
    mkdir -p "$VIDEO_CACHE_DIR"
    local old_cache="$VIDEO_CACHE_FILE"
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local cached_line=""
        if [[ -f "$old_cache" ]]; then
            cached_line=$(grep -F "$path	" "$old_cache" 2>/dev/null | head -1)
        fi
        if [[ -n "$cached_line" ]]; then
            printf '%s\n' "$cached_line" >> "$tmp"
        else
            local size duration
            size=$(_video_size "$HOME/$path")
            duration=$(_video_duration "$HOME/$path")
            printf '%s\t%s\t%s\n' "$path" "$size" "$duration" >> "$tmp"
        fi
    done < <(_video_find)
    mv "$tmp" "$VIDEO_CACHE_FILE"
    _video_get_mtime > "$VIDEO_CACHE_MTIME"
}

_video_refresh_cache() {
    if [[ ! -f "$VIDEO_CACHE_FILE" ]] || [[ ! -f "$VIDEO_CACHE_MTIME" ]]; then
        _video_build_cache
        return
    fi
    local current cached
    current=$(_video_get_mtime)
    cached=$(cat "$VIDEO_CACHE_MTIME")
    [[ "$current" != "$cached" ]] && _video_build_cache
}

_video_sort() {
    cut -f1 "$VIDEO_CACHE_FILE" | sort -V
}

_video_add_history() {
    mkdir -p "$(dirname "$VIDEO_HISTORY")"
    local tmp
    tmp=$(mktemp)
    grep -Fxv "$1" "$VIDEO_HISTORY" 2>/dev/null > "$tmp"
    printf '%s\n' "$1" >> "$tmp"
    mv "$tmp" "$VIDEO_HISTORY"
}

_video_recent() {
    if command -v fd &>/dev/null; then
        fd -e mp4 -e mkv -e webm --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude '.*' -x stat --printf='%Y\t%n\n' . "$VIDEO_DIR" 2>/dev/null \
        | sort -t$'\t' -k1,1nr \
        | cut -f2- \
        | head -n 100
    else
        find "$VIDEO_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) \
            -printf '%T@\t%p\n' 2>/dev/null \
        | sort -t$'\t' -k1,1nr \
        | cut -f2- \
        | head -n 100
    fi
}

_run_video_menu_flat() {
    declare -a VIDEO_PATHS VIDEO_LABELS

    LAST_WATCHED=$(tail -n 1 "$VIDEO_HISTORY" 2>/dev/null)
    [[ -n "$LAST_WATCHED" ]] && VIDEO_PATHS+=("$LAST_WATCHED") && VIDEO_LABELS+=("➜ last")

    while IFS=$'\t' read -r path size duration; do
        [[ -z "$path" ]] && continue
        [[ "$path" == "$LAST_WATCHED" ]] && continue
        VIDEO_PATHS+=("$path")
        VIDEO_LABELS+=("$(printf '%-7s %-10s %s' "$size" "$duration" "$path")")
    done < "$VIDEO_CACHE_FILE"

    [[ ${#VIDEO_PATHS[@]} -eq 0 ]] && exit 0

    idx=$(printf '%s\n' "${VIDEO_LABELS[@]}" | _manga_rofi_menu "video")
    [[ -z "$idx" ]] && exit 0

    choice="${VIDEO_PATHS[$idx]}"
    [[ -z "$choice" ]] && exit 0

    file="$HOME/$choice"
    [[ -f "$file" ]] || exit 0

    if [[ "${VIDEO_LABELS[$idx]}" == "➜ last" ]]; then
        mpv "$file" >/dev/null 2>&1 &
    else
        _video_add_history "$choice"
        mpv "$file" >/dev/null 2>&1 &
    fi
}

_run_video_menu_by_folder() {
    local root_display
    if [[ "$VIDEO_DIR" == "$HOME" ]]; then
        root_display="~"
    else
        root_display="$VIDEO_DIR"
    fi

    declare -a MENU_ENTRIES MENU_LABELS
    local LAST_WATCHED
    LAST_WATCHED=$(tail -n 1 "$VIDEO_HISTORY" 2>/dev/null)
    MENU_ENTRIES+=("NEW")
    MENU_LABELS+=("➜ new")

    if [[ -n "$LAST_WATCHED" ]]; then
        MENU_ENTRIES+=("LAST")
        MENU_LABELS+=("➜ last")
    fi

    MENU_ENTRIES+=("ALL")
    MENU_LABELS+=("󰒓  all")

    while IFS=$'\t' read -r count folder; do
        [[ -z "$folder" ]] && continue
        if [[ "$folder" == "." ]]; then
            MENU_ENTRIES+=(".")
            MENU_LABELS+=("$(printf '(%s)\t%s' "$count" "$root_display")")
        else
            MENU_ENTRIES+=("$folder")
            MENU_LABELS+=("$(printf '(%s)\t%s' "$count" "$folder")")
        fi
    done < <(
        cut -f1 "$VIDEO_CACHE_FILE" | awk '{n=$0; sub(/\/[^\/]+$/,"",n); if (n == $0) n="."; c[n]++} END {for (k in c) print c[k] "\t" k}' \
        | sort -t$'\t' -k1,1rn
    )

    MENU_ENTRIES+=("LONGEST")
    MENU_LABELS+=("")

    [[ ${#MENU_ENTRIES[@]} -eq 0 ]] && exit 0

    local idx
    idx=$(printf '%s\n' "${MENU_LABELS[@]}" | _manga_rofi_menu "video folder")
    [[ -z "$idx" ]] && exit 0

    local selected_entry
    selected_entry="${MENU_ENTRIES[$idx]}"
    [[ -z "$selected_entry" ]] && exit 0

    if [[ "$selected_entry" == "NEW" ]]; then
        local -a recent=()
        local path rel
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            rel="${path#$HOME/}"
            [[ "$rel" == "$path" ]] && continue
            recent+=("$HOME/$rel")
        done < <(_video_recent)
        [[ ${#recent[@]} -eq 0 ]] && exit 0
        mpv --no-resume-playback "${recent[@]}" >/dev/null 2>&1 &
        exit 0
    fi

    if [[ "$selected_entry" == "LAST" ]]; then
        local file
        file="$HOME/$LAST_WATCHED"
        [[ -f "$file" ]] || exit 0
        mpv "$file" >/dev/null 2>&1 &
        exit 0
    fi

    if [[ "$selected_entry" == "ALL" ]]; then
        declare -a VIDEO_PATHS VIDEO_LABELS
        while IFS=$'\t' read -r path size duration; do
            [[ -z "$path" ]] && continue
            [[ "$path" == "$LAST_WATCHED" ]] && continue
            VIDEO_PATHS+=("$path")
            VIDEO_LABELS+=("$(printf '%-7s %-10s %s' "$size" "$duration" "$path")")
        done < "$VIDEO_CACHE_FILE"

        [[ ${#VIDEO_PATHS[@]} -eq 0 ]] && exit 0

        idx=$(printf '%s\n' "${VIDEO_LABELS[@]}" | _manga_rofi_menu "all videos")
        [[ -z "$idx" ]] && exit 0

        choice="${VIDEO_PATHS[$idx]}"
        [[ -z "$choice" ]] && exit 0

        file="$HOME/$choice"
        [[ -f "$file" ]] || exit 0

        _video_add_history "$choice"
        mpv "$file" >/dev/null 2>&1 &
        exit 0
    fi

    if [[ "$selected_entry" == "LONGEST" ]]; then
        declare -a VIDEO_PATHS VIDEO_LABELS
        while IFS=$'\t' read -r path size duration; do
            [[ -z "$path" ]] && continue
            [[ "$path" == "$LAST_WATCHED" ]] && continue
            VIDEO_PATHS+=("$path")
            VIDEO_LABELS+=("$(printf '%-7s %-10s %s' "$size" "$duration" "$path")")
        done < <(awk -F'\t' '{split($3,a,":"); secs=a[1]*3600+a[2]*60+a[3]; print secs "\t" $0}' "$VIDEO_CACHE_FILE" | sort -t$'\t' -k1,1nr | cut -f2-)

        [[ ${#VIDEO_PATHS[@]} -eq 0 ]] && exit 0

        idx=$(printf '%s\n' "${VIDEO_LABELS[@]}" | _manga_rofi_menu "longest videos")
        [[ -z "$idx" ]] && exit 0

        choice="${VIDEO_PATHS[$idx]}"
        [[ -z "$choice" ]] && exit 0

        file="$HOME/$choice"
        [[ -f "$file" ]] || exit 0

        _video_add_history "$choice"
        mpv "$file" >/dev/null 2>&1 &
        exit 0
    fi

    local folder_choice
    folder_choice="$selected_entry"

    declare -a VIDEO_PATHS VIDEO_LABELS
    while IFS=$'\t' read -r path size duration; do
        [[ -z "$path" ]] && continue
        [[ "$path" == "$LAST_WATCHED" ]] && continue
        local base
        base="${path##*/}"
        VIDEO_PATHS+=("$path")
        VIDEO_LABELS+=("$(printf '%-7s %-10s %s' "$size" "$duration" "$base")")
    done < <(grep -F "$folder_choice/" "$VIDEO_CACHE_FILE")

    [[ ${#VIDEO_PATHS[@]} -eq 0 ]] && exit 0

    idx=$(printf '%s\n' "${VIDEO_LABELS[@]}" | _manga_rofi_menu "$folder_choice")
    [[ -z "$idx" ]] && exit 0

    choice="${VIDEO_PATHS[$idx]}"
    [[ -z "$choice" ]] && exit 0

    file="$HOME/$choice"
    [[ -f "$file" ]] || exit 0

    _video_add_history "$choice"
    mpv "$file" >/dev/null 2>&1 &
}

run_video_menu() {
    pkill -x rofi 2>/dev/null
    _video_refresh_cache
    [[ ! -f "$VIDEO_CACHE_FILE" ]] && exit 0

    if [[ "$VIDEO_GROUP_BY_FOLDER" == true ]]; then
        _run_video_menu_by_folder
        return
    fi

    _run_video_menu_flat
}

# ----- images -----
_image_find() {
    if command -v fd &>/dev/null; then
        fd -e jpg -e jpeg -e png -e webp -e gif -e bmp -e avif -e svg --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude thumbnails --exclude thumb --exclude '.*' --base-directory "$IMAGE_DIR" 2>/dev/null
    else
        find "$IMAGE_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" -o -path "*/thumbnails" -o -path "*/thumb" \) -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.avif" -o -iname "*.svg" \) -print 2>/dev/null | sed "s|^$HOME/||"
    fi
}

_image_get_mtime() {
    if command -v fd &>/dev/null; then
        fd -e jpg -e jpeg -e png -e webp -e gif -e bmp -e avif -e svg --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude thumbnails --exclude thumb --exclude '.*' -x stat --printf='%Y %s %n\n' . "$IMAGE_DIR" 2>/dev/null | sort | md5sum
    else
        find "$IMAGE_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" -o -path "*/thumbnails" -o -path "*/thumb" \) -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.avif" -o -iname "*.svg" \) -printf '%T@ %s %p\n' 2>/dev/null | sort | md5sum
    fi
}

_image_build_cache() {
    local tmp
    tmp=$(mktemp)
    mkdir -p "$IMAGE_CACHE_DIR"
    _image_find > "$tmp"
    mv "$tmp" "$IMAGE_CACHE_FILE"
    _image_get_mtime > "$IMAGE_CACHE_MTIME"
}

_image_refresh_cache() {
    if [[ ! -f "$IMAGE_CACHE_FILE" ]] || [[ ! -f "$IMAGE_CACHE_MTIME" ]]; then
        _image_build_cache
        return
    fi
    local current cached
    current=$(_image_get_mtime)
    cached=$(cat "$IMAGE_CACHE_MTIME")
    [[ "$current" != "$cached" ]] && _image_build_cache
}

_image_open() {
    local file="$1"
    local dir viewer
    dir=$(dirname "$file")

    if command -v swayimg &>/dev/null; then
        viewer="swayimg"
    elif command -v imv &>/dev/null; then
        viewer="imv"
    else
        xdg-open "$file" >/dev/null 2>&1 &
        return
    fi

    # Open all images in the folder so user can swipe,
    # and track the last viewed file via /proc/PID/fd/
    (
        cd "$dir" 2>/dev/null || exit

        local -a images
        while IFS= read -r -d '' img; do
            images+=("$img")
        done < <(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.avif" -o -iname "*.svg" \) -print0 2>/dev/null | sort -zV)

        "${viewer}" "${images[@]}" >/dev/null 2>&1 &
        local pid=$!

        local last="$file"
        while kill -0 "$pid" 2>/dev/null; do
            local current
            current=$(readlink "/proc/${pid}/fd/"* 2>/dev/null | grep -iE '\.(jpg|jpeg|png|webp|gif|bmp|avif|svg)$' | tail -1)
            [[ -n "$current" ]] && last="$current"
            sleep 1
        done

        local rel="${last#$HOME/}"
        if [[ "$rel" != "$last" ]]; then
            _image_add_history "$rel"
        fi
    ) & disown
}

_image_add_history() {
    mkdir -p "$(dirname "$IMAGE_HISTORY")"
    local tmp
    tmp=$(mktemp)
    grep -Fxv "$1" "$IMAGE_HISTORY" 2>/dev/null > "$tmp"
    printf '%s\n' "$1" >> "$tmp"
    mv "$tmp" "$IMAGE_HISTORY"
}

_image_recent() {
    if command -v fd &>/dev/null; then
        fd -e jpg -e jpeg -e png -e webp -e gif -e bmp -e avif -e svg --exclude .cache --exclude .local --exclude .config --exclude node_modules --exclude thumbnails --exclude thumb --exclude '.*' -x stat --printf='%Y\t%n\n' . "$HOME" 2>/dev/null \
        | sort -t$'\t' -k1,1nr \
        | cut -f2- \
        | head -n 20
    else
        find "$HOME" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.avif" -o -iname "*.svg" \) \
            -printf '%T@\t%p\n' 2>/dev/null \
        | sort -t$'\t' -k1,1nr \
        | cut -f2- \
        | head -n 20
    fi
}

_image_open_recent() {
    local dir
    dir=$(mktemp -d /tmp/images-recent.XXXXXX)

    local count=0
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        ln -s "$filepath" "$dir/$(printf '%03d' $count)_$(basename "$filepath")" 2>/dev/null
        ((count++))
    done < <(_image_recent)

    [[ $count -eq 0 ]] && rm -rf "$dir" && exit 0

    local first
    first=$(ls -1v "$dir" 2>/dev/null | head -1)

    if command -v swayimg &>/dev/null; then
        swayimg "$dir/$first" >/dev/null 2>&1 &
    elif command -v imv &>/dev/null; then
        imv "$dir/$first" >/dev/null 2>&1 &
    else
        xdg-open "$dir/$first" >/dev/null 2>&1 &
    fi
}

run_image_menu() {
    pkill -x rofi 2>/dev/null
    _image_refresh_cache
    [[ ! -f "$IMAGE_CACHE_FILE" ]] && exit 0

    local root_display="~"

    declare -a MENU_ENTRIES MENU_LABELS
    local LAST_OPENED
    LAST_OPENED=$(tail -n 1 "$IMAGE_HISTORY" 2>/dev/null)
    if [[ -n "$LAST_OPENED" ]]; then
        MENU_ENTRIES+=("LAST")
        MENU_LABELS+=("➜ last")
    fi

    MENU_ENTRIES+=("RECENT")
    MENU_LABELS+=("➜ recent")

    while IFS=$'\t' read -r count folder; do
        [[ -z "$folder" ]] && continue
        if [[ "$folder" == "." ]]; then
            MENU_ENTRIES+=(".")
            MENU_LABELS+=("$(printf '(%s)\t%s' "$count" "$root_display")")
        else
            MENU_ENTRIES+=("$folder")
            MENU_LABELS+=("$(printf '(%s)\t%s' "$count" "$folder")")
        fi
    done < <(
        awk '{n=$0; sub(/\/[^\/]+$/,"",n); if (n == $0) n="."; c[n]++} END {for (k in c) print c[k] "\t" k}' "$IMAGE_CACHE_FILE" \
        | sort -t$'\t' -k1,1rn
    )

    [[ ${#MENU_ENTRIES[@]} -eq 0 ]] && exit 0

    local idx
    idx=$(printf '%s\n' "${MENU_LABELS[@]}" | _manga_rofi_menu "images")
    [[ -z "$idx" ]] && exit 0

    local selected_folder="${MENU_ENTRIES[$idx]}"
    [[ -z "$selected_folder" ]] && exit 0

    if [[ "$selected_folder" == "LAST" ]]; then
        local last_file="$HOME/$LAST_OPENED"
        [[ -f "$last_file" ]] || exit 0
        _image_open "$last_file"
        exit 0
    fi

    if [[ "$selected_folder" == "RECENT" ]]; then
        _image_open_recent
        exit 0
    fi

    declare -a IMAGE_PATHS IMAGE_LABELS
    if [[ "$selected_folder" == "." ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            IMAGE_PATHS+=("$path")
            IMAGE_LABELS+=("${path##*/}")
        done < <(grep -v '/' "$IMAGE_CACHE_FILE")
    else
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            IMAGE_PATHS+=("$path")
            IMAGE_LABELS+=("${path##*/}")
        done < <(grep -F "$selected_folder/" "$IMAGE_CACHE_FILE")
    fi

    [[ ${#IMAGE_PATHS[@]} -eq 0 ]] && exit 0

    idx=$(printf '%s\n' "${IMAGE_LABELS[@]}" | _manga_rofi_menu "$selected_folder")
    [[ -z "$idx" ]] && exit 0

    local choice="${IMAGE_PATHS[$idx]}"
    [[ -z "$choice" ]] && exit 0

    local file="$HOME/$choice"
    [[ -f "$file" ]] || exit 0

    _image_add_history "$choice"
    _image_open "$file"
}

# ----- files -----
_files_get_mtime() {
    find "$HOME" -maxdepth 2 -type d ! -path "*/.local" ! -path "*/.cache" -printf '%T@ %p\n' 2>/dev/null | sort | md5sum
}

_files_build_cache() {
    local tmp
    tmp=$(mktemp)
    mkdir -p "$FILES_CACHE_DIR"

    find "$HOME" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" -o -path "*/target" -o -path "*/build" -o -path "*/dist" \) -prune -o -type d -print 2>/dev/null | sed "s|$HOME/||" | head -n $FILES_LIMIT | \
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf 'dir\t%s\n' "$line"
        done >> "$tmp"

    find "$HOME" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" -o -path "*/target" -o -path "*/build" -o -path "*/dist" \) -prune -o -type f -print 2>/dev/null | sed "s|$HOME/||" | head -n $FILES_LIMIT | \
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf 'file\t%s\n' "$line"
        done >> "$tmp"

    mv "$tmp" "$FILES_CACHE_FILE"
    _files_get_mtime > "$FILES_CACHE_MTIME"
}

_files_refresh_cache() {
    if [[ ! -f "$FILES_CACHE_FILE" ]] || [[ ! -f "$FILES_CACHE_MTIME" ]]; then
        _files_build_cache
        return
    fi
    local current_mtime
    current_mtime=$(_files_get_mtime)
    local cached_mtime
    cached_mtime=$(cat "$FILES_CACHE_MTIME")
    if [[ "$current_mtime" != "$cached_mtime" ]]; then
        _files_build_cache
    fi
}

_files_get_count() {
    local type="$1"
    awk -F'\t' '$1 == "'"$type"'" {count++} END {print count+0}' "$FILES_CACHE_FILE" 2>/dev/null
}

_files_get_text_count() {
    grep -E $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$FILES_CACHE_FILE" | wc -l
}

_files_get_config_count() {
    local dirs=(aria2 gallery-dl kitty rofi swayimg mpv swaync fish yt-dlp zathura hypr waybar)
    local count=0
    for d in "${dirs[@]}"; do
        [[ -d "$HOME/.config/$d" ]] && ((count++))
        if [[ -d "$HOME/.config/$d" ]]; then
            count=$((count + $(find "$HOME/.config/$d" -type f 2>/dev/null | wc -l)))
        fi
    done
    echo "$count"
}

_files_save_history() {
    mkdir -p "$(dirname "$FILES_HISTORY")"
    local tmp
    tmp=$(mktemp)
    grep -Fxv "$1" "$FILES_HISTORY" 2>/dev/null > "$tmp"
    printf '%s\n' "$1" >> "$tmp"
    mv "$tmp" "$FILES_HISTORY"
}

run_files_menu() {
    pkill -x rofi 2>/dev/null
    _files_refresh_cache

    local file_count=$(_files_get_count file)
    local dir_count=$(_files_get_count dir)
    local text_count=$(_files_get_text_count)
    local config_count=$(_files_get_config_count)

    local LAST_READ=$(tail -n 1 "$FILES_HISTORY" 2>/dev/null | grep -v '^$')
    local menu_entries=""
    [[ -n "$LAST_READ" ]] && menu_entries+="➜  last\n"
    menu_entries+="󰉋  All Folders ($dir_count)\n󰈙  All Files ($file_count)\n󰈙  Text Files ($text_count)\n󰒓  Cfg Files ($config_count)\n󰈙  Other Files"

    local chosen=$(printf '%b' "$menu_entries" | _manga_rofi_menu "❀  fd:" 6)
    [ -z "$chosen" ] && exit 0

    local file=""

    if [[ "$chosen" == "➜  last" ]]; then
        file="$LAST_READ"
        local fullpath="$HOME/$file"
        if [ -f "$fullpath" ] || [ -d "$fullpath" ]; then
            if command -v nvim &>/dev/null; then
                nohup nvim "$fullpath" >/dev/null 2>&1 &
            else
                nohup zeditor "$fullpath" >/dev/null 2>&1 &
            fi
        else
            "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 2000 0 "fontsize:16 󰅙 last not found"
        fi
        exit 0
    fi

    if [[ "$chosen" == *"All Folders"* ]]; then
        file=$(grep $'^dir\t' "$FILES_CACHE_FILE" | cut -f2 | sed 's/^/󰉋  /' | _manga_rofi_menu "󰉋  Folders:")
        file="${file#󰉋  }"

    elif [[ "$chosen" == *"All Files"* ]]; then
        file=$(grep $'^file\t' "$FILES_CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _manga_rofi_menu "󰈙  Files:")
        file="${file#󰈙  }"

    elif [[ "$chosen" == *"Text Files"* ]]; then
        file=$(grep -E $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$FILES_CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _manga_rofi_menu "󰈙  Text:")
        file="${file#󰈙  }"

    elif [[ "$chosen" == *"Cfg Files"* ]]; then
        local config_dirs=(aria2 gallery-dl kitty rofi swayimg mpv swaync fish yt-dlp zathura hypr waybar)
        local config_entries="󰒓  Open All\n"
        for d in "${config_dirs[@]}"; do
            if [[ -d "$HOME/.config/$d" ]]; then
                config_entries+="󰉋  $d\n"
                while IFS= read -r f; do
                    local rel=$(echo "$f" | sed "s|$HOME/.config/$d/||")
                    config_entries+="󰈙  $d/$rel\n"
                done < <(find "$HOME/.config/$d" -type f 2>/dev/null | sort)
            fi
        done
        file=$(printf '%b' "$config_entries" | _manga_rofi_menu "󰒓  Cfg:")
        [[ "$file" == "󰒓  Open All" ]] && {
            if command -v nvim &>/dev/null; then
                zeditor "$HOME/.config/aria2" "$HOME/.config/gallery-dl" "$HOME/.config/kitty" "$HOME/.config/rofi" "$HOME/.config/swayimg" "$HOME/.config/mpv" "$HOME/.config/swaync" "$HOME/.config/fish" "$HOME/.config/yt-dlp" "$HOME/.config/zathura" "$HOME/.config/hypr" "$HOME/.config/waybar" &>/dev/null &
            else
                zeditor "$HOME/.config/aria2" "$HOME/.config/gallery-dl" "$HOME/.config/kitty" "$HOME/.config/rofi" "$HOME/.config/swayimg" "$HOME/.config/mpv" "$HOME/.config/swaync" "$HOME/.config/fish" "$HOME/.config/yt-dlp" "$HOME/.config/zathura" "$HOME/.config/hypr" "$HOME/.config/waybar" &>/dev/null &
            fi
            exit 0
        }
        file="${file#󰉋  }"
        file="${file#󰈙  }"
        [[ -n "$file" ]] && file=".config/$file"

    else
        file=$(grep -Ev $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$FILES_CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _manga_rofi_menu "󰈙  Other:")
        file="${file#󰈙  }"
    fi

    [ -z "$file" ] && exit 0

    local fullpath="$HOME/$file"

    if [ -d "$fullpath" ]; then
        if command -v nvim &>/dev/null; then
            nohup nvim "$fullpath" >/dev/null 2>&1 &
        else
            nohup zeditor "$fullpath" >/dev/null 2>&1 &
        fi
        _files_save_history "$file"
    elif [ -f "$fullpath" ]; then
        case "$fullpath" in
            *.sh|*.txt|*.py|*.lua|*.json|*.js|*.ts|*.css|*.html|*.conf|*.md|*.rs|*.toml|*.xml|*.yaml|*.yml|*.ini|*.c|*.cpp|*.h|*.hpp|*.go|*.java|*.rb|*.php|*.sql|*.fish|*.desktop|*.service|*.bash|*.zsh|*.vim|*.nvim|*.log)
                nvim "$fullpath" &>/dev/null &
                ;;
            *.cbz|*.cbr|*.pdf)
                zathura "$fullpath" &>/dev/null &
                ;;
            *.mp4|*.mp3|*.mkv|*.webm|*.avi|*.mov|*.flv|*.m4a|*.ogg|*.flac|*.wav|*.aac|*.opus|*.wma)
                mpv "$fullpath" &>/dev/null &
                ;;
            *)
                xdg-open "$fullpath" &>/dev/null &
                ;;
        esac
        _files_save_history "$file"
    else
        "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 2000 0 "fontsize:16 󰅙 not found"
    fi
}

run_power_menu() {
    case "$(printf '❀  Shutdown\n❀  Reboot\n❀  Logout' | rofi_menu "❀  Power:" 3)" in
        *Shutdown) systemctl poweroff ;;
        *Reboot) systemctl reboot ;;
        *Logout) hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    esac
}

[[ -f "$MANGA_CACHE_FILE" ]] && manga_count=$(wc -l < "$MANGA_CACHE_FILE" 2>/dev/null)
[[ -f "$VIDEO_CACHE_FILE" ]] && video_count=$(wc -l < "$VIDEO_CACHE_FILE" 2>/dev/null)
[[ -f "$IMAGE_CACHE_FILE" ]] && image_count=$(wc -l < "$IMAGE_CACHE_FILE" 2>/dev/null)
manga_count=${manga_count:-0}
video_count=${video_count:-0}
image_count=${image_count:-0}

main_menu_items=()
main_menu_items+=('❀  Search All ('"$all_count"')')
main_menu_items+=('❀  Websites ('"$websites_count"')')
main_menu_items+=('❀  Cfg ('"$config_count"')')
[[ "$manga_count" -gt 0 ]] && main_menu_items+=('❀  Mangas ('"$manga_count"')')
main_menu_items+=('❀  Manga Reader')
[[ "$video_count" -gt 0 ]] && main_menu_items+=('❀  Videos ('"$video_count"')')
[[ "$image_count" -gt 0 ]] && main_menu_items+=('❀  Images ('"$image_count"')')
main_menu_items+=('❀  Files')
main_menu_items+=('❀  Power')
chosen=$(printf '%s\n' "${main_menu_items[@]}" | rofi_menu "❀  tr:" "${#main_menu_items[@]}")
case "$chosen" in
    '.'*)  handle_bang "$chosen" ;;
    *Search*) run_search_all ;;
    *Websites*) run_websites_menu ;;
    *Cfg*) run_config_menu ;;
    *Manga\ Reader*) run_manga_reader ;;
    *Mangas*) run_manga_menu ;;
    *Videos*) run_video_menu ;;
    *Images*) run_image_menu ;;
    *Files*)  run_files_menu ;;
    *Power*)  run_power_menu ;;
esac
