#!/usr/bin/env bash

case "${1:-}" in
    # ----- mpv (ALT + W) -----
    mpv)
        SPECIAL="mpv"
        CLASS="mpv"
        
        DATA=$(hyprctl clients -j 2>/dev/null | jq -r --arg s "special:$SPECIAL" --arg c "$CLASS" '
            (map(select(.workspace.name == $s)) | first | .address // empty),
            (map(select(.class == $c)) | first | .address // empty)
        ')
        EXISTING_SPECIAL=$(echo "$DATA" | sed -n '1p')
        ADDR=$(echo "$DATA" | sed -n '2p')

        if [ -n "$EXISTING_SPECIAL" ]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            exit 0
        fi

        if [ -n "$ADDR" ]; then
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })" >/dev/null 2>&1
            hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            exit 0
        fi

        mpv --force-window --idle --fs >/dev/null 2>&1 &
        hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
        ;;

    # ----- kitty (ALT + Q) -----
    kitty)
        SPECIAL="kitty"
        DATA=$(hyprctl clients -j 2>/dev/null | jq -r --arg s "special:$SPECIAL" '
            map(select(.class == "kitty-float")) | first | "\(.address // "") \(.workspace.name // "")"
        ')
        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [ -n "$ADDR" ]; then
            if [ "$WS" = "special:$SPECIAL" ]; then
                hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            else
                hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })" >/dev/null 2>&1
                hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            fi
            exit 0
        fi

        kitty --class kitty-float >/dev/null 2>&1 &
        hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
        ;;

    # ----- thunar (SUPER + T) -----
    thunar)
        SPECIAL="thunar"
        DATA=$(hyprctl clients -j 2>/dev/null | jq -r --arg s "special:$SPECIAL" '
            map(select(.class == "thunar" or .class == "Thunar")) | first | "\(.address // "") \(.workspace.name // "")"
        ')
        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [ -n "$ADDR" ]; then
            if [ "$WS" = "special:$SPECIAL" ]; then
                hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            else
                hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })" >/dev/null 2>&1
                hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
            fi
            exit 0
        fi

        thunar >/dev/null 2>&1 &
        hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
        ;;

    # ----- telegram (ALT + T) -----
    toggle)
        SPECIAL="telegram"
        CLASS="org.telegram.desktop"
        EXEC="Telegram"

        DATA=$(hyprctl clients -j 2>/dev/null | jq -r --arg c "$CLASS" '
            map(select(.class == $c)) | first | "\(.address // "") \(.workspace.name // "")"
        ')
        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [ -z "$ADDR" ]; then
            "$EXEC" >/dev/null 2>&1 &
            exit 0
        fi

        if [[ "$WS" == special* ]]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
        else
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })" >/dev/null 2>&1
            hyprctl dispatch "hl.dsp.workspace.toggle_special('$SPECIAL')" >/dev/null 2>&1
        fi
        ;;

    # ----- workspace notify (Daemon) -----
    workspace)
        ICONS=("" ➊ ➋ ➌ ➍ ➎ ➏ ➐ ➑ ➒ ➓)
        socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | while read -r line; do
            case "$line" in
                workspace\>\>*)
                    ws="${line#workspace>>}"
                    if [[ "$ws" =~ ^[0-9]+$ ]] && [ "$ws" -le 10 ]; then
                        msg="${ICONS[$ws]}"
                    else
                        msg="󰣇  $ws"
                    fi
                    class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')
                    case "$class" in
                        org.telegram.desktop) class="telegram" ;;
                        dev.zed.zed) class="zed" ;;
                        org.pwmt.zathura|zathura) class="zathura" ;;
                        brave-browser) class="brave" ;;
                        code-oss) class="code" ;;
                        kitty|kitty-float) class="kitty" ;;
                        firefox|librewolf) class="firefox" ;;
                    esac
                    [ -n "$class" ] && msg="$msg  ·  $class"
                    hyprctl dismissnotify 1 >/dev/null 2>&1
                    hyprctl notify 1 1800 "rgb(cba6f7)" "fontsize:16 $msg" >/dev/null 2>&1
                    ;;
            esac
        done
        ;;

    # ----- window switcher (ALT + E) -----
    switcher)
        python3 -B -c '
import sys
sys.dont_write_bytecode = True
import json, subprocess, os

