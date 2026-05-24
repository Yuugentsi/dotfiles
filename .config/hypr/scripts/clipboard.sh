#!/bin/bash
# bind_exec("SUPER + V", "$HOME/.config/hypr/scripts/clipboard.sh")
# bind_exec("ALT + V",   "$HOME/.config/hypr/scripts/clipboard.sh images")
#
# exec("$HOME/.config/hypr/scripts/clipboard.sh daemon")
HISTORY_LIMIT="${CLIPBOARD_HISTORY_LIMIT:-80}"
PINNED_FILE="$HOME/.cache/scripts/clipboard/pinned"
RESUME_IMAGE="${CLIPBOARD_RESUME_IMAGE:-true}"

run_clipboard_manager() {
    pkill -x rofi 2>/dev/null
    sleep 0.1

    rofi_menu() {
        rofi -dmenu -i \
            -sep $'\x1f' \
            -theme-str 'window { width: 46%; }' \
            -theme-str 'mainbox { padding: 0px; spacing: 0px; }' \
            -theme-str 'inputbar { padding: 8px; }' \
            -theme-str 'listview { columns: 1; lines: 12; fixed-height: true; dynamic: false; spacing: 0px; scrollbar: true; }' \
            -theme-str 'element { padding: 4px 8px; height: 36px; }' \
            -theme-str 'element-text { expand: true; }' \
            -p "$1"
    }

    local formatted_list=""
    local count=0

    while IFS=$'\t' read -r id content; do
        [[ -z "$id" ]] && continue
        [[ "$content" =~ "[[ binary data" ]] && continue
        local clean_content
        clean_content=$(printf '%s\n' "$content" | head -n 2 | cut -c 1-100)
        formatted_list+="$id   $clean_content"$'\x1f'
        ((count++))
    done <<< "$(cliphist list 2>/dev/null | grep -av $'\t<meta' | head -n "$HISTORY_LIMIT")"

    if [[ $count -eq 0 ]]; then
        notify-send -e -t 2000 "󰅍  Clipboard" "History is empty"
        exit 0
    fi

    local wipe_option="Clear History ($count)"

    local pinned_items=""
    mkdir -p "$(dirname "$PINNED_FILE")"
    if [[ -f "$PINNED_FILE" ]]; then
        while IFS= read -r pinned_line; do
            [[ -z "$pinned_line" ]] && continue
            pinned_items+="📌   $pinned_line"$'\x1f'
        done < "$PINNED_FILE"
    fi

    local content
    content="$wipe_option"$'\x1f'"$pinned_items$formatted_list"

    local selected
    selected=$(printf '%s' "$content" | rofi_menu "󰅍 Clipboard")

    [[ -z "$selected" ]] && exit 0

    if [[ "$selected" == "$wipe_option"* ]]; then
        rm -f "$HOME/.cache/cliphist/db"
        notify-send -e -t 2000 "󰅍  Clipboard" "History cleared"
    elif [[ "$selected" =~ ^pin[[:space:]]+ ]]; then
        local pinned_text
        pinned_text=$(echo "$selected" | sed -E 's/^pin[[:space:]]+//')
        printf '%s\n' "$pinned_text" >> "$PINNED_FILE"
        printf '%s' "$pinned_text" | wl-copy
        notify-send -e -t 2000 "󰅍  Clipboard" "Pinned"
    elif [[ "$selected" == "📌 "* ]]; then
        local pinned_text
        pinned_text=$(echo "$selected" | sed -E 's/^📌[[:space:]]+//')
        [[ -n "$pinned_text" ]] && printf '%s' "$pinned_text" | wl-copy
    elif [[ "$selected" =~ ^unpin[[:space:]]+ ]]; then
        local unpin_text
        unpin_text=$(echo "$selected" | sed -E 's/^unpin[[:space:]]+//')
        if [[ -f "$PINNED_FILE" ]]; then
            grep -vFx "$unpin_text" "$PINNED_FILE" > "${PINNED_FILE}.tmp" 2>/dev/null
            mv "${PINNED_FILE}.tmp" "$PINNED_FILE"
        fi
        notify-send -e -t 2000 "󰅍  Clipboard" "Unpinned"
    elif [[ "$selected" =~ ^(delet|delete)[[:space:]] ]]; then
        local pattern
        pattern=$(echo "$selected" | sed -E 's/^(delet|delete)[[:space:]]+//')
        cliphist list 2>/dev/null | grep -av $'\t<meta' | grep -iF -- "$pattern" | cliphist delete
    elif [[ "$selected" == "del imagens" ]]; then
        local img_count
        img_count=$(cliphist list 2>/dev/null | grep -c "binary data")
        cliphist list 2>/dev/null | grep "binary data" | cliphist delete
        notify-send -e -t 2000 "󰅍  Clipboard" "$img_count images deleted"
    else
        local id
        id=$(echo "$selected" | grep -oE '^[0-9]+')
        if [[ -n "$id" ]]; then
            cliphist decode "$id" | wl-copy
            notify-send -e -t 2000 "󰅍  Clipboard" "Copied"
        fi
    fi
}

