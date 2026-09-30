#!/usr/bin/env bash

case "${1:-}" in
    # brightness
    brightness)
        dev=$(ls -1 /sys/class/backlight 2>/dev/null | head -n 1)
        [ -z "$dev" ] && exit 0
        read -r cur < "/sys/class/backlight/$dev/actual_brightness"
        read -r max < "/sys/class/backlight/$dev/max_brightness"
        pct=$((cur * 100 / max))

        case "${2:-}" in
            down)
                new_pct=$((pct - 5))
                [ "$new_pct" -lt 30 ] && new_pct=30
                ;;
            up)
                new_pct=$((pct + 5))
                [ "$new_pct" -gt 90 ] && new_pct=90
                ;;
            *)
                new_pct="$pct"
                ;;
        esac

        if command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl set "${new_pct}%" >/dev/null 2>&1
        else
            val=$((new_pct * max / 100))
            busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu "backlight" "$dev" "$val" >/dev/null 2>&1
        fi

        [ "$new_pct" -le 30 ] && icon="󰃞" || { [ "$new_pct" -le 70 ] && icon="󰃟" || icon="󰃠"; }
        hyprctl dismissnotify -1 >/dev/null 2>&1
        hyprctl notify -1 2000 0 "fontsize:18 $icon ${new_pct}%" >/dev/null 2>&1
        ;;

    # volume
    volume)
        if [ "${2:-}" = "mute" ]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            read -r _ vol status < <(wpctl get-volume @DEFAULT_AUDIO_SINK@)
            hyprctl dismissnotify -1 >/dev/null 2>&1
            if [ "$status" = "[MUTED]" ]; then
                hyprctl notify -1 1500 "rgb(ff3333)" "fontsize:18 󰖁" >/dev/null 2>&1
            else
                hyprctl notify -1 1500 "rgb(33ff33)" "fontsize:18 " >/dev/null 2>&1
            fi
            exit 0
        fi

        read -r _ vol status < <(wpctl get-volume @DEFAULT_AUDIO_SINK@)
        [ -z "$vol" ] && exit 0
        pct=$(awk -v v="$vol" 'BEGIN { printf "%d", (v * 100) + 0.5 }')

        case "${2:-}" in
            up)
                new_pct=$((pct + 5))
                color="rgb(33ff33)"
                icon="󰕾"
                ;;
            down)
                new_pct=$((pct - 5))
                color="rgb(ffaa00)"
                icon=""
                ;;
            *)
                exit 0
                ;;
        esac

        [ "$new_pct" -lt 30 ] && new_pct=30
        [ "$new_pct" -gt 90 ] && new_pct=90

        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${new_pct}%"
        hyprctl dismissnotify -1 >/dev/null 2>&1
        if [ "$status" = "[MUTED]" ]; then
            hyprctl notify -1 1500 "rgb(ff3333)" "fontsize:18 󰖁" >/dev/null 2>&1
        else
            hyprctl notify -1 1500 "$color" "fontsize:18 $icon ${new_pct}%" >/dev/null 2>&1
        fi
        ;;

    # sunset
    sunset)
        pgrep -x hyprsunset >/dev/null || hyprsunset &
        v=$(hyprctl hyprsunset temperature 2>/dev/null)
        [ -z "$v" ] && v=2000

        case "${2:-}" in
            down)
                v=$((v - 300))
                [ "$v" -lt 1200 ] && v=1200
                ;;
            up)
                v=$((v + 300))
                [ "$v" -gt 2700 ] && v=2700
                ;;
        esac

        hyprctl hyprsunset temperature "$v"
        [ "$v" -le 2000 ] && icon="󰃛" || icon="󰃜"
        hyprctl dismissnotify -1 >/dev/null 2>&1
        hyprctl notify -1 2000 0 "fontsize:18 $icon ${v}K" >/dev/null 2>&1
        ;;

    # toggle
    toggle)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.7
        command -v brightnessctl >/dev/null 2>&1 && brightnessctl set 60% >/dev/null 2>&1
        s=""
        if pgrep -x hyprsunset >/dev/null; then
            pkill -x hyprsunset >/dev/null 2>&1
        else
            hyprsunset >/dev/null 2>&1 &
            sleep 0.2
            hyprctl hyprsunset temperature 2600 >/dev/null 2>&1
            s=" 󰃛 2600K"
        fi
        ram=""
        if [ -r /proc/meminfo ]; then
            ram=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {printf "%.2f GB", (t-a)/(1024*1024)}' /proc/meminfo)
        fi
        hyprctl dismissnotify -1 >/dev/null 2>&1
        hyprctl notify 0 2000 0 "fontsize:18 󰕾 70% 󰃟 60%${s} 󰘚 ${ram}" >/dev/null 2>&1
        ;;

    # switcher
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

    # video
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

    # spotify
    spotify-listener)
        exec 200>/tmp/spotify_listener.lock
        flock -n 200 || exit 0

        playerctl --follow status -f '{{playerName}} {{status}}' 2>/dev/null | while read -r player status; do
            if [ "$player" = "spotify" ] && [ "$status" = "Playing" ]; then
                pkill -x mpv 2>/dev/null
            fi
        done
        ;;

    *)
        echo "Usage: $0 {brightness [up|down]|volume [up|down|mute]|sunset [up|down]|toggle|switcher|video|spotify-listener}"
        exit 1
        ;;
esac
