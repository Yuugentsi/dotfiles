#!/usr/bin/env bash

case "${1:-}" in
    # recording
    record)
        recording_state="${XDG_RUNTIME_DIR:-/tmp}/hypr-recording-$UID"
        exec 9>"$recording_state.lock"
        flock -w 5 9 || exit 0

        if [[ -f "$recording_state.pid" ]]; then
            read -r recording_pid < "$recording_state.pid"
            if [[ "$recording_pid" =~ ^[0-9]+$ ]] &&
                [[ "$(cat "/proc/$recording_pid/comm" 2>/dev/null)" == "wf-recorder" ]]; then
                kill -INT "$recording_pid"
                for ((recording_attempt = 0; recording_attempt < 50; recording_attempt++)); do
                    kill -0 "$recording_pid" 2>/dev/null || break
                    sleep 0.1
                done
                if kill -0 "$recording_pid" 2>/dev/null; then
                    printf '%s\n' "Recording is still finishing" >> "$recording_state.log"
                    exit 1
                fi
                "$HOME/.config/hypr/scripts/quickshell.sh" notify 5 1000 "rgb(80ff80)" "Recording stopped" >/dev/null 2>&1
                exit 0
            fi
            rm -f "$recording_state.pid"
        fi

        recording_sink=$(pactl get-default-sink 2>/dev/null)
        recording_audio="$recording_sink.monitor"
        if [[ -z "$recording_sink" ]] || ! pactl list short sources 2>/dev/null |
            awk -v source="$recording_audio" '$2 == source { found = 1 } END { exit !found }'; then
            "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 4000 "rgb(ff8080)" "System audio unavailable" >/dev/null 2>&1
            exit 1
        fi

        recording_dir="$HOME/0/videos/recordings"
        mkdir -p "$recording_dir" || exit 1
        "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 1000 "rgb(ff8080)" "Recording starts in 1 second" >/dev/null 2>&1
        sleep 1
        "$HOME/.config/hypr/scripts/quickshell.sh" dismiss -1 >/dev/null 2>&1
        recording_file="$recording_dir/$(date +%m-%d-%Y_%H-%M-%S).mp4"
        (
            exec 9>&-
            wf-recorder --audio="$recording_audio" -f "$recording_file" > "$recording_state.log" 2>&1 &
            recording_pid=$!
            echo "$recording_pid" > "$recording_state.pid"
            wait "$recording_pid"
            recording_result=$?
            rm -f "$recording_state.pid"
            if [[ "$recording_result" -ne 0 && "$recording_result" -ne 130 ]]; then
                "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 4000 "rgb(ff8080)" "Recording failed: $recording_state.log" >/dev/null 2>&1
            fi
        ) </dev/null >/dev/null 2>&1 &
        for ((recording_attempt = 0; recording_attempt < 50; recording_attempt++)); do
            [[ -f "$recording_state.pid" ]] && break
            sleep 0.02
        done
        ;;

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
        "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 2000 0 "fontsize:18 $icon ${new_pct}%" >/dev/null 2>&1
        ;;

    # volume
    volume)
        if [ "${2:-}" = "mute" ]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            read -r _ vol status < <(wpctl get-volume @DEFAULT_AUDIO_SINK@)
            "$HOME/.config/hypr/scripts/quickshell.sh" dismiss -1 >/dev/null 2>&1
            if [ "$status" = "[MUTED]" ]; then
                "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 1500 "rgb(ff3333)" "fontsize:18 󰖁" >/dev/null 2>&1
            else
                "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 1500 "rgb(33ff33)" "fontsize:18 " >/dev/null 2>&1
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
        [ "$new_pct" -gt 95 ] && new_pct=95

        wpctl set-volume --limit 0.95 @DEFAULT_AUDIO_SINK@ "${new_pct}%"
        "$HOME/.config/hypr/scripts/quickshell.sh" dismiss -1 >/dev/null 2>&1
        if [ "$status" = "[MUTED]" ]; then
            "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 1500 "rgb(ff3333)" "fontsize:18 󰖁" >/dev/null 2>&1
        else
            "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 1500 "$color" "fontsize:18 $icon ${new_pct}%" >/dev/null 2>&1
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
        "$HOME/.config/hypr/scripts/quickshell.sh" notify -1 2000 0 "fontsize:18 $icon ${v}K" >/dev/null 2>&1
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
            hyprctl hyprsunset temperature 2800 >/dev/null 2>&1
            hyprctl hyprsunset gamma 70 >/dev/null 2>&1
            s=" 󰃛 2800K · gamma 70%"
        fi
        ram=""
        if [ -r /proc/meminfo ]; then
            ram=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {printf "%.2f GB", (t-a)/(1024*1024)}' /proc/meminfo)
        fi
        "$HOME/.config/hypr/scripts/quickshell.sh" dismiss -1 >/dev/null 2>&1
        "$HOME/.config/hypr/scripts/quickshell.sh" notify 0 2000 0 "fontsize:18 󰕾 70% 󰃟 60%${s} 󰘚 ${ram}" >/dev/null 2>&1
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
    subprocess.Popen([os.path.expanduser("~/.config/hypr/scripts/quickshell.sh"), "notify", "3", "2000", "rgb(f38ba8)", "No videos found in ~/0/videos"], stdout=subprocess.DEVNULL)
    sys.exit(0)

files.sort(key=lambda x: x[0], reverse=True)
sorted_paths = [p for _, p in files]

latest_name = os.path.basename(sorted_paths[0])
display_title = (latest_name[:40] + "...") if len(latest_name) > 43 else latest_name
subprocess.Popen([os.path.expanduser("~/.config/hypr/scripts/quickshell.sh"), "notify", "1", "2000", "rgb(cba6f7)", f"🎬 Opening: {display_title}"], stdout=subprocess.DEVNULL)

subprocess.Popen(["mpv"] + sorted_paths, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
'
        ;;

    # spotify
    spotify-listener)
        exec 200>/tmp/spotify_listener.lock
        flock -n 200 || exit 0

        playerctl --player=spotify --follow status 2>/dev/null | while IFS= read -r status; do
            case "$status" in
                Playing)
                    pkill -x mpv 2>/dev/null
                    ;;
            esac
        done
        ;;

    *)
        echo "Usage: $0 {brightness [up|down]|volume [up|down|mute]|sunset [up|down]|toggle|video|spotify-listener}"
        exit 1
        ;;
esac
