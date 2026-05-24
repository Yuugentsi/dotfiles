#!/usr/bin/env bash
set -euo pipefail

sudo -v

REPO_URL="https://github.com/Yuugentsi/dotfile.git"

# ─────────── git ───────────
echo "󰊢 git"
sudo pacman -S --needed --noconfirm git

# ─────────── clone ───────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/fish" ] && [ -d "$SCRIPT_DIR/hypr" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
else
    rm -rf "/tmp/dotfiles"
    echo "󰊢 cloning..."
    git clone "$REPO_URL" "/tmp/dotfiles"
    DOTFILES_DIR="/tmp/dotfiles"
fi

# ─────────── packages ───────────
echo "󰮯 installing..."
sudo pacman -S --needed --noconfirm \
    brightnessctl   \
    cliphist        \
    firefox         \
    firefox-ublock-origin \
    firefox-dark-reader \
    fish            \
    fd              \
    gvfs            \
    hyprland        \
    hypridle        \
    hyprlock        \
    hyprpaper       \
    hyprshot        \
    hyprsunset      \
    imagemagick     \
    jq              \
    kitty           \
    mpv             \
    mpv-mpris       \
    playerctl       \
    nano            \
    rofi            \
    swayimg         \
    swaync          \
    thunar          \
    tree            \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    noto-fonts      \
    oxygen-cursors  \
    adw-gtk-theme   \
    breeze-icons    \
    noto-fonts-cjk  \
    noto-fonts-emoji \
    noto-fonts-extra \
    waybar          \
    wl-clipboard    \
    yt-dlp          \
    zathura         \
    zathura-cb      \
    ffmpegthumbnailer \
    tumbler         \
    qt6ct           \
    zed             \
    zip             \
    unzip           \
    libarchive       \
    xdg-desktop-portal-hyprland

