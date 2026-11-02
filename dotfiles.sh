#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Yuugentsi/dotfile.git"

PACKAGES=(
    libnotify
    xdg-utils
    python
    libarchive
    file-roller
    brightnessctl
    cliphist
    fish
    fd
    gvfs
    hyprland
    hypridle
    hyprlock
    hyprpaper
    hyprshot
    hyprsunset
    imagemagick
    jq
    kitty
    mpv
    mpv-mpris
    playerctl
    nano
    pacman-contrib
    rofi
    swayimg
    telegram-desktop
    thunar
    qt6ct
    tree
    ttf-jetbrains-mono
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-extra
    wl-clipboard
    yt-dlp
    zoxide
    ffmpegthumbnailer
    fzf
    tumbler
    zed
    zip
    unzip
    xdg-desktop-portal-hyprland
    aria2
    qt6-multimedia
    qt6-imageformats
    power-profiles-daemon
    wf-recorder
    xcursor-vanilla-dmz
)

BOLD=""
ACCENT=""
GREEN=""
DIM=""
RED=""
RESET=""
FAILED_STEPS=()
ANIMATED=false

if [[ -t 1 && -z "${NO_COLOR+x}" && "${TERM:-dumb}" != "dumb" ]]; then
    BOLD=$'\e[1m'
    ACCENT=$'\e[38;2;137;220;235m'
    GREEN=$'\e[38;2;166;227;161m'
    DIM=$'\e[38;2;88;91;112m'
    RED=$'\e[38;2;243;139;168m'
    RESET=$'\e[0m'
    ANIMATED=true
    trap 'printf "\033[?25h"' EXIT
fi

step() {
    printf '  %s◇%s %s\n' "$ACCENT" "$RESET" "$1"
}

render_status() {
    local detail="$1" frame="$2" width="$3"
    local phase package current total percent bar_width filled empty bar trail title_width
    if [[ "$detail" =~ ^(Downloading|Installing)[[:space:]]+([^[:space:]]+)[[:space:]]+·[[:space:]]+([0-9]+)/([0-9]+)([[:space:]]+·[[:space:]]+([0-9]+)%)?$ ]]; then
        phase="${BASH_REMATCH[1]}"
        package="${BASH_REMATCH[2]}"
        current="${BASH_REMATCH[3]}"
        total="${BASH_REMATCH[4]}"
        percent="${BASH_REMATCH[6]:-100}"
        bar_width=12
        title_width=$((width - 49))
        if ((title_width < 8)); then
            printf '  %s%s%s %.*s %s%s%%%s' "$ACCENT" "$frame" "$RESET" "$((width - 12))" "$package" "$DIM" "$percent" "$RESET"
            return
        fi
        ((title_width > 30)) && title_width=30
        filled=$((percent * bar_width / 100))
        empty=$((bar_width - filled))
        printf -v bar '%*s' "$filled" ''
        printf -v trail '%*s' "$empty" ''
        bar="${bar// /━}"
        trail="${trail// /─}"
        printf '  %s%s%s %s%-*.*s%s  %s%s%s%s%s  %3s%%  %s%2s/%-2s  %s%s' \
            "$ACCENT" "$frame" "$RESET" "$BOLD" "$title_width" "$title_width" "$package" "$RESET" \
            "$ACCENT" "$bar" "$DIM" "$trail" "$RESET" "$percent" "$DIM" "$current" "$total" "$phase" "$RESET"
    else
        printf '  %s%s%s %.*s' "$ACCENT" "$frame" "$RESET" "$((width - 5))" "$detail"
    fi
}

