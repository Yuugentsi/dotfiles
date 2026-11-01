#!/usr/bin/env -S python3 -B
import sys
sys.dont_write_bytecode = True
import os
import subprocess

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
PLAYLIST_FILE = "/tmp/mpv_playlist.m3u"
SOCKET_PATH = "/tmp/mpv_music_socket"
MUSIC_EXTENSIONS = {".mp3", ".flac", ".ogg", ".wav", ".opus", ".m4a", ".aac"}

MPV_FLAGS = [
    "/usr/bin/mpv",
    "--no-video",
    "--audio-display=no",
    "--no-resume-playback",
    "--gapless-audio=yes",
    f"--input-ipc-server={SOCKET_PATH}",
]

def is_mpv_running() -> bool:
    try:
        for pid in os.listdir("/proc"):
            if pid.isdigit():
                try:
                    with open(f"/proc/{pid}/comm", "rb") as f:
                        if f.read().strip() in (b"mpv", b"ffplay"):
                            return True
                except OSError:
                    continue
    except OSError:
        pass
    return False

def kill_mpv():
    try:
        for pid in os.listdir("/proc"):
            if pid.isdigit():
                try:
                    with open(f"/proc/{pid}/comm", "rb") as f:
                        if f.read().strip() in (b"mpv", b"ffplay"):
                            os.kill(int(pid), 9)
                except OSError:
                    continue
    except OSError:
        pass

def stop_music():
    kill_mpv()
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

def play_queue(queue: list[str], loop: bool = True, title: str | None = None):
    if not queue:
        return
    kill_mpv()
    try:
        with open(PLAYLIST_FILE, "w", encoding="utf-8") as fp:
            fp.write("\n".join(queue) + "\n")
    except Exception:
        pass

    loop_flag = "--loop-playlist=inf" if loop else "--loop-playlist=no"
    subprocess.Popen(
        MPV_FLAGS + [loop_flag, f"--playlist={PLAYLIST_FILE}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
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

    if not is_mpv_running():
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
            ["playerctl", "-i", "mpv,playerctld", "-a", "status"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return "Playing" in res.stdout
    except Exception:
        return False

def next_or_random():
    import time
    if is_external_playing():
        if is_mpv_running():
            kill_mpv()
        subprocess.run(["playerctl", "-i", "mpv,playerctld", "next"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.15)
        try:
            res = subprocess.run(
                ["playerctl", "-i", "mpv,playerctld", "metadata", "--format", "{{title}}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            title = res.stdout.strip()
            if title:
                notify("rgb(cba6f7)", f"󰎇  {title}")
        except Exception:
            pass
    elif is_mpv_running():
        subprocess.run(["playerctl", "--player=mpv", "next"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.15)
        try:
            res = subprocess.run(
                ["playerctl", "--player=mpv", "metadata", "--format", "{{title}}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            title = res.stdout.strip()
            if title:
                notify("rgb(cba6f7)", f"󰎇  {title}")
        except Exception:
            pass
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

# ─────────── main ───────────
def main():
    prog = sys.argv[0]
    action = sys.argv[1].lower() if len(sys.argv) > 1 else ""

    if "video" in prog or action in {"video", "videos", "-v", "--video"}:
        run_video_menu()
        return

    if action in {"stop", "kill", "-k", "--stop"}:
        stop_music()
    elif action in {"music", "menu", "picker", "-m", "--menu"}:
        if is_external_playing():
            if is_mpv_running():
                kill_mpv()
            return
        run_menu()
    elif action in {"random", "force-random"}:
        play_random()
    else:
        next_or_random()

if __name__ == "__main__":
    main()
