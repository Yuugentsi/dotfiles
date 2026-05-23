#!/bin/bash
# exec("$HOME/.config/hypr/scripts/wallpaper.sh daemon")
CACHE_DIR="$HOME/.cache/scripts/wallpapers"
WALLPAPER_CACHE="$CACHE_DIR/wallpaper"
HYPRPAPER_CONFIG="$CACHE_DIR/hyprpaper.conf"
WALLPAPER_DIR="$HOME/media/pictures/wallpapers"

run_wallpaper_daemon() {
    mkdir -p "$CACHE_DIR"

    local img
    img="$(tr -d '\r' < "$WALLPAPER_CACHE" 2>/dev/null | head -n 1)"

    if [[ ! -f "$img" ]]; then
        img="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1)"
    fi

    [[ -n "$img" && -f "$img" ]] || return 0

    printf "%s\n" "$img" > "$WALLPAPER_CACHE"

    cat > "$HYPRPAPER_CONFIG" <<EOF
splash = false
ipc = true

wallpaper {
    monitor =
    path = $img
    fit_mode = cover
}
EOF

    pkill -x hyprpaper 2>/dev/null
    sleep 0.2
    exec hyprpaper -c "$HYPRPAPER_CONFIG"
}

run_wallpaper_blur() {
    local blur_dir="$WALLPAPER_DIR/blur"

    if ! command -v magick &>/dev/null; then
        notify-send -e -t 2000 "󰋔  Blur" "ImageMagick not installed"
        return 1
    fi

    mkdir -p "$blur_dir"

    for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png}; do
        [[ -f "$img" ]] || continue
        local out="$blur_dir/$(basename "${img%.*}")-blur.${img##*.}"
        [[ -f "$out" ]] && continue
        magick "$img" -blur 0x12 "$out"
        printf "✓ %s\n" "$(basename "$out")"
    done

    local count
    count=$(ls "$blur_dir"/*-blur.* 2>/dev/null | wc -l)
    notify-send -e -t 2000 "󰋔  Blur" "Done: $count wallpapers"
}

case "${1:-daemon}" in
    daemon)
        run_wallpaper_daemon
        ;;
    blur)
        run_wallpaper_blur
        ;;
    *)
        printf "usage: %s {daemon|blur}\n" "$0" >&2
        exit 1
        ;;
esac