run() {
    local label="$1" log_file pid frame=0 result=0 detail width rendered
    width=${COLUMNS:-80}
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    ((width > 8)) || width=80
    local -a frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    shift
    log_file=$(mktemp)
    (
        set -euo pipefail
        "$@"
    ) >"$log_file" 2>&1 &
    pid=$!
    if "$ANIMATED"; then
        printf '\033[?25l'
        while kill -0 "$pid" 2>/dev/null; do
            detail=$(tail -c 2048 "$log_file" | tr '\r' '\n' | sed -E '/^[[:space:]]*$/d; /[Nn]o changes? (required|needed|made)/d; /[Tt]here is nothing to do/d' | tail -n 1 | LC_ALL=C tr -d '\000-\010\013-\037\177')
            detail="${detail:-$label}"
            rendered=$(render_status "$detail" "${frames[frame % 10]}" "$width")
            printf '\r%s\033[K' "$rendered"
            frame=$((frame + 1))
            sleep 0.08
        done
    fi
    wait "$pid" || result=$?
    if "$ANIMATED"; then
        printf '\r\033[?25h'
    fi
    if ((result == 0)); then
        printf '  %s✓%s %s' "$GREEN" "$RESET" "$label"
        if "$ANIMATED"; then printf '\033[K'; fi
        printf '\n'
    else
        printf '  %s✗%s %s' "$RED" "$RESET" "$label" >&2
        if "$ANIMATED"; then printf '\033[K'; fi
        printf '\n' >&2
        FAILED_STEPS+=("$label")
        cat "$log_file" >&2
    fi
    rm -f "$log_file"
    return 0
}

finish() {
    if ((${#FAILED_STEPS[@]})); then
        printf '\n  %sSetup finished with %s failed step(s):%s\n' "$RED" "${#FAILED_STEPS[@]}" "$RESET" >&2
        printf '  ✗ %s\n' "${FAILED_STEPS[@]}" >&2
        return 1
    fi
    printf '\n  %s✓%s Setup complete.\n\n' "$GREEN" "$RESET"
}

header() {
    printf '\n  %s%s◈  dotfiles%s  %s/  %s%s\n\n' "$BOLD" "$ACCENT" "$RESET" "$DIM" "$1" "$RESET"
}

simulate_packages() {
    local package percent index=0 total=${#PACKAGES[@]}
    for package in "${PACKAGES[@]}"; do
        index=$((index + 1))
        for percent in 15 45 75 100; do
            printf 'Downloading %s · %s/%s · %s%%\n' "$package" "$index" "$total" "$percent"
            sleep 0.08
        done
        printf 'Installing %s · %s/%s · 100%%\n' "$package" "$index" "$total"
        sleep 0.08
    done
}

preview() {
    header "preview · simulation"
    run "Repository synced" sleep 0.5
    run "Packages ready (${#PACKAGES[@]})" simulate_packages
    local label
    for label in "Updating Fish" "Applying configuration" "Setting up Thunar actions" "Reloading Hyprland"; do
        run "$label" sleep 0.5
    done
    printf '\n  %s✓%s Preview complete\n\n' "$GREEN" "$RESET"
}

case "${1:-}" in
    --preview) preview; exit 0 ;;
    --help|-h)
        printf 'Usage: %s [--preview | --help]\n' "$0"
        exit 0
        ;;
    "") ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
esac

header "setup"
printf '  %s01%s  Full setup\n' "$ACCENT" "$RESET"
printf '  %s02%s  Update configuration\n' "$ACCENT" "$RESET"
printf '  %s03%s  Packages and utilities\n' "$ACCENT" "$RESET"
printf '  %s04%s  Install apps only\n\n' "$ACCENT" "$RESET"
printf '  %s›%s ' "$ACCENT" "$RESET"
read -r choice
printf '\n'

case "$choice" in
    1|2|3|4) ;;
    *)
        printf '  Invalid option. Choose 1, 2, 3, or 4.\n' >&2
        exit 1
        ;;
esac

sudo -v

if [[ "$choice" == 4 ]]; then
    run "Installing apps" sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
    finish
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/.config/fish" ] && [ -d "$SCRIPT_DIR/.config/hypr" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
else
    rm -rf "/tmp/dotfiles"
    run "Syncing repository" git clone "$REPO_URL" "/tmp/dotfiles"
    DOTFILES_DIR="/tmp/dotfiles"
fi

