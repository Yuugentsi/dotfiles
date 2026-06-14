#!/bin/bash
# bind_exec("F1", "bash $HOME/.config/hypr/scripts/play.sh")

SOCKET="$HOME/.config/mpv-socket"
MUSIC_DIR="$HOME/0/music"
PLAYED_FILE="/tmp/play.txt"

tmp_all=$(mktemp /tmp/play-all-XXXX.txt)
tmp_unplayed=$(mktemp /tmp/play-unplayed-XXXX.txt)

find "$MUSIC_DIR" -type f \( -name "*.mp3" -o -name "*.flac" \) 2>/dev/null | sort > "$tmp_all"
touch "$PLAYED_FILE"

grep -Fxv -f "$PLAYED_FILE" "$tmp_all" > "$tmp_unplayed"

if [ ! -s "$tmp_unplayed" ]; then
    : > "$PLAYED_FILE"
    cp "$tmp_all" "$tmp_unplayed"
fi

file=$(shuf -n1 "$tmp_unplayed")
printf '%s\n' "$file" >> "$PLAYED_FILE"

rm -f "$tmp_all" "$tmp_unplayed"

[ -z "$file" ] && exit 0

if pgrep -x mpv >/dev/null; then
    { echo "loadfile \"$file\" insert-at"; echo "playlist-next"; echo "playlist-move 0 999"; } | socat - "$SOCKET" 2>/dev/null
else
    mpv --no-video --no-resume-playback "$file" >/dev/null 2>&1 &
fi
