#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Yuugentsi/dotfile.git"
TEMP_DIR="/tmp/dotfiles"

rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR"

cd "$HOME"

for dir in "$TEMP_DIR"/.config/*/; do
    name="$(basename "$dir")"
    rm -rf "${HOME}/.config/${name:?}"
    cp -r "$dir" "${HOME}/.config/${name}"
done

# ─────────── thunar bookmarks ───────────
echo "󰉏 bookmarks"
mkdir -p "${HOME}/.config/gtk-3.0"
cat > "${HOME}/.config/gtk-3.0/bookmarks" <<EOF
file://${MEDIA}
file://${MEDIA}/pictures
file://${MEDIA}/videos
file://${MEDIA}/documents
file://${MEDIA}/music
file://${HOME}/Downloads
EOF

command -v hyprctl >/dev/null 2>&1 && find "${HOME}/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
rm -rf "$TEMP_DIR"