install_extractor() {
    sudo pacman -S --needed --noconfirm file-roller libarchive python xdg-utils libnotify
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

[ -n "$archive_path" ] || fail "No archive was provided."
[ -f "$archive_path" ] || fail "File does not exist: $archive_path"
command -v bsdtar >/dev/null 2>&1 || fail "Install libarchive to use bsdtar."
command -v gio >/dev/null 2>&1 || fail "Install gio to move archives to Trash."

archive_dir="$(dirname "$archive_path")"
archive_name="$(basename "$archive_path")"
base_name="$archive_name"

while [[ "$base_name" == *.tar.gz || "$base_name" == *.tar.bz2 || "$base_name" == *.tar.xz || "$base_name" == *.tar.zst || "$base_name" == *.tar.lz || "$base_name" == *.tar.lzma || "$base_name" == *.tar.Z ]]; do
  base_name="${base_name%.*}"
done

case "$base_name" in
  *.tgz|*.tbz2|*.txz|*.tlz|*.tzst) base_name="${base_name%.*}" ;;
esac

case "$archive_name" in
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

[ -n "$base_name" ] || base_name="${archive_name}.extracted"

staging_dir="$(mktemp -d "${archive_dir}/.extract.XXXXXXXX")" || fail "Cannot create extraction directory."
trap 'rm -rf -- "$staging_dir"' EXIT

if ! bsdtar -xf "$archive_path" -C "$staging_dir"; then
  fail "The archive may be corrupted or use an unsupported format."
fi

