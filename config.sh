#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Yuugentsi/dotfile.git"
TEMP_DIR="/tmp/dotfiles"

rm -rf "$TEMP_DIR"
git clone "$REPO_URL" "$TEMP_DIR"

for dir in "$TEMP_DIR"/.config/*/; do
    name="$(basename "$dir")"
    rm -rf "${HOME}/.config/${name:?}"
    cp -r "$dir" "${HOME}/.config/"
done

chmod +x "${HOME}/.config/hypr/scripts/"*.sh 2>/dev/null || true
rm -rf "$TEMP_DIR"