run_clipboard_daemon() {
    pkill -f "wl-paste.*watch" 2>/dev/null
    sleep 0.2
    wl-paste --watch bash -c '
        tmp=$(mktemp)
        cat > "$tmp"
        mime=$(file --mime-type -b "$tmp" 2>/dev/null)
        if [[ "$mime" != image/* ]]; then
            cliphist store < "$tmp"
        fi
        rm -f "$tmp"
    ' >/dev/null 2>&1 &
    for mime in image/png image/jpeg image/gif image/webp image/bmp; do
        wl-paste --type "$mime" --watch cliphist store >/dev/null 2>&1 &
    done
}

run_clipboard_images() {
    local image_ids=()
    while IFS=$'\t' read -r id content; do
        [[ -z "$id" ]] && continue
        [[ "$content" =~ "[[ binary data" ]] || continue
        image_ids+=("$id")
    done <<< "$(cliphist list 2>/dev/null | grep -av $'\t<meta' | head -n 50)"

    if [[ ${#image_ids[@]} -eq 0 ]]; then
        notify-send -e -t 2000 "󰅍  Clipboard" "No images in history"
        exit 0
    fi

    local tmp_dir
    tmp_dir="$HOME/.cache/scripts/clipboard/images"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    local id_map
    id_map=$(mktemp)

    local last_id
    last_id=$(cat "$HOME/.cache/scripts/clipboard/last_image" 2>/dev/null)
    local start_path=""

    local i=0
    for img_id in "${image_ids[@]}"; do
        local f="$tmp_dir/${img_id}"
        cliphist decode "$img_id" > "$f"
        local mime
        mime=$(file --mime-type -b "$f" 2>/dev/null)
        case "$mime" in
            image/jpeg) mv "$f" "${f}.jpg" && f="${f}.jpg" ;;
            image/png)  mv "$f" "${f}.png"  && f="${f}.png" ;;
            image/gif)  mv "$f" "${f}.gif"  && f="${f}.gif" ;;
            image/webp) mv "$f" "${f}.webp" && f="${f}.webp" ;;
        esac
        printf '%s\t%s\n' "$f" "$img_id" >> "$id_map"
        [[ "$img_id" == "$last_id" ]] && start_path="$f"
        ((i++))
    done

    local files
    files=$(find "$tmp_dir" -type f | sort -V | tr '\n' ' ')
    if [[ -n "$files" ]]; then
        if [[ "$RESUME_IMAGE" == "true" && -n "$start_path" && -f "$start_path" ]]; then
            swayimg "$start_path" $(echo "$files" | tr ' ' '\n' | grep -vF "$start_path" | tr '\n' ' ')
        else
            swayimg $files
        fi
        while IFS=$'\t' read -r fpath fid; do
            if [[ ! -f "$fpath" ]]; then
                printf '%s\t%s\n' "$fid" "$(cliphist list 2>/dev/null | grep "^$fid" | cut -f2- | head -c 40)" | cliphist delete 2>/dev/null
            fi
        done < "$id_map"
    fi
    rm -rf "$tmp_dir" "$id_map" 2>/dev/null
}

case "${1:-}" in
    daemon)
        run_clipboard_daemon
        ;;
    images)
        run_clipboard_images
        ;;
    *)
        run_clipboard_manager
        ;;
esac
