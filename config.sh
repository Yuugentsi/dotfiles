#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Yuugentsi/dotfile.git"
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles"

command -v git >/dev/null 2>&1 || pkg install git -y 2>/dev/null || true

pkg install gallery-dl yt-dlp python ffmpeg -y 2>/dev/null || true

rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR"

for dir in "$TEMP_DIR"/.config/*/; do
    name="$(basename "$dir")"
    rm -rf "${HOME}/.config/${name:?}"
    cp -r "$dir" "${HOME}/.config/"
done

command -v hyprctl >/dev/null 2>&1 && find "${HOME}/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
rm -rf "$TEMP_DIR"
