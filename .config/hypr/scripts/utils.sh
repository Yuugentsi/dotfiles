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
        if pgrep -x spotify >/dev/null 2>&1; then
            playerctl -p spotify next 2>/dev/null
            exit 0
        fi

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

    # ----- zeditor (SUPER + Z) -----
    # bind_exec("SUPER + Z", "$HOME/.config/hypr/scripts/utils.sh z")
    z)
        CLASS="dev.zed.Zed"
        EXEC="zeditor"
        PGEXEC="zed-editor"
        SPECIAL="zed"

        if ! pgrep -x "$PGEXEC" > /dev/null 2>&1; then
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
    # ----- notes (ALT + N) -----
    # bind_exec("ALT + N", "$HOME/.config/hypr/scripts/utils.sh note")
    note)
        notes="$HOME/0/documents/txt/notes.txt"
        mkdir -p "$(dirname "$notes")"

        content=$(wl-paste 2>/dev/null)
        if [ -z "$content" ]; then
            hyprctl notify -1 2000 "rgb(cba6f7)" "󰅙 clipboard empty"
            exit 1
        fi

        last=$(tail -n 2 "$notes" 2>/dev/null | head -1)
        if [ "$last" = "$content" ]; then
            hyprctl notify -1 2000 "rgb(fab387)" "󰅜 duplicate"
            exit 0
        fi

        printf "%s\n-------------\n" "$content" >> "$notes"
        hyprctl notify -1 2000 "rgb(a6e3a1)" "󰄬 note saved"
        ;;
    *)
        echo "Usage: $0 {toggle|play|z|note}"
        exit 1
        ;;
esac