# ─────────── spotx ───────────
echo "󰝚 spotx"
bash <(curl -sSL https://spotx-official.github.io/run.sh) || true

# ─────────── shell ───────────
echo "󰈺 shell → fish"
sudo chsh -s /usr/bin/fish "$USER"

# ─────────── dirs ───────────
echo "󰉋 media"
MEDIA="${HOME}/media"
for d in music video pictures documents; do
    [ -d "$MEDIA/$d" ] || mkdir -p "$MEDIA/$d"
done

# ─────────── config ───────────
TARGET_DIR="${HOME}/.config"
mkdir -p "$TARGET_DIR"

for dir in "$DOTFILES_DIR"/*/; do
    name="$(basename "$dir")"
    [ "$name" = ".git" ] && continue
    echo " 󰄬 ${name}"
    rm -rf "${TARGET_DIR:?}/${name}"
    cp -r "$dir" "${TARGET_DIR}/"
done

# ─────────── scripts ───────────
chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true

# ─────────── nodisplay ───────────
apps_nodisplay=(
    avahi-discover.desktop bssh.desktop bvnc.desktop
    xfce4-about.desktop qv4l2.desktop qvidcap.desktop
    xgps.desktop xgpsspeed.desktop org.freedesktop.Xwayland.desktop
    kitty-open.desktop thunar-bulk-rename.desktop thunar-settings.desktop
    org.gnupg.pinentry-qt5.desktop org.gnupg.pinentry-qt.desktop
    electron36.desktop electron37.desktop
    rofi.desktop rofi-theme-selector.desktop
)
for app in "${apps_nodisplay[@]}"; do
    file="/usr/share/applications/$app"
    if [ -f "$file" ] && ! grep -q '^NoDisplay=true$' "$file" 2>/dev/null; then
        echo "NoDisplay=true" | sudo tee -a "$file" >/dev/null
    fi
done

# ─────────── theme ───────────
echo "󰉋 theme → adw-gtk3-dark"
gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "breeze-dark" 2>/dev/null || true

# ─────────── yay ───────────
if ! command -v yay &>/dev/null; then
    echo "󰮯 yay"
    sudo pacman -S --needed --noconfirm base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    chown -R "$USER:$USER" /tmp/yay
    cd /tmp/yay
    sudo -u "$USER" makepkg -si --noconfirm
    cd /
    rm -rf /tmp/yay
fi

# ─────────── extractor ───────────
APP_ID="extract.desktop"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
SCRIPT_PATH="${BIN_DIR}/extract.sh"
DESKTOP_PATH="${APP_DIR}/${APP_ID}"

mkdir -p "${BIN_DIR}" "${APP_DIR}"

cat > "${SCRIPT_PATH}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

archive_path="${1:-}"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -t 1000 "$@"
  fi
}

fail() {
  notify "Extraction failed" "$1"
  exit 1
}

[ -n "${archive_path}" ] || fail "No archive was provided."
[ -f "${archive_path}" ] || fail "File does not exist: ${archive_path}"

if ! command -v bsdtar >/dev/null 2>&1; then
  fail "Install libarchive to use bsdtar."
fi

if ! command -v gio >/dev/null 2>&1; then
  fail "Install gio to move archives to Trash."
fi

archive_dir="$(dirname "${archive_path}")"
archive_name="$(basename "${archive_path}")"
base_name="${archive_name}"

while [[ "${base_name}" == *.tar.gz || "${base_name}" == *.tar.bz2 || "${base_name}" == *.tar.xz || "${base_name}" == *.tar.zst || "${base_name}" == *.tar.lz || "${base_name}" == *.tar.lzma || "${base_name}" == *.tar.Z ]]; do
  base_name="${base_name%.*}"
done

case "${base_name}" in
  *.tgz|*.tbz2|*.txz|*.tlz|*.tzst) base_name="${base_name%.*}" ;;
esac

case "${archive_name}" in
  *.cbz) exit 0 ;;
esac

base_name="${base_name%.zip}"
base_name="${base_name%.7z}"
base_name="${base_name%.rar}"
base_name="${base_name%.tar}"
base_name="${base_name%.gz}"
base_name="${base_name%.bz2}"
base_name="${base_name%.xz}"
base_name="${base_name%.zst}"
base_name="${base_name%.lz}"
base_name="${base_name%.lzma}"
base_name="${base_name%.Z}"

[ -n "${base_name}" ] || base_name="${archive_name}.extracted"

target_dir="${archive_dir}/${base_name}"
if [ -e "${target_dir}" ]; then
  suffix=2
  while [ -e "${target_dir}-${suffix}" ]; do
    suffix=$((suffix + 1))
  done
  target_dir="${target_dir}-${suffix}"
fi

mkdir -p "${target_dir}"

if ! bsdtar -xf "${archive_path}" -C "${target_dir}"; then
  rmdir "${target_dir}" 2>/dev/null || true
  fail "The archive may be corrupted or use an unsupported format."
fi

if ! gio trash "${archive_path}"; then
  fail "Extraction succeeded, but moving the archive to Trash failed."
fi

notify "Archive extracted" "$(basename "${target_dir}")"
EOF

chmod +x "${SCRIPT_PATH}"

cat > "${DESKTOP_PATH}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Extract Archive
Comment=Extract archive
Exec=${SCRIPT_PATH} %f
NoDisplay=true
Terminal=false
StartupNotify=false
MimeType=application/epub+zip;application/x-7z-compressed;application/x-7z-compressed-tar;application/x-ace;application/x-alz;application/x-arc;application/x-arj;application/x-brotli;application/x-brotli-compressed-tar;application/x-bzip;application/x-bzip2;application/bzip2;application/x-bzip-compressed-tar;application/x-bzip1;application/x-bzip1-compressed-tar;application/x-cabinet;application/x-cbr;application/x-cd-image;application/x-compress;application/x-compressed-tar;application/x-cpio;application/vnd.debian.binary-package;application/x-ear;application/x-ms-dos-executable;application/x-gtar;application/x-gzip;application/gzip;application/x-gzpostscript;application/x-java-archive;application/java-archive;application/jar;application/jar-archive;application/x-lha;application/x-lzh-compressed;application/x-lrzip;application/x-lrzip-compressed-tar;application/x-lzip;application/x-lzip-compressed-tar;application/x-lzma;application/x-lzma-compressed-tar;application/x-lzop;application/x-lzop-compressed-tar;application/x-ms-wim;application/x-rar;application/x-rar-compressed;application/x-rpm;application/x-source-rpm;application/x-rzip;application/x-tar;application/x-tarz;application/x-stuffit;application/x-war;application/x-xz;application/x-xz-compressed-tar;application/x-zip;application/x-zip-compressed;application/x-zoo;application/zstd;application/x-zstd;application/x-zstd-compressed-tar;application/zip;application/x-archive;application/vnd.ms-cab-compressed;
Categories=Utility;Archiving;
EOF

chmod 644 "${DESKTOP_PATH}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APP_DIR}" >/dev/null 2>&1 || true
fi

mime_types=(
  application/epub+zip
  application/x-7z-compressed
  application/x-7z-compressed-tar
  application/x-ace
  application/x-alz
  application/x-arc
  application/x-arj
  application/x-brotli
  application/x-brotli-compressed-tar
  application/x-bzip
  application/x-bzip2
  application/bzip2
  application/x-bzip-compressed-tar
  application/x-bzip1
  application/x-bzip1-compressed-tar
  application/x-cabinet
  application/x-cbr
  application/x-cd-image
  application/x-compress
  application/x-compressed-tar
  application/x-cpio
  application/vnd.debian.binary-package
  application/x-ear
  application/x-ms-dos-executable
  application/x-gtar
  application/x-gzip
  application/gzip
  application/x-gzpostscript
  application/x-java-archive
  application/java-archive
  application/jar
  application/jar-archive
  application/x-lha
  application/x-lzh-compressed
  application/x-lrzip
  application/x-lrzip-compressed-tar
  application/x-lzip
  application/x-lzip-compressed-tar
  application/x-lzma
  application/x-lzma-compressed-tar
  application/x-lzop
  application/x-lzop-compressed-tar
  application/x-ms-wim
  application/x-rar
  application/x-rar-compressed
  application/x-rpm
  application/x-source-rpm
  application/x-rzip
  application/x-tar
  application/x-tarz
  application/x-stuffit
  application/x-war
  application/x-xz
  application/x-xz-compressed-tar
  application/x-zip
  application/x-zip-compressed
  application/x-zoo
  application/zstd
  application/x-zstd
  application/x-zstd-compressed-tar
  application/zip
  application/x-archive
  application/vnd.ms-cab-compressed
)

for mime in "${mime_types[@]}"; do
  xdg-mime default "${APP_ID}" "${mime}" >/dev/null 2>&1 || true
done

echo "󰄬 Extractor installed: ${SCRIPT_PATH}"

# ─────────── reload ───────────
hyprctl reload 2>/dev/null || true

echo "󰄬 done"
