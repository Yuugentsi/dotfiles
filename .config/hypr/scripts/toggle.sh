#!/bin/bash
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