shopt -s dotglob nullglob
entries=("$staging_dir"/*)
source_dir="$staging_dir"
if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ] && [ ! -L "${entries[0]}" ]; then
  source_dir="${entries[0]}"
fi

target_dir="${archive_dir}/${base_name}"
suffix=2
while ! mkdir -- "$target_dir" 2>/dev/null; do
  if [ ! -e "$target_dir" ] && [ ! -L "$target_dir" ]; then
    fail "Cannot create destination directory."
  fi
  target_dir="${archive_dir}/${base_name}-${suffix}"
  suffix=$((suffix + 1))
done

if ! mv -T -- "$source_dir" "$target_dir"; then
  rmdir -- "$target_dir" 2>/dev/null || true
  fail "Cannot move the extracted files to the destination."
fi

if ! gio trash "$archive_path"; then
  fail "Extraction succeeded, but moving the archive to Trash failed."
fi

notify "Archive extracted" "$(basename "$target_dir")"
EOF

    chmod +x "${SCRIPT_PATH}"

    cat > "${DESKTOP_PATH}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Extract Archive
Exec="${SCRIPT_PATH}" %f
TryExec=${SCRIPT_PATH}
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

    cat > "${BIN_DIR}/thunar-zip-folder.sh" <<'ZIP_FOLDER'
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '%s\n' "$1" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "ZIP failed" "$1" || true
  fi
  exit 1
}

[ "$#" -ge 1 ] || fail "Select at least one file or folder."
command -v file-roller >/dev/null 2>&1 || fail "Missing dependency: file-roller"

items=()
for selected in "$@"; do
  if [ ! -e "$selected" ] && [ ! -L "$selected" ]; then
    fail "Selected item not found: $selected"
  fi
  if [ -d "$selected" ]; then
    item="$(cd -- "$selected" && pwd -P)"
    [ "$item" != / ] || fail "Cannot compress the root directory."
  elif [ -f "$selected" ]; then
    parent="$(cd -- "$(dirname -- "$selected")" && pwd -P)"
    item="$parent/$(basename -- "$selected")"
  else
    continue
  fi
  items+=("$item")
done
[ "${#items[@]}" -gt 0 ] || fail "No regular files or folders selected."

if [ "${#items[@]}" -eq 1 ]; then
  archive_base="${items[0]}"
else
  parent="$(dirname -- "${items[0]}")"
  name="$(basename -- "$parent")"
  [ "$name" != / ] || name=archive
  archive_base="$parent/$name"
fi
archive="${archive_base}.zip"
suffix=2
while [ -e "$archive" ] || [ -L "$archive" ]; do
  archive="${archive_base}-${suffix}.zip"
  suffix=$((suffix + 1))
done

exec file-roller --notify --add-to="$archive" -- "${items[@]}"

ZIP_FOLDER
    chmod +x "${BIN_DIR}/thunar-zip-folder.sh"

    cat > "${BIN_DIR}/thunar-del.py" <<'DEL_PY'
#!/usr/bin/env python3
import os
import shutil
import sys


def main():
    if len(sys.argv) < 2:
        raise ValueError("Select at least one file or folder.")
    paths = list(dict.fromkeys(os.path.abspath(path) for path in sys.argv[1:]))
    for path in paths:
        if not path.strip("/"):
            raise ValueError("Cannot delete the root directory.")
        if not os.path.lexists(path):
            raise ValueError(f"Selected item not found: {path}")
    for path in sorted(paths, key=lambda item: item.count(os.sep), reverse=True):
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path)
        else:
            os.unlink(path)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        print(f"Permanent deletion failed: {error}", file=sys.stderr)
        sys.exit(1)
DEL_PY
    chmod +x "${BIN_DIR}/thunar-del.py"

    python3 - <<'PYTHON'
import os
import time
from pathlib import Path
import xml.etree.ElementTree as ET

config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
path = config_dir / "Thunar" / "uca.xml"
if path.exists():
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    tree = ET.parse(path, parser=parser)
    root = tree.getroot()
    if root.tag != "actions":
        raise SystemExit(f"Invalid Thunar configuration: {path}")
else:
    root = ET.Element("actions")
    tree = ET.ElementTree(root)
actions = [
    action for action in root.findall("action")
    if "TerminalEmulator" in action.findtext("command", "")
    or action.findtext("command", "") == "kitty --directory %f"
]
if not actions:
    action = ET.SubElement(root, "action")
    for tag, text in (
        ("icon", "utilities-terminal"),
        ("name", "Open Terminal Here"),
        ("unique-id", f"{time.time_ns()}-kitty"),
        ("command", "kitty --directory %f"),
        ("description", "Open Kitty in this folder"),
        ("patterns", "*"),
        ("directories", None),
    ):
        ET.SubElement(action, tag).text = text
else:
    for action in actions:
        action.find("command").text = "kitty --directory %f"

zip_id = "thunar-zip-folder"
action = next((a for a in root.findall("action")
               if a.findtext("unique-id") == zip_id), None)
if action is None:
    action = ET.SubElement(root, "action")
helper_path = Path.home() / ".local/bin/thunar-zip-folder.sh"
quoted_helper = "'" + str(helper_path).replace("'", "'\"'\"'") + "'"
for tag, text in (
    ("icon", "package-x-generic"),
    ("name", "Compress to ZIP"),
    ("unique-id", zip_id),
    ("command", f"{quoted_helper} %F"),
    ("description", "Create one ZIP archive containing all selected files and folders"),
    ("patterns", "*"),
    ("range", ""),
    ("directories", None),
    ("audio-files", None),
    ("image-files", None),
    ("other-files", None),
    ("text-files", None),
    ("video-files", None),
):
    element = action.find(tag)
    if element is None:
        element = ET.SubElement(action, tag)
    element.text = text

del_id = "thunar-permanent-delete"
action = next((a for a in root.findall("action")
               if a.findtext("unique-id") == del_id), None)
if action is None:
    action = ET.SubElement(root, "action")
helper_path = Path.home() / ".local/bin/thunar-del.py"
quoted_helper = "'" + str(helper_path).replace("'", "'\"'\"'") + "'"
for tag, text in (
    ("icon", "edit-delete"),
    ("name", "del"),
    ("unique-id", del_id),
    ("command", f"python3 {quoted_helper} %F"),
    ("description", "Permanently delete the selection without confirmation"),
    ("patterns", "*"),
    ("range", ""),
    ("directories", None),
    ("audio-files", None),
    ("image-files", None),
    ("other-files", None),
    ("text-files", None),
    ("video-files", None),
):
    element = action.find(tag)
    if element is None:
        element = ET.SubElement(action, tag)
    element.text = text

path.parent.mkdir(parents=True, exist_ok=True)
tree.write(path, encoding="UTF-8", xml_declaration=True)
PYTHON

    step "Thunar ZIP, Open Terminal Here and del actions installed"

    step "Archive extractor installed: ${SCRIPT_PATH}"
}

install_packages() {
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
}

set_shell_fish() {
    step "Setting Fish as the default shell..."
    sudo chsh -s /usr/bin/fish "$USER"
}

create_media_dirs() {
    step "Creating media directories..."
    MEDIA="${HOME}/1"
    mkdir -p "${HOME}/Downloads"
    for d in music videos pictures documents; do
        [ -d "$MEDIA/$d" ] || mkdir -p "$MEDIA/$d"
    done
}

copy_dotfiles() {
    TARGET_DIR="${HOME}/.config"
    mkdir -p "$TARGET_DIR"

    for dir in "$DOTFILES_DIR"/.config/*/; do
        name="$(basename "$dir")"
        [ "$name" = ".git" ] && continue
        step "Updating configuration: ${name}"
        rm -rf "${TARGET_DIR:?}/${name}"
        cp -r "$dir" "${TARGET_DIR}/"
    done

    chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true
}

