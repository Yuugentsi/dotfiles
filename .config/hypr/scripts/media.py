#!/usr/bin/env -S python3 -B
import sys
sys.dont_write_bytecode = True
import os
import subprocess
import hashlib
import json
import re
import secrets
import shutil
import signal
import tempfile
import unicodedata
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

ROFI_THEME = [
    "-theme-str", "listview { columns: 1; lines: 12; fixed-height: false; dynamic: true; }",
]
def notify(color: str, text: str):
    subprocess.Popen(
        [os.path.expanduser("~/.config/hypr/scripts/quickshell.sh"), "notify", "-1", "1500", color, f"fontsize:16 {text}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def rofi_dmenu(prompt: str, options: list[str]) -> str:
    cmd = ["rofi", "-dmenu", "-i", "-no-custom", "-p", prompt] + ROFI_THEME
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        stdout, _ = proc.communicate(input="\n".join(options))
        return stdout.strip()
    except Exception:
        return ""

# ─────────── music ───────────
MUSIC_DIR = os.path.expanduser("~/0/music")
PLAYED_FILE = "/tmp/music_played.txt"
LEGACY_SOCKET = "/tmp/mpv_music_socket"
ENGINE_DIR = os.path.expanduser("~/.config/quickshell/scripts")
MUSIC_EXTENSIONS = {".mp3", ".flac", ".ogg", ".wav", ".opus", ".m4a", ".aac"}
OWN_PLAYERS = "mpv,playerctld,y_music"

def engine():
    if ENGINE_DIR not in sys.path:
        sys.path.insert(0, ENGINE_DIR)
    import player
    return player

def engine_state():
    try:
        return engine().audio_request("state", start=False)
    except Exception:
        return None

def is_music_active() -> bool:
    current = engine_state()
    return bool(current and current.get("path"))

def quit_legacy_player():
    import socket
    try:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(1)
            connection.connect(LEGACY_SOCKET)
            connection.sendall(b'{"command": ["quit"]}\n')
    except OSError:
        pass

def stop_engine():
    quit_legacy_player()
    try:
        engine().audio_request("stop", start=False)
    except Exception:
        pass

def stop_music():
    stop_engine()
    notify("rgb(f38ba8)", "󰎊  Music stopped")

def scan_music():
    if not os.path.isdir(MUSIC_DIR):
        return []
    files = []
    def _walk(path):
        try:
            with os.scandir(path) as it:
                for entry in it:
                    if entry.name[0] == ".":
                        continue
                    if entry.is_dir(follow_symlinks=False):
                        _walk(entry.path)
                    elif entry.is_file(follow_symlinks=False):
                        dot = entry.name.rfind(".")
                        if dot != -1 and entry.name[dot:].lower() in MUSIC_EXTENSIONS:
                            files.append(entry.path)
        except OSError:
            pass
    _walk(MUSIC_DIR)
    return files

def play_queue(queue: list[str], title: str | None = None):
    if not queue:
        return
    quit_legacy_player()
    try:
        engine().play_queue(queue[0], queue)
    except Exception as error:
        notify("rgb(f38ba8)", f"󰎊  {error}")
        return
    if title is None:
        first = queue[0]
        bname = first[first.rfind("/") + 1:]
        dot = bname.rfind(".")
        title = bname[:dot] if dot != -1 else bname
    notify("rgb(cba6f7)", f"󰎇  {title}")

def play_random():
    import random
    files = scan_music()
    if not files:
        return

    played = set()
    if os.path.isfile(PLAYED_FILE):
        try:
            with open(PLAYED_FILE, "r", encoding="utf-8", errors="ignore") as fp:
                played = set(fp.read().splitlines())
        except Exception:
            pass

    available = [f for f in files if f not in played]
    if not available:
        played = set()
        available = files

    chosen = random.choice(available)
    played.add(chosen)

    try:
        with open(PLAYED_FILE, "w", encoding="utf-8") as fp:
            fp.write("\n".join(played) + "\n")
    except Exception:
        pass

    remaining_available = [f for f in available if f != chosen]
    random.shuffle(remaining_available)
    played_files = [f for f in files if f in played and f != chosen]
    random.shuffle(played_files)

    queue = [chosen] + remaining_available + played_files
    play_queue(queue)

def play_files_shuffled(file_list: list[str], all_files=None):
    if not file_list:
        return
    import random
    queue = list(file_list)
    random.shuffle(queue)
    if all_files is None:
        all_files = scan_music()
    others = [f for f in all_files if f not in queue]
    random.shuffle(others)
    play_queue(queue + others)

def show_tracklist(file_list: list[str], prompt: str, prefix_artist=True, all_files=None):
    if not file_list:
        return
    import random
    display_map = {}
    items = []
    m_prefix = len(MUSIC_DIR) + 1

    for f in sorted(file_list, key=lambda x: x[x.rfind("/") + 1:].lower()):
        rel = f[m_prefix:]
        parts = rel.split("/")
        if not prefix_artist:
            if len(parts) >= 3:
                alb = parts[-2]
                name = parts[-1]
                dot = name.rfind(".")
                disp = f"{alb} / {name[:dot] if dot != -1 else name}"
            else:
                name = parts[-1]
                dot = name.rfind(".")
                disp = name[:dot] if dot != -1 else name
        else:
            if len(parts) == 1:
                name = parts[0]
                dot = name.rfind(".")
                disp = name[:dot] if dot != -1 else name
            elif len(parts) == 2:
                artist = parts[0]
                name = parts[1]
                dot = name.rfind(".")
                disp = f"{artist} - {name[:dot] if dot != -1 else name}"
            else:
                artist = parts[0]
                alb = parts[1]
                name = parts[2]
                dot = name.rfind(".")
                disp = f"{artist} - {alb} / {name[:dot] if dot != -1 else name}"

        items.append(disp)
        display_map[disp] = f

    chosen = rofi_dmenu(prompt, items)
    if not chosen:
        return

    f = display_map.get(chosen)
    if f and os.path.isfile(f):
        sel_idx = file_list.index(f) if f in file_list else 0
        subsequent = file_list[sel_idx:] + file_list[:sel_idx]
        if all_files is None:
            all_files = scan_music()
        others = [x for x in all_files if x not in file_list]
        random.shuffle(others)
        play_queue(subsequent + others)

def run_menu():
    all_files = scan_music()
    if not all_files:
        return

    if not is_music_active():
        play_random()

    tree = {}
    m_prefix = len(MUSIC_DIR) + 1
    for f in all_files:
        rel = f[m_prefix:]
        parts = rel.split("/")
        if len(parts) == 1:
            top = "Various"
            sub = ""
        elif len(parts) == 2:
            top = parts[0]
            sub = ""
        else:
            top = parts[0]
            sub = parts[1]

        if top not in tree:
            tree[top] = {}
        if sub not in tree[top]:
            tree[top][sub] = []
        tree[top][sub].append(f)

    options = []

    try:
        out = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{status}}:::{{artist}}:::{{title}}"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
        if out:
            p_parts = out.split(":::")
            status = p_parts[0] if len(p_parts) > 0 else ""
            artist = p_parts[1] if len(p_parts) > 1 else ""
            title = p_parts[2] if len(p_parts) > 2 else ""
            if status in {"Playing", "Paused"} and title:
                now_playing = f"󰎇  {artist} — {title}" if artist else f"󰎇  {title}"
                options.append(now_playing)
    except Exception:
        pass

    all_count = len(all_files)
    all_option = f"󰒓  ALL ({all_count})"
    tracklist_option = f"󰎸  Tracklist ({all_count})"
    options.append(all_option)
    options.append(tracklist_option)

    top_entries = []
    for top, subs in tree.items():
        total_top_tracks = sum(len(tracks) for tracks in subs.values())
        top_entries.append((top, total_top_tracks))
    top_entries.sort(key=lambda x: (-x[1], x[0].lower()))

    for top, count in top_entries:
        options.append(f"󰎈  {top} ({count})")

    chosen = rofi_dmenu("󰝚  Artist:", options)
    if not chosen:
        return

    if chosen == all_option:
        play_files_shuffled(all_files, all_files=all_files)
        return

    if chosen == tracklist_option:
        show_tracklist(all_files, "  Track:", prefix_artist=True, all_files=all_files)
        return

    chosen_top = None
    for top, _ in top_entries:
        if chosen.startswith(f"󰎈  {top} ("):
            chosen_top = top
            break

    if not chosen_top or chosen_top not in tree:
        return

    top_dict = tree[chosen_top]
    top_all_files = []
    for subs in top_dict.values():
        top_all_files.extend(subs)

    subfolders = [s for s in top_dict.keys() if s]
    if not subfolders:
        sub_options = [
            f"󰒓  ALL ({len(top_all_files)})",
            f"󰎸  Tracklist ({len(top_all_files)})"
        ]
        sub_chosen = rofi_dmenu("󰀥  Album:", sub_options)
        if not sub_chosen:
            return
        if sub_chosen.startswith("󰒓  ALL"):
            play_files_shuffled(top_all_files, all_files=all_files)
        elif sub_chosen.startswith("󰎸  Tracklist"):
            show_tracklist(top_all_files, "  Track:", prefix_artist=False, all_files=all_files)
        return

    album_options = [
        f"󰒓  ALL ({len(top_all_files)})",
        f"󰎸  Tracklist ({len(top_all_files)})"
    ]
    for sub in sorted(subfolders, key=lambda s: (-len(top_dict[s]), s.lower())):
        album_options.append(f"󰀥  {sub} ({len(top_dict[sub])})")

    if "" in top_dict and top_dict[""]:
        album_options.append(f"󰀥  (Loose Tracks) ({len(top_dict[''])})")

    album_chosen = rofi_dmenu("󰀥  Album:", album_options)
    if not album_chosen:
        return

    if album_chosen.startswith("󰒓  ALL"):
        play_files_shuffled(top_all_files, all_files=all_files)
        return

    if album_chosen.startswith("󰎸  Tracklist"):
        show_tracklist(top_all_files, "  Track:", prefix_artist=False, all_files=all_files)
        return

    chosen_sub = None
    for sub in subfolders:
        if album_chosen.startswith(f"󰀥  {sub} ("):
            chosen_sub = sub
            break
    if album_chosen.startswith("󰀥  (Loose Tracks)"):
        chosen_sub = ""

    if chosen_sub is not None and chosen_sub in top_dict:
        sub_files = top_dict[chosen_sub]
        show_tracklist(sub_files, "  Track:", prefix_artist=False, all_files=all_files)

def is_external_playing() -> bool:
    try:
        res = subprocess.run(
            ["playerctl", "-i", OWN_PLAYERS, "-a", "status"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return "Playing" in res.stdout
    except Exception:
        return False

def notify_current_title():
    current = engine_state()
    if not current:
        return
    tags = current.get("metadata") or {}
    path = current.get("path") or ""
    title = tags.get("TITLE") or tags.get("title") or (path[path.rfind("/") + 1:].rsplit(".", 1)[0] if path else "")
    if title:
        notify("rgb(cba6f7)", f"󰎇  {title}")

def next_or_random():
    import time
    if is_external_playing():
        stop_engine()
        subprocess.run(["playerctl", "-i", OWN_PLAYERS, "next"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.15)
        try:
            res = subprocess.run(
                ["playerctl", "-i", OWN_PLAYERS, "metadata", "--format", "{{title}}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            title = res.stdout.strip()
            if title:
                notify("rgb(cba6f7)", f"󰎇  {title}")
        except Exception:
            pass
    elif is_music_active():
        try:
            engine().audio_request("next", start=False)
        except Exception:
            return
        time.sleep(0.15)
        notify_current_title()
    else:
        play_random()

# ─────────── video ───────────
VIDEOS_DIR = os.path.expanduser("~/0/videos")
RECENT_VIDEO_FILE = os.path.expanduser("~/.cache/media_recent_video.txt")
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".flv", ".m4v"}
RE_EPISODE = None
RE_DIGITS = None

def init_video_regex():
    global RE_EPISODE, RE_DIGITS
    if RE_EPISODE is None:
        import re
        RE_EPISODE = re.compile(r"(?:s(\d+))?e(?:p)?\s*(\d+)", re.IGNORECASE)
        RE_DIGITS = re.compile(r"(\d+)")

def is_video(filename: str) -> bool:
    if filename.endswith(".part"):
        return False
    dot = filename.rfind(".")
    return dot != -1 and filename[dot:].lower() in VIDEO_EXTENSIONS

def video_sort_key(filepath: str):
    name = filepath[filepath.rfind("/") + 1:].lower()
    m = RE_EPISODE.search(name)
    if m:
        season = int(m.group(1)) if m.group(1) else 0
        return (0, season, int(m.group(2)), name)
    parts = RE_DIGITS.split(name)
    return (1, [int(p) if p.isdigit() else p for p in parts])

def scan_videos():
    if not os.path.isdir(VIDEOS_DIR):
        return [], {}

    init_video_regex()
    all_files = []
    tree = {}

    def _walk(path, rel_dir):
        try:
            with os.scandir(path) as it:
                for entry in it:
                    name = entry.name
                    if name[0] == ".":
                        continue
                    if entry.is_dir(follow_symlinks=False):
                        new_rel = name if not rel_dir else f"{rel_dir}/{name}"
                        _walk(entry.path, new_rel)
                    elif entry.is_file(follow_symlinks=False) and is_video(name):
                        all_files.append(entry.path)
                        f_key = rel_dir if rel_dir else "Root"
                        if f_key not in tree:
                            tree[f_key] = []
                        tree[f_key].append(entry.path)
        except OSError:
            pass

    _walk(VIDEOS_DIR, "")
    all_files.sort(key=video_sort_key)
    for k in tree:
        tree[k].sort(key=video_sort_key)

    return all_files, tree

def set_recent_video(file_path: str):
    try:
        with open(RECENT_VIDEO_FILE, "w", encoding="utf-8") as fp:
            fp.write(file_path)
    except Exception:
        pass

def get_recent_video(all_files=None):
    if os.path.isfile(RECENT_VIDEO_FILE):
        try:
            with open(RECENT_VIDEO_FILE, "r", encoding="utf-8") as fp:
                path = fp.read().strip()
                if path and os.path.isfile(path):
                    return path
        except Exception:
            pass
    if all_files:
        try:
            return max(all_files, key=lambda f: os.path.getmtime(f))
        except Exception:
            pass
    return None

def play_video(file_path: str, playlist_context: list[str] = None):
    if not os.path.isfile(file_path):
        return
    set_recent_video(file_path)
    bname = file_path[file_path.rfind("/") + 1:]
    dot = bname.rfind(".")
    title = bname[:dot] if dot != -1 else bname
    disp = (title[:40] + "...") if len(title) > 43 else title
    notify("rgb(cba6f7)", f"🎬  {disp}")

    playlist = [file_path]
    if playlist_context and file_path in playlist_context:
        idx = playlist_context.index(file_path)
        playlist = playlist_context[idx:]

    subprocess.Popen(
        ["mpv", "--autocreate-playlist=no"] + playlist,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

def show_video_folder(folder_name: str, file_list: list[str]):
    count = len(file_list)
    options = ["󰌍  .. (Back)"]
    mapping = {"󰌍  .. (Back)": "back"}

    if count > 1:
        play_all_lbl = f"󰐊  Play all ({count})"
        options.append(play_all_lbl)
        mapping[play_all_lbl] = "play_all"

    for f in file_list:
        bname = f[f.rfind("/") + 1:]
        dot = bname.rfind(".")
        name = bname[:dot] if dot != -1 else bname
        lbl = f"󰕼  {name}"
        options.append(lbl)
        mapping[lbl] = f

    chosen = rofi_dmenu(f"󰉋  {folder_name}:", options)
    if not chosen or mapping.get(chosen) == "back":
        return "back"

    action = mapping.get(chosen)
    if action == "play_all":
        play_video(file_list[0], file_list)
        return "done"
    elif action:
        play_video(action, file_list)
        return "done"

    return None

def show_all_videos(all_files: list[str]):
    options = ["󰌍  .. (Back)"]
    mapping = {"󰌍  .. (Back)": "back"}
    v_prefix = len(VIDEOS_DIR) + 1

    for f in all_files:
        lbl = f"󰕼  {f[v_prefix:]}"
        options.append(lbl)
        mapping[lbl] = f

    chosen = rofi_dmenu("󰒓  All Videos:", options)
    if not chosen or mapping.get(chosen) == "back":
        return "back"

    target = mapping.get(chosen)
    if target:
        play_video(target, all_files)
        return "done"

    return None

def run_video_menu():
    all_files, tree = scan_videos()
    if not all_files:
        notify("rgb(f38ba8)", "No videos found in ~/0/videos")
        return

    options = [f"󰒓  All videos ({len(all_files)})"]
    mapping = {options[0]: ("all", None)}

    recent = get_recent_video(all_files)
    if recent:
        bname = recent[recent.rfind("/") + 1:]
        dot = bname.rfind(".")
        rtitle = bname[:dot] if dot != -1 else bname
        recent_lbl = f"󰄉  {rtitle}"
        options.append(recent_lbl)
        mapping[recent_lbl] = ("recent", recent)

    for fld in sorted(tree.keys(), key=lambda x: x.lower()):
        lbl = f"󰉋  {fld}/  ({len(tree[fld])})"
        options.append(lbl)
        mapping[lbl] = ("folder", fld)

    while True:
        chosen = rofi_dmenu("🎬  0/videos:", options)
        if not chosen:
            break

        act = mapping.get(chosen)
        if not act:
            break

        kind, val = act
        if kind == "recent":
            play_video(val, all_files)
            break
        elif kind == "all":
            if show_all_videos(all_files) == "done":
                break
        elif kind == "folder":
            if show_video_folder(val, tree[val]) == "done":
                break

# ─────────── image ───────────
IMAGE_CACHE = Path.home() / '.cache/imgview'
IMAGE_HISTORY = IMAGE_CACHE / 'history.txt'
IMAGE_THUMBS = IMAGE_CACHE / 'thumbs'
IMAGE_PIDFILE = IMAGE_CACHE / 'viewer.pid'
IMAGE_NATIVE = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.jpe': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.bmp': 'image/bmp',
    '.ico': 'image/x-icon',
    '.ppm': 'image/x-portable-pixmap',
    '.pgm': 'image/x-portable-graymap',
    '.pbm': 'image/x-portable-bitmap',
}
IMAGE_CONVERTED = {'.webp', '.avif', '.svg', '.svgz', '.heic', '.heif', '.tif', '.tiff', '.jxl', '.tga', '.qoi', '.dds', '.exr', '.hdr'}
IMAGE_TYPES = set(IMAGE_NATIVE) | IMAGE_CONVERTED
IMAGE_DESKTOP_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp', 'image/avif', 'image/svg+xml', 'image/heic', 'image/heif', 'image/tiff', 'image/jxl', 'image/x-icon', 'image/x-tga', 'image/x-portable-pixmap', 'image/x-portable-graymap', 'image/x-portable-bitmap']
IMAGE_THUMB_SIZE = 384
IMAGE_RAW_THUMB_LIMIT = 350_000
IMAGE_CACHE_DAYS = 30
IMAGE_WARM_LIMIT = 3000
IMAGE_SLOTS = threading.BoundedSemaphore(max(2, (os.cpu_count() or 4) // 2))


def image_natural_key(path):
    return [int(part) if part.isdigit() else part.casefold() for part in re.split(r'(\d+)', path.name)]


def image_search_key(name):
    return ''.join(char for char in unicodedata.normalize('NFKD', name) if not unicodedata.combining(char)).casefold()


def image_to_path(argument):
    if argument.startswith('file://'):
        return Path(unquote(urlparse(argument).path))
    return Path(argument).expanduser()


def image_list_folder(folder):
    try:
        entries = [entry for entry in folder.iterdir() if entry.suffix.lower() in IMAGE_TYPES and entry.is_file()]
    except OSError:
        return []
    return sorted(entries, key=image_natural_key)


def image_collect(arguments):
    paths = [image_to_path(argument).absolute() for argument in arguments] or [Path.cwd()]
    if len(paths) == 1:
        target = paths[0]
        if target.is_dir():
            return image_list_folder(target), 0, True, target
        siblings = image_list_folder(target.parent)
        if target not in siblings:
            siblings = [target] + siblings
        return siblings, siblings.index(target), False, target.parent
    files = []
    for path in paths:
        if path.is_dir():
            files.extend(image_list_folder(path))
        elif path.is_file():
            files.append(path)
    return files, 0, False, None


def image_folder_summary(folder, depth=3, budget=None):
    budget = budget if budget is not None else [400]
    if budget[0] <= 0:
        return None
    budget[0] -= 1
    images = 0
    first = None
    folders = []
    try:
        with os.scandir(folder) as entries:
            for entry in entries:
                if entry.name.startswith('.') or entry.name == 'node_modules':
                    continue
                try:
                    if entry.is_file():
                        if os.path.splitext(entry.name)[1].lower() in IMAGE_TYPES:
                            images += 1
                            path = Path(entry.path)
                            if first is None or image_natural_key(path) < image_natural_key(first):
                                first = path
                    elif entry.is_dir():
                        folders.append(Path(entry.path))
                except OSError:
                    pass
    except OSError:
        return None
    if images:
        return {'count': images, 'folders': len(folders), 'cover': first}
    if depth > 0:
        for sub in sorted(folders, key=image_natural_key):
            found = image_folder_summary(sub, depth - 1, budget)
            if found:
                return {'count': 0, 'folders': len(folders), 'cover': found['cover']}
    return None


def image_subfolders(folder):
    try:
        found = [entry for entry in folder.iterdir() if not entry.name.startswith('.') and entry.name != 'node_modules' and entry.is_dir()]
    except OSError:
        return []
    return sorted(found, key=image_natural_key)[:600]


def image_prune_cache():
    limit = time.time() - IMAGE_CACHE_DAYS * 86400
    for pattern in ('*.png', 'thumbs/*'):
        for entry in IMAGE_CACHE.glob(pattern):
            try:
                if entry.stat().st_atime < limit:
                    entry.unlink()
            except OSError:
                pass


def image_cache_key(path, tag):
    stat = path.stat()
    return hashlib.sha1(f'{tag}\0{path}\0{stat.st_mtime_ns}\0{stat.st_size}'.encode()).hexdigest()


def image_run(command, output, background):
    output.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=output.parent, suffix=output.suffix)
    os.close(handle)
    command = [temporary if part == '{out}' else part for part in command]
    try:
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60, preexec_fn=(lambda: os.nice(15)) if background else None)
        if os.path.getsize(temporary) == 0:
            raise OSError('empty conversion')
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return output


def image_full(path):
    output = IMAGE_CACHE / f'{image_cache_key(path, "full")}.png'
    if output.exists():
        return output
    if path.suffix.lower() in {'.svg', '.svgz'} and shutil.which('rsvg-convert'):
        command = ['rsvg-convert', '-z', '2', '-o', '{out}', str(path)]
    else:
        command = ['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(path), '-frames:v', '1', '-update', '1', '{out}']
    with IMAGE_SLOTS:
        if output.exists():
            return output
        return image_run(command, output, False)


def image_shared_thumbnail(path, modified):
    digest = hashlib.md5(path.as_uri().encode()).hexdigest()
    for size in ('x-large', 'large'):
        shared = Path.home() / '.cache/thumbnails' / size / f'{digest}.png'
        try:
            if shared.stat().st_mtime >= modified:
                return shared
        except OSError:
            pass
    return None


def image_thumbnail(path, background=False):
    stat = path.stat()
    suffix = path.suffix.lower()
    if suffix in IMAGE_NATIVE and stat.st_size <= IMAGE_RAW_THUMB_LIMIT:
        return path, IMAGE_NATIVE[suffix]
    shared = image_shared_thumbnail(path, stat.st_mtime)
    if shared is not None:
        return shared, 'image/png'
    vector = suffix in {'.svg', '.svgz'} and shutil.which('rsvg-convert')
    output = IMAGE_THUMBS / f'{image_cache_key(path, "thumb")}.{"png" if vector else "jpg"}'
    if output.exists():
        return output, 'image/png' if vector else 'image/jpeg'
    if vector:
        command = ['rsvg-convert', '-w', str(IMAGE_THUMB_SIZE), '-h', str(IMAGE_THUMB_SIZE), '-a', '-o', '{out}', str(path)]
    else:
        size = IMAGE_THUMB_SIZE
        command = ['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(path), '-frames:v', '1', '-vf', f'scale={size}:{size}:force_original_aspect_ratio=decrease:flags=bilinear', '-q:v', '4', '-update', '1', '{out}']
    if background:
        image_run(command, output, True)
    else:
        with IMAGE_SLOTS:
            if not output.exists():
                image_run(command, output, False)
    return output, 'image/png' if vector else 'image/jpeg'


def image_warm(files, stop):
    time.sleep(0.8)
    for path in files[:IMAGE_WARM_LIMIT]:
        if stop.is_set():
            return
        try:
            image_thumbnail(path, background=True)
        except (OSError, ValueError, subprocess.SubprocessError):
            pass


def image_install():
    script = Path(__file__).resolve()
    applications = Path.home() / '.local/share/applications'
    desktop = applications / 'imgview.desktop'
    entry = '\n'.join([
        '[Desktop Entry]',
        'Type=Application',
        'Name=imgview',
        'GenericName=Image Viewer',
        'Comment=View images',
        f'Exec={script} image %F',
        'Icon=image-viewer',
        'Terminal=false',
        'Categories=Graphics;Viewer;',
        'MimeType=' + ';'.join(IMAGE_DESKTOP_TYPES) + ';',
        '',
    ])
    first = not desktop.exists()
    try:
        if first or desktop.read_text() != entry:
            applications.mkdir(parents=True, exist_ok=True)
            desktop.write_text(entry)
            subprocess.run(['update-desktop-database', str(applications)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if first:
            subprocess.run(['xdg-mime', 'default', 'imgview.desktop', *IMAGE_DESKTOP_TYPES], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        link = Path.home() / '.local/bin/imgview'
        if link.is_symlink() and link.resolve() != script:
            link.unlink()
        if not link.exists() and not link.is_symlink():
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(script)
    except OSError:
        pass


def image_close_previous():
    try:
        pid = int(IMAGE_PIDFILE.read_text())
        command = Path(f'/proc/{pid}/cmdline').read_bytes()
    except (OSError, ValueError):
        return
    if b'imgview' in command:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def image_claim(pid):
    IMAGE_CACHE.mkdir(parents=True, exist_ok=True)
    IMAGE_PIDFILE.write_text(str(pid))


def image_release():
    try:
        if not Path(f'/proc/{int(IMAGE_PIDFILE.read_text())}').exists():
            IMAGE_PIDFILE.unlink()
    except (OSError, ValueError):
        pass


def image_add_history(path):
    try:
        entry = str(path)
        lines = [line for line in IMAGE_HISTORY.read_text().splitlines() if line != entry] if IMAGE_HISTORY.exists() else []
        lines.append(entry)
        IMAGE_HISTORY.parent.mkdir(parents=True, exist_ok=True)
        IMAGE_HISTORY.write_text(''.join(f'{line}\n' for line in lines[-500:]))
    except OSError:
        pass


IMAGE_QML = r'''
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    id: root
    visible: false
    width: 960; height: 640
    title: (gridMode ? folderName : (current ? current.name : "Images")) + " — imgview"
    color: canvas
    font.family: "Adwaita Sans"
    property string api: API_URL
    property color accent: "#0a84ff"
    property color ink: "#f5f5f7"
    property color secondaryInk: "#98989d"
    property color separator: "#38383a"
    property color surface: "#1c1c1e"
    property color canvas: "#0d0d0f"
    property var files: []
    property string folderName: ""
    property string folderPath: ""
    property string parentPath: ""
    property var dirs: []
    property int hoveredCell: -1
    property int index: 0
    property var current: index >= 0 && index < files.length ? files[index] : null
    property bool gridMode: false
    property bool startedInGrid: false
    property bool viewed: false
    property var filtered: []
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property int angle: 0
    property bool pinnedOverlay: false
    readonly property bool overlay: pinnedOverlay && !gridMode
    property string toast: ""
    property bool shown: false
    readonly property bool animated: current !== null && current.animated
    readonly property Item picture: animated ? animatedPicture : stillPicture
    readonly property real sourceWidth: picture.implicitWidth
    readonly property real sourceHeight: picture.implicitHeight
    readonly property bool sideways: angle % 180 !== 0
    readonly property real boxWidth: sideways ? sourceHeight : sourceWidth
    readonly property real boxHeight: sideways ? sourceWidth : sourceHeight
    readonly property real fitScale: boxWidth > 0 && boxHeight > 0 ? Math.min(viewport.width / boxWidth, viewport.height / boxHeight, 1) : 1
    readonly property real scaleNow: fitScale * zoom
    readonly property bool loading: !gridMode && picture.status === Image.Loading
    readonly property bool failed: current !== null && picture.status === Image.Error

    function imageUrl(i) { return files.length > 0 ? api + "image/" + files[(i + files.length) % files.length].id : "" }
    function thumbUrl(i) { return i >= 0 && i < files.length ? api + "thumb/" + files[i].id : "" }
    function post(action, done) {
        let request = new XMLHttpRequest()
        request.open("POST", api + action)
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE && done) done(request.status === 200 ? JSON.parse(request.responseText) : null)
        }
        request.send()
    }
    function load() {
        let request = new XMLHttpRequest()
        request.open("GET", api + "list")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 200) { present(); return }
            let data = JSON.parse(request.responseText)
            applyListing(data)
            startedInGrid = data.grid && (files.length > 1 || dirs.length > 0)
            viewed = !startedInGrid
            if (startedInGrid) {
                showGrid()
                present()
            }
        }
        request.send()
    }
    function applyListing(data) {
        folderName = data.folder
        folderPath = data.path
        parentPath = data.parent
        dirs = data.dirs
        files = data.files
        index = Math.max(0, Math.min(data.index, files.length - 1))
        refilter(search.text)
    }
    function openDir(path) {
        if (!path) return
        let request = new XMLHttpRequest()
        request.open("GET", api + "list?dir=" + encodeURIComponent(path))
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 200) { notify("Could not open folder"); return }
            let previous = folderPath
            hoveredCell = -1
            search.text = ""
            applyListing(JSON.parse(request.responseText))
            viewed = false
            resetView()
            let position = -1
            for (let k = 0; k < dirs.length; k++) if (dirs[k].path === previous) position = k
            grid.currentIndex = position >= 0 ? filtered.indexOf(-position - 1) : 0
            grid.positionViewAtIndex(Math.max(0, grid.currentIndex), GridView.Contain)
            grid.forceActiveFocus()
        }
        request.send()
    }
    function openEntry(value) {
        if (value === undefined) return
        if (value < 0) openDir(dirs[-value - 1].path)
        else openFromGrid(value)
    }
    function normalize(text) {
        let value = text.trim().toLowerCase()
        try { value = value.normalize("NFKD").replace(/[̀-ͯ]/g, "") } catch (error) {}
        return value
    }
    function refilter(text) {
        let needle = normalize(text)
        let result = []
        for (let k = 0; k < dirs.length; k++)
            if (needle.length === 0 || dirs[k].key.indexOf(needle) >= 0) result.push(-k - 1)
        for (let i = 0; i < files.length; i++)
            if (needle.length === 0 || files[i].key.indexOf(needle) >= 0) result.push(i)
        filtered = result
    }
    function showGrid() {
        gridMode = true
        let position = viewed ? filtered.indexOf(index) : -1
        grid.currentIndex = position >= 0 ? position : 0
        Qt.callLater(function() {
            grid.positionViewAtIndex(grid.currentIndex, GridView.Center)
            grid.forceActiveFocus()
        })
    }
    function openFromGrid(fileIndex) {
        if (fileIndex < 0 || fileIndex >= files.length) return
        index = fileIndex
        angle = 0
        resetView()
        viewed = true
        gridMode = false
        viewport.forceActiveFocus()
    }
    function back() {
        if (help.visible) { help.close(); return }
        if (gridMode) {
            if (search.text.length > 0) { search.text = ""; grid.forceActiveFocus(); return }
            if (viewed) { gridMode = false; viewport.forceActiveFocus(); return }
            close()
            return
        }
        if (visibility === Window.FullScreen) { showNormal(); return }
        if (files.length > 1 || dirs.length > 0) { showGrid(); return }
        close()
    }
    property bool swipeLocked: false
    property real swipeTravel: 0
    function unlockSwipe() { swipeLocked = false; swipeTravel = 0 }
    function swipe(phase, delta) {
        if (phase === Qt.ScrollMomentum) return
        if (phase === Qt.ScrollBegin || phase === Qt.ScrollEnd) { unlockSwipe(); return }
        let touchpad = phase === Qt.ScrollUpdate
        if (touchpad) touchpadQuiet.restart()
        if (swipeLocked || delta === 0) return
        if (swipeTravel !== 0 && (swipeTravel < 0) !== (delta < 0)) swipeTravel = 0
        swipeTravel += delta
        if (Math.abs(swipeTravel) < (touchpad ? 60 : 1)) return
        go(swipeTravel < 0 ? 1 : -1)
        swipeTravel = 0
        swipeLocked = true
        if (!touchpad) wheelLock.restart()
    }
    Timer { id: wheelLock; interval: 180; onTriggered: root.unlockSwipe() }
    Timer { id: touchpadQuiet; interval: 140; onTriggered: root.unlockSwipe() }
    function resetView() { zoom = 1; panX = 0; panY = 0 }
    function go(step) {
        if (files.length < 2) return
        index = (index + step + files.length) % files.length
        angle = 0
        resetView()
    }
    function goTo(i) {
        if (files.length === 0) return
        index = Math.max(0, Math.min(files.length - 1, i))
        angle = 0
        resetView()
    }
    function clampPan() {
        let maxX = Math.max(0, (boxWidth * scaleNow - viewport.width) / 2)
        let maxY = Math.max(0, (boxHeight * scaleNow - viewport.height) / 2)
        panX = Math.max(-maxX, Math.min(maxX, panX))
        panY = Math.max(-maxY, Math.min(maxY, panY))
    }
    function zoomTo(value, px, py) {
        let next = Math.max(0.1, Math.min(40 / Math.max(fitScale, 0.001), value))
        if (px === undefined) { px = viewport.width / 2; py = viewport.height / 2 }
        let dx = px - viewport.width / 2
        let dy = py - viewport.height / 2
        let ratio = next / zoom
        panX = (panX - dx) * ratio + dx
        panY = (panY - dy) * ratio + dy
        zoom = next
        clampPan()
    }
    function actualSize() { zoomTo(1 / fitScale) }
    function rotate(step) { angle = (angle + step + 360) % 360; resetView() }
    function toggleFullScreen() {
        if (!shown) return
        if (visibility === Window.FullScreen) showNormal()
        else showFullScreen()
    }
    function present() {
        if (shown) return
        let w = Math.round(Screen.desktopAvailableWidth * 0.62)
        let h = Math.round(Screen.desktopAvailableHeight * 0.7)
        if (!gridMode && sourceWidth > 0 && sourceHeight > 0) {
            let s = Math.min(Screen.desktopAvailableWidth * 0.75 / sourceWidth, Screen.desktopAvailableHeight * 0.8 / sourceHeight, 1)
            w = Math.max(480, Math.round(sourceWidth * s))
            h = Math.max(360, Math.round(sourceHeight * s))
        }
        minimumWidth = w; maximumWidth = w; width = w
        minimumHeight = h; maximumHeight = h; height = h
        visible = true
        shown = true
        unlockTimer.start()
    }
    function notify(text) { toast = text; toastTimer.restart() }
    function copyImage() { if (current) post("copy/" + current.id, function(r) { notify(r && r.ok ? "Image copied" : "Could not copy image") }) }
    function copyPath() { if (current) post("copy-path/" + current.id, function(r) { notify(r && r.ok ? "Path copied" : "Could not copy path") }) }
    function openFolder() { if (current) post("folder/" + current.id, null) }
    function removeAt(i) {
        let list = files.slice()
        list.splice(i, 1)
        let next = index > i ? index - 1 : index
        files = list
        index = Math.max(0, Math.min(next, files.length - 1))
        refilter(search.text)
        if (gridMode) grid.currentIndex = Math.min(grid.currentIndex, filtered.length - 1)
        resetView()
        if (files.length === 0) { if (dirs.length > 0) showGrid(); else gridMode = false }
    }
    function trash(i) {
        if (i < 0 || i >= files.length) return
        let file = files[i]
        post("trash/" + file.id, function(r) {
            if (!r || !r.ok) { notify("Could not move to trash"); return }
            let position = -1
            for (let k = 0; k < files.length; k++) if (files[k].id === file.id) position = k
            if (position >= 0) removeAt(position)
            notify("Moved to trash")
        })
    }
    function sizeText(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB"
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB"
        return bytes + " B"
    }

    onCurrentChanged: if (current && !gridMode) post("seen/" + current.id, null)
    onGridModeChanged: if (!gridMode && current) post("seen/" + current.id, null)
    onWidthChanged: clampPan()
    onHeightChanged: clampPan()
    onSourceWidthChanged: if (sourceWidth > 0 && !gridMode) present()
    onFailedChanged: if (failed) present()
    Component.onCompleted: load()

    Timer {
        id: unlockTimer
        interval: 400
        onTriggered: {
            root.maximumWidth = 16777215
            root.maximumHeight = 16777215
            root.minimumWidth = 360
            root.minimumHeight = 260
        }
    }
    Timer { interval: 1500; running: true; onTriggered: root.present() }
    Timer { id: toastTimer; interval: 1600; onTriggered: root.toast = "" }

    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        focus: true
        visible: opacity > 0
        opacity: root.gridMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Image {
            id: backdropSource
            anchors.fill: parent
            visible: false
            source: root.current ? root.thumbUrl(root.index) : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 96
            sourceSize.height: 96
        }
        MultiEffect {
            anchors.fill: parent
            source: backdropSource
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.15
            brightness: -0.25
            opacity: backdropSource.status === Image.Ready ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }

        Image {
            id: stillPicture
            visible: !root.animated
            source: root.animated ? "" : root.imageUrl(root.index)
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            autoTransform: true
            width: implicitWidth * root.scaleNow
            height: implicitHeight * root.scaleNow
            x: (viewport.width - width) / 2 + root.panX
            y: (viewport.height - height) / 2 + root.panY
            rotation: root.angle
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        AnimatedImage {
            id: animatedPicture
            visible: root.animated
            source: root.animated ? root.imageUrl(root.index) : ""
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            width: implicitWidth * root.scaleNow
            height: implicitHeight * root.scaleNow
            x: (viewport.width - width) / 2 + root.panX
            y: (viewport.height - height) / 2 + root.panY
            rotation: root.angle
        }
        Image { visible: false; asynchronous: true; cache: true; source: root.files.length > 1 && !root.gridMode && !root.files[(root.index + 1) % root.files.length].animated ? root.imageUrl(root.index + 1) : "" }
        Image { visible: false; asynchronous: true; cache: true; source: root.files.length > 2 && !root.gridMode && !root.files[(root.index - 1 + root.files.length) % root.files.length].animated ? root.imageUrl(root.index - 1) : "" }

        MouseArea {
            anchors.fill: parent
            enabled: !root.gridMode
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: pressed ? Qt.ClosedHandCursor : (root.boxWidth * root.scaleNow > viewport.width || root.boxHeight * root.scaleNow > viewport.height) ? Qt.OpenHandCursor : Qt.ArrowCursor
            property real lastX: 0
            property real lastY: 0
            onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
            onPositionChanged: function(mouse) {
                root.panX += mouse.x - lastX
                root.panY += mouse.y - lastY
                lastX = mouse.x
                lastY = mouse.y
                root.clampPan()
            }
            onDoubleClicked: root.toggleFullScreen()
            onClicked: function(mouse) { if (mouse.button === Qt.MiddleButton) root.resetView() }
            onWheel: function(wheel) {
                let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 4
                if (wheel.modifiers & Qt.ControlModifier || root.zoom !== 1) root.zoomTo(root.zoom * Math.pow(1.0018, delta), wheel.x, wheel.y)
                else root.swipe(wheel.phase, delta)
            }
        }

        BusyIndicator { anchors.centerIn: parent; running: root.loading; visible: running }
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: root.failed || root.files.length === 0
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.files.length === 0 ? "No images here" : "Could not open this image"; color: root.ink; font.pixelSize: 18; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.current ? root.current.name : ""; color: root.secondaryInk; font.pixelSize: 13 }
        }
    }

    component Pill: Rectangle {
        radius: height / 2
        color: "#e61c1c1e"
        border.color: root.separator
        visible: root.overlay
    }
    component RoundButton: Rectangle {
        id: button
        signal clicked()
        property string glyph: ""
        width: 44; height: 44; radius: 22
        color: area.pressed ? "#3a3a3c" : area.containsMouse ? "#2c2c2e" : "#e61c1c1e"
        border.color: root.separator
        visible: root.overlay && root.files.length > 1
        Text { anchors.centerIn: parent; text: button.glyph; color: root.ink; font.pixelSize: 22 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: button.clicked() }
    }

    Pill {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        width: Math.min(parent.width - 32, infoRow.implicitWidth + 32)
        height: 40
        RowLayout {
            id: infoRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 32)
            spacing: 12
            Text { Layout.fillWidth: true; Layout.maximumWidth: 520; text: root.current ? root.current.name : ""; color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideMiddle }
            Text { text: root.files.length > 0 ? (root.index + 1) + " / " + root.files.length : ""; color: root.secondaryInk; font.pixelSize: 13 }
            Text { visible: root.sourceWidth > 0; text: root.sourceWidth + " × " + root.sourceHeight; color: root.secondaryInk; font.pixelSize: 13 }
            Text { visible: root.current !== null; text: root.current ? root.sizeText(root.current.size) : ""; color: root.secondaryInk; font.pixelSize: 13 }
            Text { text: Math.round(root.scaleNow * 100) + "%"; color: root.accent; font.pixelSize: 13 }
        }
    }
    RoundButton { glyph: "‹"; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; onClicked: root.go(-1) }
    RoundButton { glyph: "›"; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; onClicked: root.go(1) }
    Pill {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 16
        width: hintText.implicitWidth + 32
        height: 32
        visible: root.overlay && root.width > 620
        Text { id: hintText; anchors.centerIn: parent; text: "← → navigate · G grid · scroll zoom · R rotate · F fullscreen · H help"; color: root.secondaryInk; font.pixelSize: 12 }
    }

    Rectangle {
        id: gridLayer
        anchors.fill: parent
        color: root.canvas
        visible: opacity > 0
        opacity: root.gridMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.bottomMargin: 6
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 16
                Rectangle {
                    visible: root.parentPath.length > 0
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: upArea.pressed ? "#3a3a3c" : upArea.containsMouse ? "#2c2c2e" : root.surface
                    border.color: root.separator
                    Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "‹"; color: root.ink; font.pixelSize: 20 }
                    MouseArea { id: upArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.openDir(root.parentPath) }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { Layout.fillWidth: true; text: root.folderName; color: root.ink; font.pixelSize: 20; font.weight: Font.DemiBold; elide: Text.ElideMiddle }
                    Text { text: (search.text.length > 0 ? root.filtered.length + " found · " : "") + (root.dirs.length > 0 ? root.dirs.length + (root.dirs.length === 1 ? " folder · " : " folders · ") : "") + root.files.length + (root.files.length === 1 ? " image" : " images"); color: root.secondaryInk; font.pixelSize: 12 }
                }
                TextField {
                    id: search
                    Layout.preferredWidth: Math.min(300, gridLayer.width * 0.42)
                    Layout.preferredHeight: 36
                    placeholderText: "Search"
                    placeholderTextColor: root.secondaryInk
                    color: root.ink
                    font.pixelSize: 13
                    leftPadding: 14
                    rightPadding: 14
                    selectByMouse: true
                    background: Rectangle {
                        radius: 10
                        color: root.surface
                        border.width: 1
                        border.color: search.activeFocus ? root.accent : root.separator
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                    onTextChanged: { root.refilter(text); grid.currentIndex = 0; grid.positionViewAtBeginning() }
                    Keys.onDownPressed: grid.forceActiveFocus()
                    Keys.onDeletePressed: function(event) {
                        if (text.length === 0 || cursorPosition === text.length) { root.trashTarget(); event.accepted = true }
                        else event.accepted = false
                    }
                    Keys.onReturnPressed: if (root.filtered.length > 0) root.openEntry(root.filtered[Math.max(0, grid.currentIndex)])
                    Keys.onEnterPressed: if (root.filtered.length > 0) root.openEntry(root.filtered[Math.max(0, grid.currentIndex)])
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                reuseItems: true
                cacheBuffer: cellHeight * 4
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                readonly property int columns: Math.max(2, Math.floor(width / 190))
                cellWidth: Math.floor(width / columns)
                cellHeight: cellWidth
                model: root.filtered.length
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Keys.onReturnPressed: root.openEntry(root.filtered[currentIndex])
                Keys.onEnterPressed: root.openEntry(root.filtered[currentIndex])
                Keys.onSpacePressed: root.openEntry(root.filtered[currentIndex])
                Keys.onUpPressed: function(event) {
                    if (currentIndex < columns) search.forceActiveFocus()
                    else moveCurrentIndexUp()
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Backspace) {
                        root.openDir(root.parentPath)
                        event.accepted = true
                        return
                    }
                    if (event.text.length === 1 && event.text.trim().length === 1 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                        search.forceActiveFocus()
                        search.text += event.text
                        event.accepted = true
                    }
                }
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int value: index < root.filtered.length ? root.filtered[index] : 0
                    readonly property int fileIndex: value >= 0 && index < root.filtered.length ? value : -1
                    readonly property var file: fileIndex >= 0 ? root.files[fileIndex] : null
                    readonly property var dir: value < 0 ? root.dirs[-value - 1] : null
                    readonly property bool selected: GridView.isCurrentItem
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Item {
                        anchors.fill: parent
                        anchors.margins: 6
                        scale: cellArea.pressed ? 0.97 : cellArea.containsMouse ? 1.015 : 1
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        Rectangle { anchors.fill: parent; radius: 12; color: root.surface }
                        Image {
                            anchors.fill: parent
                            source: cell.dir ? (cell.dir.cover >= 0 ? root.api + "thumb/" + cell.dir.cover : "") : root.thumbUrl(cell.fileIndex)
                            asynchronous: true
                            cache: true
                            smooth: true
                            autoTransform: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 384
                            sourceSize.height: 384
                            opacity: status === Image.Ready ? (cell.dir ? 0.22 : 1) : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 40
                            visible: !cell.dir && (cellArea.containsMouse || (cell.selected && grid.activeFocus) || search.text.length > 0)
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#00000000" }
                                GradientStop { position: 1; color: "#d9000000" }
                            }
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 8
                                verticalAlignment: Text.AlignBottom
                                text: cell.file ? cell.file.name : ""
                                color: root.ink
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }
                        Column {
                            visible: cell.dir !== null
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 6
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 30; height: 23
                                Rectangle { x: 0; y: 0; width: 13; height: 8; radius: 2; color: root.accent }
                                Rectangle { x: 0; y: 4; width: 30; height: 19; radius: 4; color: root.accent }
                            }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cell.dir ? cell.dir.name : ""; color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideMiddle }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cell.dir ? (cell.dir.count > 0 ? cell.dir.count + (cell.dir.count === 1 ? " image" : " images") : cell.dir.folders + (cell.dir.folders === 1 ? " folder" : " folders")) : ""; color: root.secondaryInk; font.pixelSize: 11 }
                        }
                        Rectangle { anchors.fill: parent; anchors.margins: -7; radius: 19; color: "transparent"; border.width: 7; border.color: root.canvas }
                        Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 15; color: "transparent"; border.width: 2; border.color: root.accent; visible: cell.selected }
                        Rectangle {
                            visible: root.viewed && cell.fileIndex === root.index
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 8; height: 8; radius: 4
                            color: root.accent
                        }
                    }
                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { grid.currentIndex = cell.index; root.openEntry(cell.value) }
                        onContainsMouseChanged: root.hoveredCell = containsMouse ? cell.index : (root.hoveredCell === cell.index ? -1 : root.hoveredCell)
                    }
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: root.filtered.length === 0
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: search.text.length === 0 ? "Nothing here" : "No matches"; color: root.ink; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; visible: search.text.length > 0; text: "Esc clears the search"; color: root.secondaryInk; font.pixelSize: 12 }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: toastText.implicitWidth + 32
        height: 36
        radius: 18
        color: "#f22c2c2e"
        border.color: root.separator
        opacity: root.toast.length > 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Text { id: toastText; anchors.centerIn: parent; text: root.toast; color: root.ink; font.pixelSize: 13 }
    }

    Popup {
        id: help
        anchors.centerIn: Overlay.overlay
        width: Math.min(root.width - 48, 480)
        height: Math.min(root.height - 48, helpColumn.implicitHeight + 48)
        padding: 24
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: "#66000000" }
        background: Rectangle { radius: 24; color: "#2c2c2e"; border.color: root.separator }
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 160; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
        contentItem: Flickable {
            contentHeight: helpColumn.implicitHeight
            clip: true
            ColumnLayout {
                id: helpColumn
                width: parent.width
                spacing: 9
                Text { text: "Keyboard shortcuts"; color: root.ink; font.pixelSize: 22; font.weight: Font.DemiBold; Layout.bottomMargin: 6 }
                Repeater {
                    model: [
                        ["G  Esc", "Thumbnail grid"],
                        ["H  F1", "This help"],
                        ["Type  /", "Search in the grid"],
                        ["Enter  Click", "Open image or folder"],
                        ["Backspace  ‹", "Parent folder (grid)"],
                        ["→  D  Space  PgDn", "Next image"],
                        ["←  A  Backspace  PgUp", "Previous image"],
                        ["Home  End", "First / last image"],
                        ["Scroll", "Next / previous (zoom when zoomed)"],
                        ["Ctrl + Scroll", "Zoom at cursor"],
                        ["+  -", "Zoom in / out"],
                        ["0  Z  Middle click", "Fit to window"],
                        ["1", "Actual size"],
                        ["W  S  ↑  ↓", "Pan up / down"],
                        ["R  Shift+R", "Rotate right / left"],
                        ["F  F11  Double click", "Fullscreen"],
                        ["Tab", "Show info"],
                        ["C", "Copy image"],
                        ["Y", "Copy path"],
                        ["O", "Open folder"],
                        ["Del", "Move to trash"],
                        ["Q  Ctrl+Q", "Close"]
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text { text: modelData[0]; color: root.accent; font.pixelSize: 13; Layout.preferredWidth: 190 }
                        Text { text: modelData[1]; color: root.ink; font.pixelSize: 13; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    readonly property bool viewKeys: !help.visible && !gridMode
    Shortcut { sequences: ["Right", "D", "Space", "PgDown"]; enabled: root.viewKeys; onActivated: root.go(1) }
    Shortcut { sequences: ["Left", "A", "Backspace", "PgUp"]; enabled: root.viewKeys; onActivated: root.go(-1) }
    Shortcut { sequence: "Home"; enabled: root.viewKeys; onActivated: root.goTo(0) }
    Shortcut { sequence: "End"; enabled: root.viewKeys; onActivated: root.goTo(root.files.length - 1) }
    Shortcut { sequences: ["+", "=", "Ctrl++", "Ctrl+="]; enabled: root.viewKeys; onActivated: root.zoomTo(root.zoom * 1.25) }
    Shortcut { sequences: ["-", "Ctrl+-"]; enabled: root.viewKeys; onActivated: root.zoomTo(root.zoom / 1.25) }
    Shortcut { sequences: ["0", "Z", "Ctrl+0"]; enabled: root.viewKeys; onActivated: root.resetView() }
    Shortcut { sequence: "1"; enabled: root.viewKeys; onActivated: root.actualSize() }
    Shortcut { sequences: ["Up", "W"]; enabled: root.viewKeys; onActivated: { root.panY += viewport.height * 0.15; root.clampPan() } }
    Shortcut { sequences: ["Down", "S"]; enabled: root.viewKeys; onActivated: { root.panY -= viewport.height * 0.15; root.clampPan() } }
    Shortcut { sequence: "R"; enabled: root.viewKeys; onActivated: root.rotate(90) }
    Shortcut { sequence: "Shift+R"; enabled: root.viewKeys; onActivated: root.rotate(-90) }
    Shortcut { sequences: ["F", "F11"]; enabled: root.viewKeys; onActivated: root.toggleFullScreen() }
    Shortcut { sequence: "F11"; enabled: root.gridMode; onActivated: root.toggleFullScreen() }
    Shortcut { sequence: "Tab"; enabled: root.viewKeys; onActivated: root.pinnedOverlay = !root.pinnedOverlay }
    Shortcut { sequence: "C"; enabled: root.viewKeys; onActivated: root.copyImage() }
    Shortcut { sequences: ["Y", "Ctrl+C"]; enabled: root.viewKeys; onActivated: root.copyPath() }
    Shortcut { sequence: "O"; enabled: root.viewKeys; onActivated: root.openFolder() }
    function trashTarget() {
        if (!gridMode) { trash(index); return }
        let value = hoveredCell >= 0 && hoveredCell < filtered.length ? filtered[hoveredCell] : filtered[grid.currentIndex]
        if (value !== undefined && value >= 0) trash(value)
    }
    Shortcut { sequence: "Delete"; enabled: !help.visible && !search.activeFocus; onActivated: root.trashTarget() }
    Shortcut { sequence: "G"; enabled: root.viewKeys && root.files.length > 1; onActivated: root.showGrid() }
    Shortcut { sequence: "/"; enabled: !help.visible && root.files.length > 1; onActivated: { if (!root.gridMode) root.showGrid(); search.forceActiveFocus(); search.selectAll() } }
    Shortcut { sequence: "H"; enabled: !root.gridMode; onActivated: help.visible ? help.close() : help.open() }
    Shortcut { sequence: "F1"; onActivated: help.visible ? help.close() : help.open() }
    Shortcut { sequence: "Q"; enabled: root.viewKeys; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: root.close() }
    Shortcut { sequence: "Escape"; onActivated: root.back() }
}
'''


def image_main(arguments):
    if arguments == ['--install']:
        image_install()
        return
    threading.Thread(target=image_install, daemon=True).start()
    image_close_previous()
    files, start, grid, folder = image_collect(arguments)
    IMAGE_CACHE.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=image_prune_cache, daemon=True).start()
    token = secrets.token_urlsafe(24)
    registry = []
    known = {}
    lock = threading.Lock()
    warming = {'stop': threading.Event()}

    def register(path):
        with lock:
            key = str(path)
            if key not in known:
                known[key] = len(registry)
                registry.append(path)
            return known[key]

    def describe(path):
        try:
            size = path.stat().st_size
        except OSError:
            size = 0
        return {'id': register(path), 'name': path.name, 'key': image_search_key(path.name), 'size': size, 'animated': path.suffix.lower() == '.gif'}

    def warm(paths):
        warming['stop'].set()
        warming['stop'] = threading.Event()
        if len(paths) > 1:
            threading.Thread(target=image_warm, args=(paths, warming['stop']), daemon=True).start()

    def build(where, paths, position, as_grid):
        folders = []
        if where is not None:
            for entry in image_subfolders(where):
                summary = image_folder_summary(entry)
                if summary is None:
                    continue
                folders.append({'name': entry.name, 'key': image_search_key(entry.name), 'path': str(entry), 'cover': register(summary['cover']), 'count': summary['count'], 'folders': summary['folders']})
        return json.dumps({
            'files': [describe(path) for path in paths],
            'dirs': folders,
            'index': position,
            'grid': as_grid,
            'folder': (where.name or str(where)) if where is not None else 'Images',
            'path': str(where) if where is not None else '',
            'parent': str(where.parent) if where is not None and where.parent != where else '',
        }).encode()

    listing = build(folder, files, start, grid)

    def resolve(raw):
        number = int(raw)
        with lock:
            if not 0 <= number < len(registry):
                raise ValueError('index out of range')
            return registry[number]

    class Handler(BaseHTTPRequestHandler):
        def reply(self, body, content_type):
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def send_file(self, path, content_type):
            with open(path, 'rb') as data:
                size = os.fstat(data.fileno()).st_size
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(size))
                self.send_header('Cache-Control', 'private, max-age=86400')
                self.end_headers()
                shutil.copyfileobj(data, self.wfile, 1 << 20)

        def do_GET(self):
            if self.path == f'/{token}/list':
                self.reply(listing, 'application/json')
                return
            if self.path.startswith(f'/{token}/list?dir='):
                where = Path(unquote(self.path.split('?dir=', 1)[1]))
                if not where.is_dir():
                    self.send_error(404)
                    return
                paths = image_list_folder(where)
                warm(paths)
                self.reply(build(where, paths, 0, True), 'application/json')
                return
            match = re.fullmatch(rf'/{re.escape(token)}/(image|thumb)/([0-9]+)', self.path)
            if not match:
                self.send_error(404)
                return
            try:
                path = resolve(match[2])
                if match[1] == 'thumb':
                    source, content_type = image_thumbnail(path)
                elif path.suffix.lower() in IMAGE_NATIVE:
                    source, content_type = path, IMAGE_NATIVE[path.suffix.lower()]
                else:
                    source, content_type = image_full(path), 'image/png'
            except (OSError, ValueError, subprocess.SubprocessError):
                self.send_error(415)
                return
            self.send_file(source, content_type)

        def do_POST(self):
            match = re.fullmatch(rf'/{re.escape(token)}/(copy|copy-path|folder|seen|trash)/([0-9]+)', self.path)
            if not match:
                self.send_error(404)
                return
            ok = True
            try:
                path = resolve(match[2])
                if match[1] == 'copy':
                    source = path if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.gif', '.bmp'} else image_full(path)
                    with open(source, 'rb') as data:
                        subprocess.run(['wl-copy'], stdin=data, check=True, timeout=10)
                elif match[1] == 'copy-path':
                    subprocess.run(['wl-copy', str(path)], check=True, timeout=10)
                elif match[1] == 'folder':
                    subprocess.Popen(['xdg-open', str(path.parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                elif match[1] == 'trash':
                    subprocess.run(['gio', 'trash', '--', str(path)], check=True, timeout=20, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    image_add_history(path)
            except (OSError, ValueError, subprocess.SubprocessError):
                ok = False
            self.reply(json.dumps({'ok': ok}).encode(), 'application/json')

        def log_message(self, *args):
            pass

    class Server(ThreadingHTTPServer):
        daemon_threads = True
        request_queue_size = 64

        def handle_error(self, request, client_address):
            pass

    server = Server(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    warm(files)
    try:
        with tempfile.TemporaryDirectory(prefix='imgview-') as directory:
            qml = Path(directory) / 'imgview.qml'
            qml.write_text(IMAGE_QML.replace('API_URL', json.dumps(f'http://127.0.0.1:{server.server_port}/{token}/')))
            viewer = subprocess.Popen(['/usr/bin/qml6', str(qml)])
            signal.signal(signal.SIGTERM, lambda *args: viewer.terminate())
            image_claim(viewer.pid)
            viewer.wait()
    finally:
        warming['stop'].set()
        image_release()
        server.shutdown()
        server.server_close()

# ─────────── main ───────────
def main():
    prog = sys.argv[0]
    action = sys.argv[1].lower() if len(sys.argv) > 1 else ""

    if os.path.basename(prog) == "imgview":
        image_main(sys.argv[1:])
        return
    if action in {"image", "images", "img", "-i", "--image"}:
        image_main(sys.argv[2:])
        return

    if "video" in prog or action in {"video", "videos", "-v", "--video"}:
        run_video_menu()
        return

    if action in {"stop", "kill", "-k", "--stop"}:
        stop_music()
    elif action in {"music", "menu", "picker", "-m", "--menu"}:
        if is_external_playing():
            stop_engine()
            return
        run_menu()
    elif action in {"random", "force-random"}:
        play_random()
    else:
        next_or_random()

if __name__ == "__main__":
    main()
