# zips
# extract
# crossfade
# live
# nodisplay
# power
# past
# clients
# h
# l
# word
# search
# lf
# playing
# mem

# ━━━━━━━━━━━━━━━━━━━━━━━━━━ zips / extract ━━━━━━━━━━━━━━━━━━━━━━━━━━
function zips -d "compression menu"
    set -l P (set_color cba6f7)
    set -l G (set_color a6e3a1)
    set -l Y (set_color yellow)
    set -l B (set_color 89b4fa)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    echo "$D󰗄 Zip$N"
    echo "  [1] $Y󰛫 zip into one$N"
    echo "  [2] $P󰉓 zip separately$N"
    echo "  [3] $B󰃨 extract here$N"
    read -P "→ " choice

    switch $choice
        case 1
            clear
            set -l current (basename "$PWD")
            set -l archive "$current.zip"
            set -l targets (find . -maxdepth 1 -mindepth 1 ! -name "$archive" -print0 2>/dev/null | string split0)

            if test (count $targets) -eq 0
                echo "zips: no files or directories to zip here"
                return 1
            end

            rm -f "$archive"
            __zips_progress "$archive" $targets

        case 2
            clear
            set -l targets (find . -maxdepth 1 -mindepth 1 ! -name '*.zip' -print0 2>/dev/null | string split0)

            if test (count $targets) -eq 0
                echo "zips: no files or directories to zip here"
                return 1
            end

            for target in $targets
                set -l name (basename "$target")
                set -l archive "$name.zip"
                rm -f "$archive"
                __zips_progress "$archive" "$target"
            end

        case 3
            clear
            extract

        case 0 ''
            return 0
    end
end

# ── extract ──
function extract -d "unzip all archives"
    set -l archives (find . -maxdepth 1 -type f -name "*.zip" 2>/dev/null)

    if test -z "$archives"
        echo "extract: no zip files found here"
        return 1
    end

    for z in $archives
        set -l name (basename "$z" .zip)
        mkdir -p "$name"
        unzip -qo "$z" -d "$name"
        set -l files (find "$name" -type f | wc -l | string trim)
        echo "extracted: $z -> $name/ ($files files)"
    end
end

function __zips_progress -d "zip with progress"
    if test (count $argv) -lt 2
        return 1
    end

    set -l archive $argv[1]
    set -l targets $argv[2..-1]
    set -l cols (tput cols)
    set -l max (math $cols - 4)

    zip -r "$archive" $targets | while read -l line
        set -l item (string match -rg 'adding: (.+) \(' -- "$line")
        if test -n "$item"
            set -l truncated (string sub -l $max -- "$item")
            printf "\r\033[K󰗄 %s" "$truncated"
        end
    end

    if test $pipestatus[1] -eq 0
        printf "\r\033[K"
        set -l size (du -h "$archive" | cut -f1)
        echo "󰄬 $archive ($size)"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
    end
end