reload_hyprland() {
    step "Reloading Hyprland..."
    hyprctl reload 2>/dev/null || true
}

create_gtk_bookmarks() {
    step "Updating file manager bookmarks..."
    mkdir -p "${HOME}/.config/gtk-3.0"
    cat > "${HOME}/.config/gtk-3.0/bookmarks" <<EOF
file://${HOME}/.config/
file://${HOME}/Downloads/
file://${HOME}/1
file://${HOME}/1/documents
file://${HOME}/1/music
file://${HOME}/1/pictures
file://${HOME}/1/videos
EOF
}

apply_nodisplay() {
    step "Updating application menu visibility..."
    apps_nodisplay=(
        avahi-discover.desktop bssh.desktop bvnc.desktop
        xfce4-about.desktop qv4l2.desktop qvidcap.desktop
        xgps.desktop xgpsspeed.desktop org.freedesktop.Xwayland.desktop
        kitty-open.desktop thunar-bulk-rename.desktop thunar-settings.desktop
        org.gnupg.pinentry-qt5.desktop org.gnupg.pinentry-qt.desktop
        electron36.desktop electron37.desktop
        rofi.desktop rofi-theme-selector.desktop lstopo.desktop
    )
    for app in "${apps_nodisplay[@]}"; do
        file="/usr/share/applications/$app"
        if [ -f "$file" ] && ! grep -q '^NoDisplay=true$' "$file" 2>/dev/null; then
            echo "NoDisplay=true" | sudo tee -a "$file" >/dev/null
        fi
    done
}

install_yay() {
    local build_dir
    sudo pacman -S --needed --noconfirm base-devel
    build_dir=$(mktemp -d /tmp/dotfiles-yay.XXXXXXXX)
    git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
    cd "$build_dir/yay"
    makepkg -si --noconfirm
    cd /
    rm -rf -- "$build_dir"
}

install_spotx() {
    local script
    script=$(mktemp)
    curl -fsSL https://spotx-official.github.io/run.sh -o "$script"
    bash "$script"
    rm -f -- "$script"
}

apply_theme() {
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
    gsettings set org.gnome.desktop.interface icon-theme "breeze-dark"
}

case "$choice" in
    1)
        run "Installing Git" sudo pacman -S --needed --noconfirm git

        run "Installing packages" install_packages

        run "Installing SpotX" install_spotx

        run "Setting Fish as default shell" set_shell_fish

        run "Creating media directories" create_media_dirs

        run "Applying configuration" copy_dotfiles

        run "Updating bookmarks" create_gtk_bookmarks

        run "Updating application menu" apply_nodisplay

        run "Applying the desktop theme" apply_theme

        if ! command -v yay &>/dev/null; then
            run "Installing the Yay AUR helper" install_yay
        fi

        run "Setting up Thunar actions" install_extractor

        run "Reloading Hyprland" reload_hyprland

        finish
        ;;
    2)
        run "Applying configuration" copy_dotfiles

        run "Installing Fish" sudo pacman -S --needed --noconfirm fish
        run "Setting Fish as default shell" set_shell_fish

        run "Setting up Thunar actions" install_extractor

        run "Reloading Hyprland" reload_hyprland

        finish
        ;;
    3)
        run "Installing Git" sudo pacman -S --needed --noconfirm git

        run "Installing packages" install_packages

        run "Setting Fish as default shell" set_shell_fish

        run "Creating media directories" create_media_dirs

        run "Updating bookmarks" create_gtk_bookmarks

        run "Updating application menu" apply_nodisplay

        run "Setting up Thunar actions" install_extractor

        finish
        ;;
    *)
        printf '  Invalid option. Choose 1, 2, 3, or 4.\n' >&2
        exit 1
        ;;
esac