ROFI_THEME = [
    "-no-lazy-filter",
    "-show-icons",
    "-theme-str", "* { font: \"JetBrainsMono Nerd Font Medium 11\"; bg: rgba(12,4,8,0.75); bg-alt: rgba(255,255,255,0.05); bg-hover: rgba(200,90,120,0.25); fg: #ffe0ec; muted: #b898a8; accent: #f8b4c8; glow: rgba(248,180,200,0.5); }",
    "-theme-str", "window { width: 54%; background-color: @bg; transparency: \"real\"; border: 2px; border-color: @glow; border-radius: 18px; }",
    "-theme-str", "mainbox { background-color: transparent; padding: 12px; spacing: 6px; }",
    "-theme-str", "inputbar { background-color: rgba(255,255,255,0.07); padding: 8px 12px; border: 1px; border-color: rgba(248,180,200,0.2); border-radius: 10px; children: [ entry ]; }",
    "-theme-str", "entry { background-color: transparent; text-color: @fg; placeholder-color: @muted; cursor-color: @accent; cursor-width: 2px; }",
    "-theme-str", "listview { columns: 1; lines: 10; fixed-height: false; dynamic: true; spacing: 4px; scrollbar: true; scrollbar-width: 4px; }",
    "-theme-str", "scrollbar { background-color: transparent; handle-color: @accent; handle-width: 4px; border-radius: 2px; }",
    "-theme-str", "element { background-color: @bg-alt; text-color: @fg; padding: 6px 12px; height: 36px; border: 1px; border-color: rgba(255,255,255,0.03); border-radius: 8px; }",
    "-theme-str", "element normal.normal { background-color: @bg-alt; text-color: @fg; }",
    "-theme-str", "element alternate.normal { background-color: @bg-alt; text-color: @fg; }",
    "-theme-str", "element selected.normal { background-color: @bg-hover; text-color: @accent; border: 2px; border-color: @accent; }",
    "-theme-str", "element-text { background-color: transparent; text-color: @fg; vertical-align: 0.5; highlight: bold #ffffff; }",
    "-theme-str", "element normal.normal element-text { background-color: transparent; text-color: @fg; }",
    "-theme-str", "element alternate.normal element-text { background-color: transparent; text-color: @fg; }",
    "-theme-str", "element selected.normal element-text { background-color: transparent; text-color: @accent; }"
]

try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
except Exception:
    sys.exit(0)

clients = [c for c in clients if c.get("mapped") and c.get("address")]
if not clients:
    sys.exit(0)

clients.sort(key=lambda c: c.get("focusHistoryID", 999))

lines = []
for c in clients:
    title = (c.get("title") or c.get("class") or "window")[:52]
    cls = c.get("class") or "?"
    lines.append(f"{title}  ·  {cls}\0icon\x1f{cls}")

cmd = ["rofi", "-dmenu", "-i", "-no-custom", "-selected-row", "0", "-format", "i", "-p", "Windows"] + ROFI_THEME
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
stdout, _ = proc.communicate(input="\n".join(lines))
if not stdout.strip():
    sys.exit(0)

try:
    idx = int(stdout.strip())
    chosen_addr = clients[idx]["address"]
    chosen_class = clients[idx].get("class", "?")
    subprocess.run(["hyprctl", "dispatch", f"hl.dsp.focus({{ window = \"address:{chosen_addr}\" }})"], stdout=subprocess.DEVNULL)
    subprocess.Popen(["hyprctl", "notify", "5", "1500", "rgb(a6e3a1)", f"  {chosen_class}"], stdout=subprocess.DEVNULL)
except Exception:
    pass
'
        ;;

    # ----- cycle non-empty workspaces (SUPER) -----
    cycle_ws)
        python3 -B -c '
import sys
sys.dont_write_bytecode = True
import json, subprocess

try:
    active = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)).get("id", 1)
    workspaces = json.loads(subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True))
    valid = sorted([w["id"] for w in workspaces if w.get("id", 0) > 0 and w.get("windows", 0) > 0])
    if len(valid) <= 1:
        sys.exit(0)
    if active in valid:
        next_ws = valid[(valid.index(active) + 1) % len(valid)]
    else:
        next_ws = valid[0]
    subprocess.run(["hyprctl", "dispatch", f"hl.dsp.focus({{ workspace = {next_ws} }})"], stdout=subprocess.DEVNULL)
except Exception:
    pass
'
        ;;

    # ----- latest video (SUPER + H) -----
    video)
        python3 -B -c '
import sys
sys.dont_write_bytecode = True
import os, subprocess

video_dir = os.path.expanduser("~/0/videos")
if not os.path.isdir(video_dir):
    sys.exit(0)

exts = (".mp4", ".mkv", ".webm", ".avi", ".mov", ".flv", ".m4v")
files = []
for root, _, filenames in os.walk(video_dir):
    for f in filenames:
        if f.lower().endswith(exts) and not f.endswith(".part"):
            full_path = os.path.join(root, f)
            try:
                mtime = os.path.getmtime(full_path)
                files.append((mtime, full_path))
            except OSError:
                pass

if not files:
    subprocess.Popen(["hyprctl", "notify", "3", "2000", "rgb(f38ba8)", "No videos found in ~/0/videos"], stdout=subprocess.DEVNULL)
    sys.exit(0)

files.sort(key=lambda x: x[0], reverse=True)
sorted_paths = [p for _, p in files]

latest_name = os.path.basename(sorted_paths[0])
display_title = (latest_name[:40] + "...") if len(latest_name) > 43 else latest_name
subprocess.Popen(["hyprctl", "notify", "1", "2000", "rgb(cba6f7)", f"🎬 Opening: {display_title}"], stdout=subprocess.DEVNULL)

subprocess.Popen(["mpv"] + sorted_paths, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
'
        ;;

    *)
        echo "Usage: $0 {mpv|video|kitty|thunar|toggle|workspace|switcher|cycle_ws}"
        exit 1
        ;;
esac