# -------- crossfade --------
function crossfade --description 'Merge random music files from the current directory with crossfade'
    argparse h/help -- $argv; or return 2

    if set -q _flag_help
        printf 'Usage: crossfade <count> [fade_seconds]\n'
        return 0
    end

    if test (count $argv) -lt 1; or test (count $argv) -gt 2
        printf 'Usage: crossfade <count> [fade_seconds]\n' >&2
        return 2
    end

    if not string match -qr '^[1-9][0-9]*$' -- "$argv[1]"
        printf 'The track count must be a positive integer.\n' >&2
        return 2
    end

    for dependency in ffmpeg ffprobe find shuf python3
        if not command -q $dependency
            printf 'Missing command: %s\n' "$dependency" >&2
            return 1
        end
    end

    set -l track_count $argv[1]
    set -l fade_seconds 5
    if test (count $argv) -eq 2
        set fade_seconds $argv[2]
    end
    if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$fade_seconds"; or not test "$fade_seconds" -gt 0
        printf 'The crossfade duration must be a positive number.\n' >&2
        return 2
    end

    set -l files (command find "$PWD" -maxdepth 1 -type f \( \
        -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.wav' \
        -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.aac' \
        -o -iname '*.wma' -o -iname '*.aiff' -o -iname '*.aif' \) -print0 | string split0)

    if test (count $files) -lt "$track_count"
        printf 'Requested %s tracks, but this directory contains %s music files.\n' "$track_count" (count $files) >&2
        return 1
    end

    set -l selected (printf '%s\0' $files | command shuf -z -n "$track_count" | string split0)
    set -l arguments
    set -l durations
    set -l starts
    set -l ends
    set -l titles
    set -l index 0

    for file in $selected
        set -l duration (command ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file")
        if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$duration"; or not test "$duration" -gt 0
            printf 'Cannot read the audio duration: %s\n' "$file" >&2
            return 1
        end
        printf 'Analyzing: %s\n' (path basename "$file")
        set -l boundaries (command python3 -c '
from array import array
import math
import statistics
import subprocess
import sys

source, duration, index, count = sys.argv[1:]
duration, index, count = float(duration), int(index), int(count)
window = min(30, duration)

def envelope(start):
    raw = subprocess.check_output([
        "ffmpeg", "-nostdin", "-v", "error", "-ss", str(start), "-i", source,
        "-t", str(window), "-ac", "2", "-ar", "2000", "-f", "s16le", "-",
    ])
    samples = array("h")
    samples.frombytes(raw)
    levels = []
    for offset in range(0, len(samples), 1000):
        segment = samples[offset:offset + 1000]
        rms = math.sqrt(sum(value * value for value in segment) / len(segment)) / 32768
        levels.append(20 * math.log10(max(rms, 1e-8)))
    return levels

start, end = 0.0, duration
if index > 0:
    head = envelope(0)
    reference = [level for level in head[len(head) // 2:] if level > -60]
    if reference:
        threshold = max(-50, statistics.median(reference) - 5)
        onset = next((position for position in range(len(head) - 2)
                      if all(level >= threshold for level in head[position:position + 3])), 0)
        start = max(0, onset * 0.25 - 0.15)
if index < count - 1:
    tail = envelope(duration - window)
    reference = [level for level in tail[:len(tail) // 2] if level > -60]
    if reference:
        threshold = max(-50, statistics.median(reference) - 5)
        cutoff = next((position for position in range(len(tail) // 2, len(tail) - 3)
                       if all(level < threshold for level in tail[position:position + 4])), len(tail))
        end = min(duration, duration - window + cutoff * 0.25)
if end <= start:
    raise ValueError("No usable audio section found")
print(start)
print(end)
print(end - start)
' "$file" "$duration" "$index" "$track_count")
        if test $status -ne 0; or test (count $boundaries) -ne 3
            printf 'Cannot analyze the music boundaries: %s\n' "$file" >&2
            return 1
        end
        set -a starts "$boundaries[1]"
        set -a ends "$boundaries[2]"
        set -a durations "$boundaries[3]"
        set fade_seconds (math "min($fade_seconds, $boundaries[3] / 2)")
        set -l title (command ffprobe -v error -show_entries format_tags=title -of default=nw=1:nk=1 "$file" | string collect)
        if test -z "$title"
            set title (path basename "$file")
        end
        set -a titles "$title"
        set index (math "$index + 1")
        printf '%s. %s\n' "$index" "$title"
        set -a arguments -i "$file"
    end

    set -l graph
    set index 0
    for duration in $durations
        set -l position (math "$index + 1")
        set -a graph "[$index:a:0]atrim=start=$starts[$position]:end=$ends[$position],"'asetpts=PTS-STARTPTS,aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo'"[a$index]"
        set index (math "$index + 1")
    end

    set -l previous a0
    for index in (seq 1 (math "$track_count - 1"))
        set -a graph "[$previous][a$index]acrossfade=d=$fade_seconds:c1=qsin:c2=qsin[mix$index]"
        set previous "mix$index"
    end
    set -a graph "[$previous]alimiter=limit=0.92:level=0:latency=1[out]"

    set -l output_dir "$PWD/crossfade"
    command mkdir -p "$output_dir"; or return 1
    set -l output (command mktemp "$output_dir/mix-XXXXXX.mp3"); or return 1
    command ffmpeg -nostdin -hide_banner -loglevel error -stats -y $arguments \
        -filter_complex (string join ';' -- $graph) -map '[out]' \
        -c:a libmp3lame -b:a 256k -threads 1 -metadata title=Crossfade \
        -metadata "comment="(string join ' / ' -- $titles) "$output"
    set -l result $status
    if test "$result" -ne 0
        command rm -f "$output"
        return "$result"
    end
    printf '\n%s\n' "$output"
end

function __live_log
    set -l log_file "$HOME/.cache/live.log"
    set -l status_file "$HOME/.cache/live.status"
    mkdir -p "$HOME/.cache"
    set -l message_text $argv[-1]
    printf '[%s] %s\n' (date '+%H:%M:%S') "$message_text" >> "$log_file"
    printf '%s\n' "$message_text" > "$status_file"
end

function __live_monitor -a target
    set -l extra_args $argv[2..-1]
    set -l state_file "$HOME/.cache/live.state"
    set -l stop_file "$HOME/.cache/live.stop"
    set -l retry_count 0
    set -l max_retries 3

    while true
        test -e "$stop_file"; and return
        set -l log_file (mktemp /tmp/live-mpv.XXXXXX.log); or return 1
        __live_log 5 3500 "rgb(89dceb)" "Live: looking for stream"

        mpv \
            --ytdl-raw-options=no-config= \
            --ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]/best" \
            --af='lavfi=[silencedetect=noise=-45dB:d=2]' \
            --msg-level=all=info \
            --log-file="$log_file" \
            $extra_args "$target" </dev/null >/dev/null 2>&1 &
        set -l player_pid $last_pid
        set -l lines 0
        set -l playing false
        set -l user_quit false
        set -l waiting 0
        set -l video_found false
        set -l audio_found false
        printf '%s\n' "$player_pid" > "$state_file"

        while kill -0 $player_pid 2>/dev/null
            if test -e "$stop_file"
                kill $player_pid 2>/dev/null
                break
            end

            set -l current_lines (wc -l < "$log_file")
            if test $current_lines -gt $lines
                for line in (tail -n +(math $lines + 1) "$log_file")
                    if string match -q '*Playing:*' -- "$line"; and test "$playing" = false
                        __live_log 5 3500 "rgb(a6e3a1)" "Live: playback started"
                        set playing true
                    else if string match -q '*Opening*' -- "$line"
                        __live_log 5 3500 "rgb(89dceb)" "Live: opening stream"
                    else if string match -q '*Video --vid*' -- "$line"; and test "$video_found" = false
                        __live_log 5 3500 "rgb(89dceb)" "Live: video track detected"
                        set video_found true
                    else if string match -q '*Audio --aid*' -- "$line"; and test "$audio_found" = false
                        __live_log 5 3500 "rgb(89dceb)" "Live: audio track detected"
                        set audio_found true
                    else if string match -q '*silence_start*' -- "$line"
                        __live_log 2 3500 "rgb(f9e2af)" "Live: no audio detected"
                    else if string match -q '*silence_end*' -- "$line"
                        __live_log 5 3500 "rgb(a6e3a1)" "Live: audio detected again"
                    else if string match -q '*Exiting... (Quit)*' -- "$line"
                        set user_quit true
                    else if string match -qi '*error*' -- "$line"
                        set -l error_message (string sub -l 140 -- "$line")
                        __live_log 2 5000 "rgb(f38ba8)" "Live: $error_message"
                    end
                end
                set lines $current_lines
            end
            sleep 1
            if test "$playing" = false
                set waiting (math $waiting + 1)
                if test (math "$waiting % 10") -eq 0
                    __live_log 2 5000 "rgb(f9e2af)" "Live: still connecting ($waiting seconds elapsed)"
                end
            end
        end

        set -l current_lines (wc -l < "$log_file")
        if test $current_lines -gt $lines
            for line in (tail -n +(math $lines + 1) "$log_file")
                if string match -q '*Exiting... (Quit)*' -- "$line"
                    set user_quit true
                end
            end
        end

        wait $player_pid
        set -l player_status $status
        command rm -f "$log_file"
        command rm -f "$state_file"

        if test "$user_quit" = true; or test -e "$stop_file"; or contains -- $player_status 130 137 143
            command rm -f "$stop_file"
            __live_log 2 3500 "rgb(f38ba8)" "Live stopped"
            return
        end

        if test $retry_count -ge $max_retries
            __live_log 2 6000 "rgb(f38ba8)" "Live stopped after $max_retries retries"
            return 1
        end

        set retry_count (math $retry_count + 1)
        __live_log 2 5000 "rgb(f38ba8)" "Live ended (mpv exit $player_status); retry $retry_count of $max_retries in 10 seconds"
        sleep 10
    end
end

# -------- live --------
function live --description 'Play a YouTube live with stream and audio status'
    if test "$argv[1]" = stop
        set -l state_file "$HOME/.cache/live.state"
        set -l stop_file "$HOME/.cache/live.stop"
        mkdir -p "$HOME/.cache"
        touch "$stop_file"
        if test -s "$state_file"
            set -l player_pid (cat "$state_file")
            kill $player_pid 2>/dev/null
        end
        command pkill -f '[f]ish -c source .*__live_monitor' 2>/dev/null
        command pkill -f '[/]home/y/.local/bin/live-monitor' 2>/dev/null
        command pkill -f '[m]pv.*silencedetect' 2>/dev/null
        command rm -f "$state_file"
        __live_log 2 3500 "rgb(f38ba8)" "Live stopped"
        return
    end

    if test "$argv[1]" = status; or test "$argv[1]" = log
        if test -f "$HOME/.cache/live.log"
            if test "$argv[1]" = status
                tail -n 10 "$HOME/.cache/live.log"
            else
                cat "$HOME/.cache/live.log"
            end
        else
            echo "No live activity recorded"
        end
        return
    end

    set -l state_file "$HOME/.cache/live.state"
    if test -s "$state_file"
        set -l player_pid (cat "$state_file")
        if kill -0 $player_pid 2>/dev/null
            __live_log 2 3500 "rgb(f9e2af)" "Live is already running"
            return 1
        end
        command rm -f "$state_file"
    end

    if not command -v mpv >/dev/null 2>&1
        echo -s (set_color red) "mpv not found" (set_color normal)
        return 1
    end

    set -l target ""
    set -l extra_args

    for arg in $argv
        if test -z "$target"; and not string match -qr '^-' -- "$arg"
            set target "$arg"
        else
            set -a extra_args "$arg"
        end
    end

    if test -z "$target"
        if command -v wl-paste >/dev/null 2>&1
            set -l clip (wl-paste -n 2>/dev/null | string trim)
            if string match -qr '^https?://' -- "$clip"
                set target "$clip"
            end
        end
    end

    if test -z "$target"
        echo -s (set_color yellow) "Usage: " (set_color normal) "live <url_or_channel> [mpv options]"
        return 1
    end

    if not string match -qr '^https?://' -- "$target"
        set -l clean (string replace -r '^@' '' -- "$target")
        set target "https://www.youtube.com/@$clean/live"
    else if string match -qr 'youtube\.com/@' -- "$target"
        if not string match -qr '/live/?$' -- "$target"
            set target (string replace -r '/+$' '' -- "$target")"/live"
        end
    end

    mkdir -p "$HOME/.cache"
    command rm -f "$HOME/.cache/live.stop"
    printf '[%s] Live monitor started\n' (date '+%H:%M:%S') > "$HOME/.cache/live.log"
    nohup fish -c 'source "$HOME/.config/fish/functions/utils.fish"; __live_monitor $argv' -- "$target" $extra_args </dev/null >/dev/null 2>&1 &
    disown

    if command -q hyprctl
        hyprctl notify 5 5000 "rgb(89dceb)" "Live monitor started; run live status to follow progress" >/dev/null 2>&1
    end

    echo -s (set_color cyan) "󰐊 Live is running in the background; use live status for progress." (set_color normal)
end

# -------- nodisplay --------
function nodisplay -d "hide/show desktop apps"
    set -l apps \
        avahi-discover.desktop bssh.desktop bvnc.desktop \
        xfce4-about.desktop qv4l2.desktop qvidcap.desktop \
        xgps.desktop xgpsspeed.desktop org.freedesktop.Xwayland.desktop \
        kitty-open.desktop thunar-bulk-rename.desktop thunar-settings.desktop \
        org.gnupg.pinentry-qt5.desktop org.gnupg.pinentry-qt.desktop \
        electron36.desktop electron37.desktop \
        rofi.desktop rofi-theme-selector.desktop org.gnome.FileRoller.desktop

    set -l action $argv[1]

    if test -z "$action"
        set action on
        for app in $apps
            set -l file "/usr/share/applications/$app"
            if test -f "$file"; and grep -q '^NoDisplay=true$' "$file"
                set action off
                break
            end
        end
    end

    switch $action
        case off remove
            for app in $apps
                set -l file "/usr/share/applications/$app"
                test -f "$file" && sudo sed -i '/^NoDisplay=true$/d' "$file"
            end
            echo (set_color green)"󰄬 visible"(set_color normal)

        case on
            for app in $apps
                set -l file "/usr/share/applications/$app"
                if test -f "$file"; and not grep -q '^NoDisplay=true$' "$file"
                    echo "NoDisplay=true" | sudo tee -a "$file" >/dev/null
                end
            end
            echo (set_color red)"󰄬 hidden"(set_color normal)

        case '*'
            echo (set_color brblack)"󰇙 usage: nodisplay [on|off]"(set_color normal)
    end
end

# -------- power --------
function power -d "power menu"
    set -l R (set_color red)
    set -l Y (set_color yellow)
    set -l P (set_color cba6f7)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    echo "$D󰐥 Power$N"
    echo "  [1] $R󰐥 shutdown$N"
    echo "  [2] $Y󰜉 reboot$N"
    echo "  [3] $P󰍃 logout$N"

    read -P "→ " choice

    switch $choice
        case 1
            systemctl poweroff
        case 2
            systemctl reboot
        case 3
            hyprctl dispatch exit
        case 0 ''
            return 0
    end
end

# -------- past --------
function past -d "thunar bookmarks"
    set -l bookmarks_file ~/.config/gtk-3.0/bookmarks

    if test -f "$bookmarks_file"
        rm -f "$bookmarks_file"
        echo "bookmarks removed"
    else
        set -l home_dir $HOME

        set -l paths \
            "$home_dir/.config" \
            "$home_dir/Downloads" \
            "$home_dir/0" \
            "$home_dir/0/documents" \
            "$home_dir/0/music" \
            "$home_dir/0/pictures" \
            "$home_dir/0/videos"

        mkdir -p ~/.config/gtk-3.0
        mkdir -p $paths

        printf '%s\n' \
            "file://$home_dir/.config/" \
            "file://$home_dir/Downloads/" \
            "file://$home_dir/0" \
            "file://$home_dir/0/documents" \
            "file://$home_dir/0/music" \
            "file://$home_dir/0/pictures" \
            "file://$home_dir/0/videos" \
            > "$bookmarks_file"

        echo "bookmarks restored"
    end
end

function fish_command_not_found --on-event fish_command_not_found
    if string match -qr '^https://wallhaven\.cc/' -- $argv[1]
        if not command -v gallery-dl >/dev/null 2>&1; echo "gallery-dl not found"; return; end
        if not command -v hyprctl >/dev/null 2>&1; echo "hyprctl not found"; return; end
        echo "  [1] 󰋱 wallpaper"; echo "  [2] 󰖯 blur"
        read -P "→ " c
        set -l Y (set_color yellow); set -l N (set_color normal); set -l G (set_color green); set -l R (set_color red)
        set -l cache $HOME/.cache/scripts/wallpapers; mkdir -p $cache
        echo -s "󱎫 " $Y "downloading..." $N
        set -l i (realpath (gallery-dl $argv[1] 2>&1 | tail -n1 | string replace -r '^#\s+' '') 2>/dev/null)
        if test -z "$i"; or not test -f "$i"; echo -s $R "download failed" $N; return; end
        if test "$c" = 2
            if not command -v magick >/dev/null 2>&1; and not command -v convert >/dev/null 2>&1; and not command -v gm >/dev/null 2>&1; echo -s $R "imagemagick not found" $N; return; end
            echo -s "󱎫 " $Y "blurring..." $N
            if command -v magick >/dev/null 2>&1; magick $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current
            else if command -v convert >/dev/null 2>&1; convert $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current
            else; gm convert $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current; end
            if test $status -ne 0; echo -s $R "blur failed" $N; return; end
        else; cp -- $i $cache/current; end
        printf "%s\n" $cache/current > $cache/wallpaper
        printf "splash = false\nipc = true\npreload = %s\nwallpaper = ,%s,cover\n" $cache/current $cache/current > $cache/hyprpaper.conf
        if not pgrep -x hyprpaper >/dev/null; hyprpaper -c $cache/hyprpaper.conf >/tmp/hyprpaper-wl.log 2>&1 &; sleep 0.5; end
        hyprctl hyprpaper preload $cache/current >/dev/null 2>&1; or true
        hyprctl hyprpaper wallpaper ",$cache/current,cover" >/dev/null 2>&1
        hyprctl hyprpaper unload unused >/dev/null 2>&1; or true
        set -l s "wallpaper set"; if test "$c" = 2; set s "wallpaper set (blur)"; end
        echo -s $G "󰄬 $s" $N; hyprctl notify -1 2200 "rgb(cba6f7)" "󰄬 $s" >/dev/null 2>&1
        return
    end
    if type -q __extra_cnf; __extra_cnf $argv; and return; end
    __fish_default_command_not_found_handler $argv
end

# -------- clients --------
function clients -d "hyprctl clients"
    clear && hyprctl clients | python3 -c '
import sys, re
from collections import defaultdict

def c(n):
    return f"\033[38;5;{n}m"

def vlen(s):
    return len(re.sub(r"\033\[[0-9;]*m", "", s))
NN = "\033[0m"

PALETTE = [117, 120, 222, 140, 110, 215, 150, 175, 117, 120, 222]

APP_COLORS = {
    "spotify":      82,
    "librewolf":    39,
    "kitty":        206,
    "dev.zed.Zed": 221,
    "org.telegram.desktop": 75,
}

PAIRS = [
    ("mapped","hidden"),("visible","acceptsInput"),("at","size"),
    ("workspace","floating"),("monitor","class"),
    ("xwayland","pinned"),("fullscreen","fullscreenClient"),
    ("overFullscreen","grouped"),("focusHistoryID","inhibitingIdle"),
    ("contentType","stableID"),
]

SINGLE = ["swallowing"]
SKIP = {"tags","xdgTag","xdgDescription"}

windows = []

for b in sys.stdin.read().strip().split("\n\n"):
    lines = b.strip().split("\n")
    if not lines: continue
    title = re.search(r"-> (.+):$", lines[0])
    title = title.group(1) if title else ""

    f = {}
    for l in lines[1:]:
        m = re.match(r"\s*([a-zA-Z]+):\s*(.*)", l)
        if m: f[m.group(1)] = m.group(2)

    ws = f.get("workspace", "0")
    ws_num = int(re.search(r"\d+", ws).group()) if re.search(r"\d+", ws) else 0
    windows.append((ws_num, title, f))

windows.sort(key=lambda x: x[0])

by_ws = defaultdict(list)
for ws_num, title, f in windows:
    by_ws[ws_num].append((title, f))

for ws_num in sorted(by_ws.keys()):
    ws_label = f" Workspace {ws_num} "
    side = (40 - len(ws_label)) // 2
    rest = 40 - len(ws_label) - side
    print(f"{c(240)}" + "\u2501" * side + f"\033[1m{ws_label}{c(240)}" + "\u2501" * rest + f"{NN}")

    for title, f in by_ws[ws_num]:

        cls = f.get("class", "")
        ac = APP_COLORS.get(cls, 44)
        sz = f.get("size", "").split(",")
        w, h = sz[0], sz[1] if len(sz) > 1 else ""
        print(f"{c(ac)}\u250a {cls}  {c(240)}\u00b7{NN}  {w}\u00d7{h}{NN}")
        print(f"{c(ac)}\u250a {title}{NN}")
        ic = f.get("initialClass","")
        pidi = f.get("pid","")
        print(f"initialClass: {ic}")
        print(f"pid: {pidi}")

        items = []
        for a, b in PAIRS:
            for k in (a, b):
                v = f.get(k, "")
                if k in SKIP and not v: continue
                items.append((k, v))
        for k in SINGLE:
            v = f.get(k, "")
            if k in SKIP and not v: continue
            items.append((k, v))

        def sort_key(item):
            k, v = item
            if v == "0":               return (2, k)
            if v.replace("-","").isdigit(): return (1, k)
            return (0, k)

        items.sort(key=sort_key)

        for i in range(0, len(items), 2):
            col = PALETTE[(i // 2) % len(PALETTE)]
            a, va = items[i]
            if i + 1 < len(items):
                b, vb = items[i + 1]
                left = f"{c(col)}{a}: \033[1m{va}\033[0m{NN}"
                right = f"{c(col)}{b}: \033[1m{vb}\033[0m{NN}"
                if vlen(left) > 42 or vlen(right) > 42:
                    print(left)
                    print(right)
                else:
                    print(f"{left:<42} {c(col)}\u2502{NN} {right}")
            else:
                print(f"{c(col)}{a}: \033[1m{va}\033[0m{NN}")

        print()

    print()

for ws, title, f in windows:
    cls = f.get("class", "")
    ac = APP_COLORS.get(cls, 44)
    sz = f.get("size", "").split(",")
    w, h = sz[0], sz[1] if len(sz) > 1 else ""
    print(f"{c(ac)}{cls}  {c(240)}\u00b7{NN}  {w}\u00d7{h}  {c(240)}\u2503{NN}  {ws}")
'
end

# -------- h --------
function h --description '⌘'
    set -l cyan ''
    set -l pink ''
    set -l dim ''
    set -l text ''
    set -l reset ''
    if isatty stdout; and not set -q NO_COLOR
        set cyan (set_color --bold 00e5ff)
        set pink (set_color --bold ff4fbd)
        set dim (set_color 7b849c)
        set text (set_color e6faff)
        set reset (set_color normal)
    end
    set -l separator (printf '\x1f')
    set -l config "$HOME/.config/fish/config.fish"
    set -l directory "$HOME/.config/fish/functions"
    set -l files
    set -l sections
    set -l config_sections
    set -l longest_name 0
    set -l filter (string join ' ' -- $argv)
    if test -f "$config"
        set -a files "$config"
    end
    if test -d "$directory"
        set -a files (command find "$directory" -maxdepth 1 -type f -name '*.fish' -print | command sort)
    end
    for file in $files
        set -l label (path basename -- "$file" | string replace -r '\.fish$' '')
        if test "$file" != "$config"; and test "$label" = config
            set label functions/config
        end
        set -l entries (command fish_indent < "$file" 2>/dev/null | command rg '^function[[:blank:]]')
        set -l visible
        for entry in $entries
            set -l name (string match -rg '^function\s+([^;\s]+)' -- "$entry")
            if test -z "$name"; or string match -qr '^_|^fish_' -- "$name"
                continue
            end
            if test -n "$filter"; and not string match -iq -- "*$filter*" "$name"
                continue
            end
            set -a visible "$entry"
            set longest_name (math "max($longest_name, "(string length -- "$name")")")
        end
        set -l entry_count (count $visible)
        if test "$entry_count" -eq 0
            continue
        end
        set -l section "$entry_count$separator$label$separator"(string join '§' -- $visible)
        if test "$file" = "$config"
            set -a config_sections "$section"
        else
            set -a sections "$section"
        end
    end
    set -l ordered $config_sections
    if set -q sections[1]
        set -a ordered (printf '%s\0' $sections | command sort -z -t "$separator" -k1,1nr -k2,2 | string split0)
    end
    set -l total_functions 0
    for section in $ordered
        set -l fields (string split "$separator" -- "$section")
        set total_functions (math "$total_functions + $fields[1]")
    end
    set -l width 80
    if set -q COLUMNS; and string match -qr '^[0-9]+$' -- "$COLUMNS"
        set width (math "max(28, min(120, $COLUMNS))")
    end
    set -l columns 1
    if test "$width" -ge 76
        set columns 2
    end
    set -l column_width (math "floor(($width - 6) / $columns)")
    set -l name_width (math "min($longest_name, max(8, floor($column_width / 3)))")
    set -l description_width (math "max(1, $column_width - $name_width - 4)")
    set -l rule (string repeat -n (math "$width - 4") '─')
    printf '\n  %s╱╱ ⌘%s  %s%02d%s  %s▤ %s%s\n' "$cyan" "$reset" "$text" "$total_functions" "$reset" "$dim" (count $ordered) "$reset"
    printf '  %s%s%s\n' "$dim" "$rule" "$reset"
    if not set -q ordered[1]
        printf '\n  %s∅%s\n\n' "$dim" "$reset"
        return 1
    end
    for section in $ordered
        set -l fields (string split "$separator" -- "$section")
        set -l entries (string split '§' -- "$fields[3]")
        set -l icon ◈
        switch "$fields[2]"
            case config
                set icon ⚙
            case utils
                set icon ⌘
            case network
                set icon 󰤨
            case yt
                set icon 󰗃
            case art
                set icon 󰎆
            case ins
                set icon 󰏖
        end
        printf '\n  %s%s %s%s  %s╱ %02d%s\n' "$pink" "$icon" "$fields[2]" "$reset" "$dim" "$fields[1]" "$reset"
        set -l position 0
        for entry in $entries
            set -l name (string match -rg '^function\s+([^;\s]+)' -- "$entry")
            set -l description (string match -rg -- '^function\s+[^;\s]+[^;]*?\s(?:--description|-description|-d)\s+"([^"]*)"' "$entry")
            if test -z "$description"
                set description (string match -rg -- '^function\s+[^;\s]+[^;]*?\s(?:--description|-description|-d)\s+\x27([^\x27]*)\x27' "$entry")
            end
            if test -z "$description"
                set description (string match -rg -- '^function\s+[^;\s]+[^;]*?\s(?:--description|-description|-d)\s+([^;\s"\x27]+)' "$entry")
            end
            if string match -qr '^script:' -- "$description"; or test -z "$description"
                set description '·'
            end
            set name (string shorten --max "$name_width" -- "$name")
            set description (string shorten --max "$description_width" -- "$description")
            if test (math "$position % $columns") -eq 0
                printf '  '
            end
            printf '%s│%s %s%-*s%s %s%-*s%s' "$dim" "$reset" "$cyan" "$name_width" "$name" "$reset" "$dim" "$description_width" "$description" "$reset"
            set position (math "$position + 1")
            if test (math "$position % $columns") -eq 0
                printf '\n'
            else
                printf '   '
            end
        end
        if test (math "$position % $columns") -ne 0
            printf '\n'
        end
    end
    printf '\n  %s%s%s\n\n' "$dim" "$rule" "$reset"
end

# -------- l --------
function l -d "categorized ls"
    set -e folders zip audio video images text lua other

    for item in *
        if test -d $item
            set folders $folders " $item/"
        else if test -f $item
            switch $item
                case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                    set zip $zip " $item"
                case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                    set audio $audio " $item"
                case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                    set video $video " $item"
                case "*.txt" "*.md" "*.rst" "*.log"
                    set text $text " $item"
                case "*.lua"
                    set lua $lua " $item"
                case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                    set images $images " $item"
                case "*"
                    set other $other " $item"
            end
        end
    end

    _section brblue  " folders ($(count $folders))" $folders
    _section yellow  " zip ($(count $zip))"         $zip
    _section magenta " audio ($(count $audio))"     $audio
    _section magenta " video ($(count $video))"     $video
    _section yellow  " images ($(count $images))"   $images
    _section brgreen " text ($(count $text))"       $text
    _section cyan    " lua ($(count $lua))"         $lua
    _section white   " other ($(count $other))"     $other
end

function _section
    set -l color $argv[1]
    set -l title $argv[2]
    set -e argv[1]
    set -e argv[1]
    set -l items $argv

    if test (count $items) -eq 0
        return
    end

    set_color $color
    echo "$title"
    _grid $items
    set_color normal
    echo
end

function _grid
    set -l items $argv
    set -l i 1
    set -l c (count $items)

    while test $i -le $c
        set -l a $items[$i]
        set -l next (math $i + 1)

        if test $next -le $c
            set -l b $items[$next]
            if test (string length $a) -gt 42; or test (string length $b) -gt 42
                echo "  $a"
                echo "  $b"
            else
                printf "  %-42s │ %s\n" $a $b
            end
        else
            echo "  $a"
        end

        set i (math $i + 2)
    end
end

# -------- word --------
function word -d "word search"
    set -e code markup text other

    set -l pattern
    if test (count $argv) -ge 1
        set pattern (string join ' ' $argv)
    else
        echo "Usage: word <pattern>"
        echo "Or:    word (then type pattern freely)"
        read -P "pattern: " -l pattern
        if test -z "$pattern"
            return 1
        end
    end
    set -l base "$HOME"

    if not test -d "$base"
        echo "Directory not found: $base"
        return 1
    end

    set -l N (set_color normal)
    set -l T (printf '\t')
    set -l colors cba6f7 f5c2e7 fab387 f9e2af a6e3a1 89b4fa 89dceb

    set -l skip .git/ .cache/ node_modules/ .venv/ venv/ __pycache__/ .cargo/ .rustup/ .var/ mozilla/ BraveSoftware/ .local/ .npm/ .ssh/ .wine/ .android/ BACKUP/

    set -l matches
    if command -v rg >/dev/null 2>&1
        set -l globs
        for dir in $skip
            set globs $globs -g "!$dir"
        end
        set matches (rg -ni --no-heading $globs -- "$pattern" "$base" 2>/dev/null)
    else
        set matches (grep -rni "$pattern" "$base" 2>/dev/null | string match -v -r '/\.(git|cache|npm|ssh|wine|android|local|cargo|rustup|var)/|/node_modules/|/\.venv/|/venv/|/__pycache__/|/mozilla/|/BraveSoftware/|/BACKUP/')
    end

    if test -z "$matches"
        return
    end

    for line in $matches
        set -l parts (string split -m 2 -- ':' "$line")
        set -l filepath $parts[1]
        set -l lineno $parts[2]
        set -l content $parts[3]

        set -l dir (dirname "$filepath")
        set -l name (basename "$filepath")

        switch $filepath
            case '*.lua' '*.py' '*.sh' '*.bash' '*.zsh' '*.fish' '*.js' '*.ts' '*.jsx' '*.tsx' '*.go' '*.rs' '*.c' '*.h' '*.cpp' '*.hpp' '*.java' '*.kts' '*.swift' '*.rb' '*.php' '*.pl' '*.r' '*.m' '*.mm'
                set code $code "$dir$T$T$name:$lineno$T$content"
            case '*.html' '*.css' '*.scss' '*.less' '*.xml' '*.json' '*.yaml' '*.yml' '*.toml' '*.md' '*.rst' '*.tex'
                set markup $markup "$dir$T$T$name:$lineno$T$content"
            case '*.conf' '*.cfg' '*.ini' '*.txt' '*.log' '*.env' '*.gitignore' '*.editorconfig'
                set text $text "$dir$T$T$name:$lineno$T$content"
            case '*'
                set other $other "$dir$T$T$name:$lineno$T$content"
        end
    end

    set -l ci 0
    for var in code markup text other
        if test (count $$var) -eq 0
            continue
        end
        set -l first_parts (string split $T -- $$var[1])
        echo "$first_parts[2] $var ("(count $$var)")"
        set -l prev_dir ""
        for entry in $$var
            set -l p (string split $T -- $entry)
            if test "$p[1]" != "$prev_dir"
                set ci (math $ci + 1)
                set -l ci_mod (math $ci % 7 + 1)
                set -l c (set_color $colors[$ci_mod])
                echo ""
                echo "$c━━━ $p[1]/ ━━━$N"
                set prev_dir $p[1]
            end
            echo "  $p[2] $p[3] · $p[4]"
        end
        echo ""
    end
end

# -------- search --------
function search -d "find files"
    set -e zip audio video images text lua other

    if test (count $argv) -eq 0
        echo "Usage: search <pattern> [path]"
        return 1
    end

    set -l pattern $argv[1]
    set -l base "$HOME"

    if test (count $argv) -ge 2 -a -n "$argv[2]"
        set base $argv[2]
    end

    if not test -d "$base"
        echo "Directory not found: $base"
        return 1
    end

    set -l N (set_color normal)
    set -l T (printf '\t')
    set -l colors cba6f7 f5c2e7 fab387 f9e2af a6e3a1 89b4fa 89dceb

    for file in (find "$base" -maxdepth 5 -iname "*$pattern*" -type f -not -path "*/.local/*" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/.cache/*" -not -path "*/.npm/*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/__pycache__/*" -not -path "*/.cargo/*" -not -path "*/.rustup/*" -not -path "*/.var/*" -not -path "*/.config/chrome/*" -not -path "*mozilla*" -not -path "*BraveSoftware*" -not -path "*/.ssh/*" -not -path "*/.wine/*" -not -path "*/.android/*" -not -path "*/BACKUP/*" -not -type l 2>/dev/null)
        set -l name (basename "$file")
        set -l mtime (date -r "$file" "+%d/%m · %H:%M:%S" 2>/dev/null)
        set -l dir (dirname "$file")
        set -l label "$dir"

        switch $file
            case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                set zip $zip "$label$T$T$name$T$mtime"
            case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                set audio $audio "$label$T$T$name$T$mtime"
            case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                set video $video "$label$T$T$name$T$mtime"
            case "*.txt" "*.md" "*.rst" "*.log"
                set text $text "$label$T$T$name$T$mtime"
            case "*.lua"
                set lua $lua "$label$T$T$name$T$mtime"
            case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                set images $images "$label$T$T$name$T$mtime"
            case "*"
                set other $other "$label$T$T$name$T$mtime"
        end
    end

    set -l ci 0
    for var in zip audio video images text lua other
        if test (count $$var) -eq 0
            continue
        end
        set -l icon (string split $T -- $$var[1])[2]
        echo "$icon $var ("(count $$var)")"
        set -l prev_label ""
        for entry in $$var
            set -l parts (string split $T -- $entry)
            if test "$parts[1]" != "$prev_label"
                set ci (math $ci + 1)
                set -l ci_mod (math $ci % 7 + 1)
                set -l c (set_color $colors[$ci_mod])
                echo ""
                echo "$c━━━ $parts[1]/ ━━━$N"
                set prev_label $parts[1]
            end
            echo "  $parts[2] $parts[3] · $parts[4]"
        end
        echo ""
    end
  end

  # -------- lf --------
  function lf -d "list files"
      set -l N (set_color normal)
      set -l P (set_color cba6f7)

      set -l target "."
      if test (count $argv) -ge 1
          set target $argv[1]
      end

      if not test -d "$target"
          echo "$P󰅙 not a directory$N"
          return 1
      end

      set -l files (command ls -1t "$target" 2>/dev/null)

      if test -z "$files"
          echo "$P󰉖 empty$N"
          return 0
      end

      for f in $files
          set -l full "$target/$f"
          if not test -f "$full"
              continue
          end

          set -l mdate (date -r "$full" "+%d/%m" 2>/dev/null)
          set -l mtime (date -r "$full" "+%H:%M:%S" 2>/dev/null)
          set -l lines (wc -l < "$full" 2>/dev/null | string trim)

          set -l c $P
          set -l icon ""
          switch $f
              case '*.lua'
                  set icon ""
                  set c (set_color cba6f7)
              case '*.sh' '*.bash' '*.zsh' '*.fish'
                  set icon ""
                  set c (set_color a6e3a1)
              case '*.conf' '*.cfg' '*.ini'
                  set icon ""
                  set c (set_color fab387)
              case '*.png' '*.jpg' '*.jpeg' '*.gif' '*.svg' '*.webp'
                  set icon ""
                  set c (set_color f9e2af)
              case '*.mp3' '*.wav' '*.flac' '*.ogg' '*.m4a'
                  set icon ""
                  set c (set_color f5c2e7)
              case '*.mp4' '*.mkv' '*.avi' '*.mov' '*.webm'
                  set icon ""
                  set c (set_color 89dceb)
              case '*.zip' '*.tar' '*.tar.gz' '*.tar.xz' '*.7z' '*.rar'
                  set icon ""
                  set c (set_color f38ba8)
              case '*.txt' '*.md' '*.rst'
                  set icon ""
                  set c (set_color a6adc8)
              case '*.json' '*.yaml' '*.yml' '*.toml'
                  set icon ""
                  set c (set_color 89b4fa)
              case '*.py'
                  set icon ""
                  set c (set_color 89b4fa)
              case '*.html' '*.css' '*.js' '*.ts' '*.jsx' '*.tsx'
                  set icon ""
                  set c (set_color fab387)
          end

          printf "%s %s:%s · %s  · %s\n" \
              "$c$icon$N" \
              "$c$f$N" \
              "$c$lines$N" \
              "$c$mdate$N" \
              "$c$mtime$N"
      end
    end

    # -------- playing --------
    function playing -d "now playing"
        if not command -q playerctl
            echo "playerctl not installed"
            return 1
        end

        clear
        tput civis

        set -l cover /tmp/nowplaying_cover.jpg
        set -l P (set_color cba6f7)
        set -l G (set_color a6e3a1)
        set -l B (set_color 89b4fa)
        set -l M (set_color brmagenta)
        set -l D (set_color brblack)
        set -l N (set_color normal)

        while true
            set -l artist (playerctl metadata xesam:artist 2>/dev/null)
            set -l album  (playerctl metadata xesam:album 2>/dev/null)
            set -l title  (playerctl metadata xesam:title 2>/dev/null)

            set -l length_us (playerctl metadata mpris:length 2>/dev/null)
            set -l pos_sec (playerctl position 2>/dev/null)

            if test -z "$pos_sec"
                set pos_sec 0
            end

            set -l total_sec 0
            if test -n "$length_us"
                set total_sec (math "$length_us / 1000000")
            end

            set -l percent 0
            if test $total_sec -gt 0
                set percent (math "$pos_sec / $total_sec")
            end

            set -l width 30
            set -l pos (math -s0 "$percent * $width")
            set -l bar ""
            for i in (seq 0 (math "$width - 1"))
                if test $i -eq $pos
                    set bar "$bar$P●$N"
                else
                    set bar "$bar "
                end
            end

            set -l url (playerctl metadata xesam:url 2>/dev/null)
            set -l media_path (string replace "file://" "" -- $url)
            set media_path (string unescape --style=url $media_path)

            if test -f "$media_path"
                ffmpeg -loglevel quiet -y -i "$media_path" -an -vcodec copy "$cover"
            end

            tput cup 0 0
            tput el
            echo "$B󰝚 $artist$N"
            tput el
            echo "$P󰏤 $album$N"
            tput el
            echo "$G󰎆 $title$N"
            tput el

            set -l cur_m (math -s0 "$pos_sec / 60")
            set -l cur_s (math -s0 "$pos_sec % 60")

            set -l tot_m 0
            set -l tot_s 0
            if test $total_sec -gt 0
                set tot_m (math -s0 "$total_sec / 60")
                set tot_s (math -s0 "$total_sec % 60")
            end

            tput cup 4 0
            tput el
            echo -ns "$M󰏫 "(printf "%02d:%02d / %02d:%02d" $cur_m $cur_s $tot_m $tot_s)"$N"

            tput cup 5 0

            if test -f "$cover"
                kitty +kitten icat --clear >/dev/null 2>&1
                kitty +kitten icat --place 30x15@0x5 "$cover"
            else
                kitty +kitten icat --clear >/dev/null 2>&1
            end

            tput cup 19 0
            tput el
            echo "$bar"

            sleep 0.4
        end
    end

# -------- mem --------
function mem --description '󰍛'
    set -l interactive 0
    set -l cyan ''
    set -l pink ''
    set -l dim ''
    set -l green ''
    set -l yellow ''
    set -l reset ''
    set -l width 76

    argparse 1/once h/help -- $argv; or return 2
    if set -q _flag_help
        printf 'mem — memory monitor\n\nUsage: mem [--once]\n\n  -1, --once  Print a snapshot without opening the picker\n  -h, --help  Show this help\n\nDashboard: type to filter, Ctrl-R refreshes, Ctrl-X terminates\nimmediately, Esc exits. RSS is grouped by application.\n'
        return 0
    end
    if set -q argv[1]
        printf 'mem: unknown argument: %s\n' "$argv[1]" >&2
        return 2
    end
    if set -q COLUMNS; and string match -qr '^[0-9]+$' -- "$COLUMNS"
        set width (math "min(94, max(36, $COLUMNS - 4))")
    end
    if isatty stdout; and not set -q NO_COLOR
        set cyan (set_color --bold 00e5ff)
        set pink (set_color --bold ff4fbd)
        set dim (set_color 7b849c)
        set green (set_color 78ffb7)
        set yellow (set_color ffd166)
        set reset (set_color normal)
    end
    if isatty stdin; and isatty stdout; and command -q fzf; and not set -q _flag_once
        set interactive 1
    end

    while true
        if test "$interactive" -eq 1
            printf '\e[H\e[2J'
        end
        command awk -v cyan="$cyan" -v pink="$pink" -v dim="$dim" \
            -v green="$green" -v yellow="$yellow" -v reset="$reset" -v width="$width" '
            function line(symbol, count, color, i) {
                printf "  %s", color
                for (i = 0; i < count; i++) printf "%s", symbol
                printf "%s\n", reset
            }
            function meter(label, used, total, color, ratio, filled, i, size) {
                ratio = total > 0 ? used / total : 0
                size = width - 14
                filled = int(ratio * size + 0.5)
                printf "  %s%-5s%s %s%5.1f%%%s\n", color, label, reset, color, ratio * 100, reset
                printf "  %s", color
                for (i = 0; i < size; i++) {
                    if (i == filled) printf "%s", dim
                    printf "%s", i < filled ? "━" : "─"
                }
                printf "%s\n", reset
                printf "  %s%.2f / %.2f GiB%s\n\n", dim, used / 1048576, total / 1048576, reset
            }
            /^MemTotal:/ { total = $2 }
            /^MemAvailable:/ { available = $2 }
            /^Cached:/ { cache = $2 }
            /^SReclaimable:/ { reclaimable = $2 }
            /^Shmem:/ { shared = $2 }
            /^SwapTotal:/ { swap = $2 }
            /^SwapFree:/ { swapfree = $2 }
            END {
                if (total <= 0) exit 1
                used = total - available
                ratio = used / total
                status = ratio >= 0.9 ? "‼" : ratio >= 0.75 ? "!" : "✓"
                color = ratio >= 0.9 ? pink : ratio >= 0.75 ? yellow : green
                printf "\n  %s╱╱ 󰍛%s\n", cyan, reset
                line("─", width, dim)
                printf "  %s● %s%s  %s%s%s\n\n", color, status, reset, dim, strftime("%H:%M:%S"), reset
                meter("RAM", used, total, cyan)
                if (swap > 0) meter("SWAP", swap - swapfree, swap, pink)
                else printf "  %sSWAP  disabled%s\n\n", dim, reset
                printf "  %s◇%s  %.2f GiB", green, reset, available / 1048576
                if (width < 52) printf "\n"
                else printf "    "
                printf "  %s▧%s  %.2f GiB\n", dim, reset, (cache + reclaimable - shared) / 1048576
                line("─", width, dim)
                printf "  %s◈ RSS%s\n", pink, reset
                printf "  %sShared RSS may be counted twice.%s\n\n", dim, reset
            }
        ' /proc/meminfo
        or return 1

        set -l owner (command id -u)
        set -l name_width (math "min(30, max(8, $width - 30))")
        set -l rows (command ps -u "$owner" -o pid=,rss=,comm= | command awk -v self="$fish_pid" '
            $1 != self && $2 > 0 {
                pid = $1
                rss = $2
                sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "")
                memory[$0] += rss
                count[$0]++
                pids[$0] = pids[$0] ? pids[$0] "," pid : pid
            }
            END {
                for (name in memory)
                    printf "%d\t%s\t%d\t%s\n", memory[name], pids[name], count[name], name
            }
        ' | command sort -k1,1nr | command awk -F '\t' -v cyan="$cyan" -v pink="$pink" \
            -v dim="$dim" -v reset="$reset" -v width="$name_width" '
            NR == 1 { peak = $1 }
            {
                size = $1 >= 1048576 ? sprintf("%.2f GiB", $1 / 1048576) : sprintf("%.0f MiB", $1 / 1024)
                name = length($4) > width ? substr($4, 1, width - 1) "~" : $4
                printf "%s\t%s\t%s%-*s%s %s%9s%s %s%3dx%s ", $1, $2, cyan, width, name, reset, pink, size, reset, dim, $3, reset
                filled = peak > 0 ? int($1 / peak * 8 + 0.5) : 0
                printf "%s", cyan
                for (i = 0; i < 8; i++) {
                    if (i == filled) printf "%s", dim
                    printf "%s", i < filled ? "▰" : "▱"
                }
                printf "%s\n", reset
            }
        ')

        if test "$interactive" -eq 0
            if set -q rows[1]
                printf '%s\n' $rows | command awk -F '\t' 'NR <= 12 { print "  " $3 }'
            else
                printf '  No processes available.\n'
            end
            printf '\n  %sRSS · resident memory | x · grouped processes%s\n\n' "$dim" "$reset"
            return 0
        end

        set -l selection (printf '%s\n' $rows | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
            --ansi --height=55% --layout=reverse --border=sharp \
            --border-label=' ◈ ' --prompt='⌕ ' --pointer='▶' \
            --header='↑↓ · ⌕ · ^R ⟳ · ^X × · Esc ⏻' \
            --delimiter='\t' --with-nth=3.. --no-multi --no-sort \
            --expect=ctrl-r,ctrl-x --bind=enter:ignore \
            --color='bg+:#202039,fg+:#e6faff,border:#ff4fbd,label:#00e5ff,pointer:#00e5ff,prompt:#ff4fbd,hl:#ffd166,hl+:#ffd166,info:#7b849c,header:#7b849c')
        set -l picker_status $status
        if test "$picker_status" -eq 1; or test "$picker_status" -eq 130
            return 0
        else if test "$picker_status" -ne 0
            return "$picker_status"
        end
        if test "$selection[1]" = ctrl-r
            continue
        end
        if test "$selection[1]" != ctrl-x; or not set -q selection[2]
            continue
        end
        set -l fields (string split \t -- "$selection[-1]")
        if not string match -qr '^[0-9]+(,[0-9]+)*$' -- "$fields[2]"
            return 1
        end
        set -l pids (string split , -- "$fields[2]")
        if not kill -TERM -- $pids
            printf '  Could not terminate all processes.\n' >&2
            set -l answer ''
            read -l -P '  Press Enter to continue… ' answer; or return 0
        end
    end
end
