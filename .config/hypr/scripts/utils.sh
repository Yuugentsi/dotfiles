#!/bin/bash

case "${1:-}" in
    # ----- mpv (ALT + W) -----
    # bind_exec("ALT + W", "$HOME/.config/hypr/scripts/utils.sh mpv")
    mpv)
        SPECIAL="mpv"
        CLASS="mpv"

        EXISTING_SPECIAL=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$SPECIAL\") | .address" | head -1)

        if [ -n "$EXISTING_SPECIAL" ]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
            exit 0
        fi

        DATA=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | \"\\(.address) \\(.workspace.name)\"" | head -1)

        if [ -n "$DATA" ]; then
            ADDR="${DATA%% *}"
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
            exit 0
        fi

        mpv --force-window --idle --fs >/dev/null 2>&1 &
        ;;

    # ----- kitty (ALT + Q) -----
    # bind_exec("ALT + Q", "$HOME/.config/hypr/scripts/utils.sh kitty")
    kitty)
        SPECIAL="kitty"
        CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.name')

        MPV_SPECIAL=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:mpv") | .address' | head -1)
        [ -n "$MPV_SPECIAL" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = '${CURRENT_WS}', window = 'address:${MPV_SPECIAL}' })"

        EXISTING=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty-float") | .address' | head -1)
        if [ -n "$EXISTING" ]; then
            IN_SPECIAL=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$EXISTING\" and .workspace.name == \"special:$SPECIAL\") | .address")
            if [ -n "$IN_SPECIAL" ]; then
                hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
            else
                hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${EXISTING}' })"
            fi
            exit 0
        fi
        kitty --class kitty-float &
        PID=$!
        for i in $(seq 1 20); do
            ADDR=$(hyprctl clients -j | jq -r ".[] | select(.pid == $PID) | .address" | head -1)
            [ -n "$ADDR" ] && break
            sleep 0.1
        done
        [ -n "$ADDR" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
        ;;

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

    # ----- workspace notify -----
    # exec("bash $HOME/.config/hypr/scripts/utils.sh workspace")
    workspace)
        STATE=true
        SHOW_CLASS=true
        ICONS=("" ➀ ➁ ➂ ➃ ➄ ➅ ➆ ➇ ➈ ➉)
        socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
            case "$line" in
                workspace\>\>*)
                    $STATE || continue
                    ws="${line#workspace>>}"
                    icon="●"
                    [[ "$ws" =~ ^[0-9]+$ ]] && icon="${ICONS[$ws]}"
                    msg="$icon"
                    if [ "$SHOW_CLASS" = "true" ]; then
                        sleep 0.1
                        class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
                        class=${class,,}
                        case "$class" in
                            org.telegram.desktop) class="telegram" ;;
                            dev.zed.zed) class="zed" ;;
                            org.pwmt.zathura|zathura) class="zathura" ;;
                            brave-browser) class="brave" ;;
                            code-oss) class="code" ;;
                        esac
                        [ -n "$class" ] && msg="$icon  $class"
                    fi
                    hyprctl dismissnotify 1 2>/dev/null
                    hyprctl notify 1 2000 "rgb(a6e3a1)" "fontsize:14 $msg" 2>/dev/null
                    ;;
            esac
        done
        ;;

    *)
        echo "Usage: $0 {mpv|kitty|toggle|workspace}"
        exit 1
        ;;
esac
