#!/usr/bin/env -S python3 -B
import sys
sys.dont_write_bytecode = True
import os
import random
import subprocess
import socket
import json

MUSIC_DIR = os.path.expanduser("~/0/music")
PLAYED_FILE = "/tmp/music_played.txt"
PLAYLIST_FILE = "/tmp/mpv_playlist.m3u"
SOCKET_PATH = "/tmp/mpv_music_socket"
EXTENSIONS = {".mp3", ".flac", ".ogg", ".wav", ".opus", ".m4a", ".aac"}

MPV_FLAGS = [
    "/usr/bin/mpv",
    "--no-video",
    "--audio-display=no",
    "--no-resume-playback",
    "--gapless-audio=yes",
    f"--input-ipc-server={SOCKET_PATH}",
]

ROFI_THEME = [
    "-no-lazy-filter",
    "-theme-str", '* { font: "JetBrainsMono Nerd Font Medium 10.5"; bg: rgba(12,4,8,0.75); bg-alt: rgba(255,255,255,0.05); bg-hover: rgba(200,90,120,0.25); fg: #ffe0ec; muted: #b898a8; accent: #f8b4c8; glow: rgba(248,180,200,0.5); }',
    "-theme-str", 'window { width: 54%; background-color: @bg; transparency: "real"; border: 2px; border-color: @glow; border-radius: 18px; }',
    "-theme-str", 'mainbox { background-color: transparent; padding: 8px; spacing: 4px; }',
    "-theme-str", 'inputbar { background-color: rgba(255,255,255,0.07); padding: 6px 10px; border: 1px; border-color: rgba(248,180,200,0.2); border-radius: 10px; children: [ entry ]; }',
    "-theme-str", 'entry { background-color: transparent; text-color: @fg; placeholder-color: @muted; cursor-color: @accent; cursor-width: 2px; }',
    "-theme-str", 'listview { background-color: transparent; columns: 1; lines: 12; fixed-height: false; dynamic: true; spacing: 2px; scrollbar: true; scrollbar-width: 4px; }',
    "-theme-str", 'scrollbar { background-color: transparent; handle-color: @accent; handle-width: 4px; border-radius: 2px; }',
    "-theme-str", 'element { background-color: @bg-alt; text-color: @fg; padding: 4px 8px; height: 28px; border: 1px; border-color: rgba(255,255,255,0.03); border-radius: 8px; }',
    "-theme-str", 'element normal.normal { background-color: @bg-alt; text-color: @fg; }',
    "-theme-str", 'element alternate.normal { background-color: @bg-alt; text-color: @fg; }',
    "-theme-str", 'element selected.normal { background-color: @bg-hover; text-color: @accent; border: 2px; border-color: @accent; }',
    "-theme-str", 'element-text { background-color: transparent; text-color: @fg; vertical-align: 0.5; highlight: bold #ffffff; }',
    "-theme-str", 'element normal.normal element-text { background-color: transparent; text-color: @fg; }',
    "-theme-str", 'element alternate.normal element-text { background-color: transparent; text-color: @fg; }',
    "-theme-str", 'element selected.normal element-text { background-color: transparent; text-color: @accent; }',
]

