#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Yuugentsi/dotfile.git"
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles"

command -v git >/dev/null 2>&1 || pkg install git -y || true

if [ -n "${PREFIX:-}" ]; then
    echo "deb https://grimler.se/termux/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
    pkg update -y 2>/dev/null || true
    pkg upgrade -y 2>/dev/null || true

    for pkg in gallery-dl python-yt-dlp python ffmpeg aria2 fish openssh termux-api unzip zip wget curl fzf tree ripgrep fd jq; do
        pkg install "$pkg" -y 2>/dev/null || true
    done
fi

rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR"

cd "$HOME"

rm -rf "${HOME}/.config"
mkdir -p "${HOME}/.config"

for dir in "$TEMP_DIR"/.config/*/; do
    name="$(basename "$dir")"
    case "$name" in
        hypr|kitty|mpv|rofi|swayimg|swaync|waybar|zathura|zed)
            continue ;;
    esac
    cp -r "${dir}" "${HOME}/.config/${name}"
done

command -v hyprctl >/dev/null 2>&1 && find "${HOME}/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

if command -v fish >/dev/null 2>&1; then
    chsh -s fish 2>/dev/null || echo fish | chsh 2>/dev/null || true
fi

touch "$HOME/.hushlogin"
rm -f "$PREFIX/etc/motd" 2>/dev/null || true
rm -rf "$TEMP_DIR"
cd /storage/emulated/0 2>/dev/null || cd "$HOME"
