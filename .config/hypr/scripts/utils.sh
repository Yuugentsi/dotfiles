#!/bin/bash

case "${1:-}" in
    # ----- telegram (ALT + T) -----
    # bind_exec("ALT + T", "$HOME/.config/hypr/scripts/utils.sh toggle")
    toggle)
        CLASS="org.telegram.desktop"
        EXEC="Telegram"
        SPECIAL="telegram"

        if ! pgrep -x "$EXEC" > /dev/null 2>&1; then
            "$EXEC" &
            exit 0
        fi

        DATA=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | \"\\(.address) \\(.workspace.name)\"" | head -1)

        if [ -z "$DATA" ]; then
            "$EXEC" &
            exit 0
        fi

        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [[ "$WS" == special* ]]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
        else
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
        fi
        ;;

    # ----- random music (F1) -----
    # bind_exec("F1", "$HOME/.config/hypr/scripts/utils.sh play")
    play)
        SOCKET="$HOME/.config/mpv-socket"
        MUSIC_DIR="$HOME/media/music"
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
        ;;

    *)
        echo "Usage: $0 {toggle|play}"
        exit 1
        ;;
esac