def notify(color: str, text: str):
    subprocess.Popen(
        ["hyprctl", "notify", "-1", "1500", color, f"fontsize:16 {text}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def is_mpv_running() -> bool:
    try:
        res = subprocess.run(["pgrep", "-x", "mpv"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return res.returncode == 0
    except Exception:
        return False

def kill_mpv():
    subprocess.run(["killall", "-9", "mpv", "ffplay"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def stop_music():
    kill_mpv()
    notify("rgb(f38ba8)", "󰎊  Music stopped")

def scan_music():
    if not os.path.isdir(MUSIC_DIR):
        return []
    files = []
    for root, _, filenames in os.walk(MUSIC_DIR):
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            if ext in EXTENSIONS:
                files.append(os.path.join(root, f))
    return files

def play_queue(queue: list[str]):
    if not queue:
        return
    kill_mpv()
    try:
        with open(PLAYLIST_FILE, "w", encoding="utf-8") as fp:
            fp.write("\n".join(queue) + "\n")
    except Exception:
        pass

    subprocess.Popen(
        MPV_FLAGS + ["--loop-playlist=inf", f"--playlist={PLAYLIST_FILE}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    title = os.path.splitext(os.path.basename(queue[0]))[0]
    notify("rgb(cba6f7)", f"󰎇  {title}")

def play_random():
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

def play_files_shuffled(file_list: list[str]):
    if not file_list:
        return
    queue = list(file_list)
    random.shuffle(queue)
    all_files = scan_music()
    others = [f for f in all_files if f not in queue]
    random.shuffle(others)
    play_queue(queue + others)

def rofi_dmenu(prompt: str, options: list[str]) -> str:
    cmd = ["rofi", "-dmenu", "-i", "-no-custom", "-p", prompt] + ROFI_THEME
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        stdout, _ = proc.communicate(input="\n".join(options))
        return stdout.strip()
    except Exception:
        return ""

def show_tracklist(file_list: list[str], prompt: str, prefix_artist=True):
    if not file_list:
        return
    display_map = {}
    items = []
    for f in sorted(file_list, key=lambda x: os.path.basename(x).lower()):
        rel = os.path.relpath(f, MUSIC_DIR)
        parts = rel.split(os.sep)
        if not prefix_artist:
            if len(parts) >= 3:
                alb = parts[-2]
                name = os.path.splitext(parts[-1])[0]
                disp = f"{alb} / {name}"
            else:
                disp = os.path.splitext(parts[-1])[0]
        else:
            if len(parts) == 1:
                disp = os.path.splitext(parts[0])[0]
            elif len(parts) == 2:
                artist = parts[0]
                name = os.path.splitext(parts[1])[0]
                disp = f"{artist} - {name}"
            else:
                artist = parts[0]
                alb = parts[1]
                name = os.path.splitext(parts[2])[0]
                disp = f"{artist} - {alb} / {name}"

        items.append(disp)
        display_map[disp] = f

    chosen = rofi_dmenu(prompt, items)
    if not chosen:
        return

    f = display_map.get(chosen)
    if f and os.path.isfile(f):
        sel_idx = file_list.index(f) if f in file_list else 0
        subsequent = file_list[sel_idx:] + file_list[:sel_idx]
        others = [x for x in scan_music() if x not in file_list]
        random.shuffle(others)
        play_queue(subsequent + others)

def run_menu():
    subprocess.Popen(["pkill", "-x", "rofi"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    all_files = scan_music()
    if not all_files:
        return

    if not is_mpv_running():
        play_random()

    tree = {}
    for f in all_files:
        rel = os.path.relpath(f, MUSIC_DIR)
        parts = rel.split(os.sep)
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
        status = subprocess.check_output(["playerctl", "status"], text=True, stderr=subprocess.DEVNULL).strip()
        if status in {"Playing", "Paused"}:
            artist = subprocess.check_output(["playerctl", "metadata", "artist"], text=True, stderr=subprocess.DEVNULL).strip()
            title = subprocess.check_output(["playerctl", "metadata", "title"], text=True, stderr=subprocess.DEVNULL).strip()
            if title:
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
        play_files_shuffled(all_files)
        return

    if chosen == tracklist_option:
        show_tracklist(all_files, "  Track:", prefix_artist=True)
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
            play_files_shuffled(top_all_files)
        elif sub_chosen.startswith("󰎸  Tracklist"):
            show_tracklist(top_all_files, "  Track:", prefix_artist=False)
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
        play_files_shuffled(top_all_files)
        return

    if album_chosen.startswith("󰎸  Tracklist"):
        show_tracklist(top_all_files, "  Track:", prefix_artist=False)
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
        show_tracklist(sub_files, "  Track:", prefix_artist=False)

def is_external_playing() -> bool:
    try:
        res = subprocess.run(
            ["playerctl", "-i", "mpv", "-a", "status"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return "Playing" in res.stdout
    except Exception:
        return False

def next_or_random():
    if is_external_playing():
        if is_mpv_running():
            kill_mpv()
        subprocess.run(["playerctl", "-i", "mpv", "next"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        import time
        time.sleep(0.15)
        try:
            res = subprocess.run(
                ["playerctl", "-i", "mpv", "metadata", "--format", "{{title}}"],
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
        import time
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

def main():
    action = sys.argv[1].lower() if len(sys.argv) > 1 else "play"
    if action in {"stop", "kill", "-k", "--stop"}:
        stop_music()
    elif action in {"menu", "picker", "-m", "--menu"}:
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

