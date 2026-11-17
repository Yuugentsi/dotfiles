function ins --description 'Unified package manager'
    set -g PKG_PREVIEW true

    function __pkg_run
        command python3 -c 'import codecs
import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time
import tty
import unicodedata

arguments = sys.argv[1:]
manager = next((index for index, value in enumerate(arguments) if Path(value).name in {"pacman", "yay", "makepkg", "curl", "git"}), 0)
command = Path(arguments[manager]).name
options = arguments[manager + 1:]
flags = [value for value in options if value.startswith("-")]
packages = [value for value in options if not value.startswith("-")]
label = ", ".join(packages)
removing = False
starting, complete = "Working", "Complete"
if command in {"pacman", "yay"}:
    if any(value.startswith("-S") and "u" in value for value in flags):
        starting, complete = "Updating system", "System updated"
    elif any(value.startswith("-S") and "c" in value for value in flags):
        starting, complete = "Cleaning package cache", "Package cache cleaned"
    elif any(value.startswith("-R") for value in flags):
        starting, complete = "Removing", "Removed"
        removing = True
    elif any(value.startswith("-Y") and "c" in value for value in flags):
        starting, complete = "Cleaning unused packages", "Unused packages cleaned"
    else:
        starting, complete = "Installing", "Installed"
elif command == "makepkg":
    starting, complete = "Building package", "Package built"
    label = Path.cwd().name
elif command == "git":
    starting, complete = "Downloading build files", "Build files downloaded"
    label = ""
elif command == "curl":
    starting, complete = "Downloading package catalog", "Package catalog downloaded"
    label = ""
if label:
    starting += " · " + label
    complete += " · " + label
if not sys.stdin.isatty() or not sys.stdout.isatty():
    sys.exit(subprocess.call(arguments))
cache = Path.home() / ".cache/ins"
cache.mkdir(parents=True, exist_ok=True)
log_path = cache / "last.log"
ansi = re.compile(r"\\x1b\\[[0-?]*[ -/]*[@-~]|\\x1b\\][^\\x07]*(?:\\x07|\\x1b\\\\)")

FRAMES = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
SKY = (137, 220, 235)
MAUVE = (203, 166, 247)
PINK = (245, 194, 231)
YELLOW = (249, 226, 175)
PEACH = (250, 179, 135)
TEXT = (205, 214, 244)
DIM = (88, 91, 112)
SUB = (166, 173, 200)
GREEN = (166, 227, 161)
RED = (243, 139, 168)
RESET = "\\x1b[0m"
GRADIENTS = {"download": (SKY, MAUVE), "install": (MAUVE, PINK), "prepare": (YELLOW, PEACH)}
SIZE = r"[\\d.,]+\\s[KMGT]?i?B"
DOWNLOAD = re.compile(r"^(\\S+)(?:\\s+\\(\\s*(\\d+)/(\\d+)\\))?\\s+" + SIZE + r"\\s+(" + SIZE + r"/s)\\s+([\\d:\\-]+)\\s+\\[[^\\]]*\\]\\s+(\\d+)%$")
STEP = re.compile(r"^\\(\\s*(\\d+)/(\\d+)\\)\\s+(.*?)(?:\\s+\\[[^\\]]*\\]\\s+(\\d+)%)?$")
CURL = re.compile(r"^#*\\s*(\\d+)(?:[.,]\\d+)?%$")
GIT = re.compile(r"^(?:remote: )?(Receiving objects|Resolving deltas|Counting objects|Compressing objects):\\s+(\\d+)%")
SUMMARY = re.compile(r"^(Total Download Size|Total Installed Size|Net Upgrade Size|Total Removed Size):\\s+(.+)$")
COUNT = re.compile(r"^Packages? \\((\\d+)\\)")
PROMPT = re.compile(r"(?i)(password|passphrase).*:\\s*$|\\[y/n\\]\\s*$|[?:]\\s*$")
state = {"title": starting, "detail": "", "percent": None, "kind": "prepare", "prompt": False, "tick": 0,
         "error": "", "totals": False, "count": "", "download": "", "nothing": False, "history": [], "drawn": 1}


def paint(color):
    return "\\x1b[38;2;%d;%d;%dm" % color


def clean(text):
    return "".join(character for character in ansi.sub("", text) if character.isprintable())


def cell(character):
    if unicodedata.combining(character):
        return 0
    return 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1


def span(text):
    return sum(cell(character) for character in text)


def clip(text, width):
    if span(text) <= width:
        return text
    visible = []
    used = 0
    for character in text:
        size = cell(character)
        if used + size > max(0, width - 1):
            break
        visible.append(character)
        used += size
    return "".join(visible) + "…"


def headline(text):
    text = text.rstrip(". ")
    return text[:1].upper() + text[1:]


def parse(line):
    before = state["title"]
    scan(line)
    history = state["history"]
    if state["title"] != before and before != starting and (not history or history[-1] != before):
        history.append(before)
        del history[:-3]


def draw(rows, tail=""):
    lead = "\\x1b[%dA" % (state["drawn"] - 1) if state["drawn"] > 1 else ""
    sys.stdout.write(lead + "\\r" + "\\r\\n".join("\\x1b[2K" + row + RESET for row in rows) + tail)
    sys.stdout.flush()
    state["drawn"] = len(rows)


def trail(inner):
    rows = []
    history = state["history"]
    for index, title in enumerate(history):
        fade = (index + 1) / (len(history) + 1)
        glyph = tuple(round(DIM[channel] + (GREEN[channel] - DIM[channel]) * fade) for channel in range(3))
        shade = tuple(round(DIM[channel] + (SUB[channel] - DIM[channel]) * fade) for channel in range(3))
        rows.append(" " + paint(glyph) + "✓ " + paint(shade) + clip(title, inner - 2))
    return rows


def scan(line):
    text = clean(line).strip()
    if not text:
        return
    lowered = text.lower()
    if lowered.startswith("error:"):
        state["error"] = headline(text[6:].strip())
    elif "==> error:" in lowered:
        state["error"] = headline(text.split(":", 1)[1].strip())
    if "there is nothing to do" in lowered:
        state["nothing"] = True
    match = COUNT.match(text)
    if match:
        state["count"] = match.group(1)
        return
    match = SUMMARY.match(text)
    if match:
        if match.group(1) == "Total Download Size":
            state["download"] = match.group(2).strip()
        return
    match = DOWNLOAD.match(text)
    if match:
        name, done, total, speed, eta, percent = match.groups()
        if name == "Total":
            state["totals"] = True
        elif state["totals"]:
            return
        pieces = [speed, eta]
        if done:
            pieces.insert(0, done + "/" + total)
        state.update(kind="download", percent=int(percent), detail=" · ".join(pieces),
                     title="Downloading" if name == "Total" else name)
        return
    match = STEP.match(text)
    if match:
        done, total, action, percent = match.groups()
        action = re.sub(r"\\.+$", "", action).strip()
        first = action.split(" ", 1)[0].lower()
        kind = "install" if first in {"installing", "upgrading", "reinstalling", "downgrading", "removing"} else "prepare"
        value = int(percent) if percent else round(int(done) / max(1, int(total)) * 100)
        state.update(kind=kind, percent=value, detail=done + "/" + total, title=headline(action))
        return
    match = CURL.match(text)
    if match:
        state.update(kind="download", percent=int(match.group(1)), detail="")
        return
    match = GIT.match(text)
    if match:
        state.update(kind="download", percent=int(match.group(2)), detail="", title=match.group(1))
        return
    if text.startswith(":: ") or text.startswith("==> "):
        state.update(kind="prepare", percent=None, detail="", totals=False, title=headline(text.split(" ", 1)[1]))
        return
    if text.startswith("-> "):
        text = text[3:]
    state.update(percent=None, detail=text)


def render():
    columns = shutil.get_terminal_size().columns
    inner = max(8, columns - 2)
    if state["prompt"]:
        draw(trail(inner) + [" " + paint(YELLOW) + "❯ " + paint(TEXT) + clip(state["detail"], inner - 2)], " ")
        return
    start, end = GRADIENTS[state["kind"]]
    accent = paint(start)
    frame = FRAMES[state["tick"] % len(FRAMES)]
    title = state["title"]
    detail = state["detail"]
    if state["percent"] is None:
        title = clip(title, inner - 2)
        room = inner - 2 - span(title) - 2
        tail = "  " + paint(DIM) + clip(detail, room) if detail and room > 8 else ""
        line = " " + accent + frame + " " + paint(TEXT) + title + tail
    else:
        percent = max(0, min(100, state["percent"]))
        width = min(18, max(3, columns // 4))
        if columns < 65:
            detail = detail.split(" · ")[0]
        reserve = 24 if columns >= 65 else 6
        column = max(1, min(32, inner - 2 - 2 - width - 2 - 4 - 2 - reserve))
        detail = clip(detail, reserve)
        title = clip(title, column)
        title += " " * (column - span(title))
        filled = percent * width // 100
        cells = filled if filled == width else filled + 1
        shine = state["tick"] % (width + 8)
        bar = ""
        edge = start
        for index in range(cells):
            fade = index / max(1, width - 1)
            edge = tuple(round(start[channel] + (end[channel] - start[channel]) * fade) for channel in range(3))
            color = tuple((value + 510) // 3 for value in edge) if index == shine else edge
            bar += paint(color) + ("╸" if index == cells - 1 and filled < width else "━")
        rest = paint(DIM) + "─" * (width - cells)
        line = (" " + accent + frame + " " + paint(TEXT) + title + "  " + bar + rest + "  " + paint(edge)
                + "%3d%%" % percent + (paint(DIM) + "  " + detail if detail else ""))
    draw(trail(inner) + [line])


def finish(glyph, color, text, note):
    inner = max(8, shutil.get_terminal_size().columns - 2)
    text = clip(text, inner - 2)
    room = inner - 2 - span(text) - 2
    tail = "  " + paint(DIM) + clip(note, room) if note and room > 4 else ""
    lead = "\\x1b[%dA" % (state["drawn"] - 1) if state["drawn"] > 1 else ""
    sys.stdout.write(lead + "\\r\\x1b[J " + paint(color) + glyph + " " + paint(TEXT) + text + tail + RESET + "\\n")
    sys.stdout.flush()


previous = termios.tcgetattr(sys.stdin)
began = time.monotonic()
pid, master = pty.fork()
if pid == 0:
    os.execvp(arguments[0], arguments)


def resize(*unused):
    size = fcntl.ioctl(sys.stdin.fileno(), termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0))
    fcntl.ioctl(master, termios.TIOCSWINSZ, size)


signal.signal(signal.SIGWINCH, resize)
pending = ""
code = 1
try:
    resize()
    tty.setraw(sys.stdin.fileno())
    sys.stdout.write("\\x1b[?25l")
    render()
    inputs = [master, sys.stdin.fileno()]
    decoder = codecs.getincrementaldecoder("utf-8")("replace")
    with log_path.open("wb") as log:
        while True:
            ready, _, _ = select.select(inputs, [], [], 0.08)
            if not ready:
                if not state["prompt"]:
                    state["tick"] += 1
                    render()
                continue
            if master in ready:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                log.write(data)
                log.flush()
                state["prompt"] = False
                for character in ansi.sub("", decoder.decode(data)):
                    if character in "\\r\\n":
                        parse(pending)
                        pending = ""
                    else:
                        pending += character
                if pending.strip():
                    if PROMPT.search(pending):
                        state["prompt"] = True
                        state["detail"] = clean(pending).strip()
                        sys.stdout.write("\\x1b[?25h")
                    else:
                        parse(pending)
                if not state["prompt"]:
                    sys.stdout.write("\\x1b[?25l")
                render()
            if sys.stdin.fileno() in ready:
                data = os.read(sys.stdin.fileno(), 4096)
                if data:
                    os.write(master, data)
                else:
                    inputs.remove(sys.stdin.fileno())
    _, result = os.waitpid(pid, 0)
    code = os.waitstatus_to_exitcode(result)
except KeyboardInterrupt:
    os.kill(pid, signal.SIGINT)
    os.waitpid(pid, 0)
    code = 130
finally:
    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, previous)
    os.close(master)
    sys.stdout.write("\\x1b[?25h")
elapsed = time.monotonic() - began
notes = []
if state["count"] and not packages:
    notes.append(state["count"] + (" package" if state["count"] == "1" else " packages"))
if state["download"]:
    notes.append("↓ " + state["download"])
if elapsed >= 60:
    notes.append("%dm %02ds" % divmod(int(elapsed), 60))
elif elapsed >= 1:
    notes.append("%ds" % elapsed)
if code == 0:
    if state["nothing"]:
        finish("✓", GREEN, "Nothing to do" + (" · " + label if label else ""), " · ".join(notes[-1:] if elapsed >= 1 else []))
    elif removing:
        finish("−", RED, complete, " · ".join(notes))
    else:
        finish("✓", GREEN, complete, " · ".join(notes))
else:
    finish("✗", RED, state["error"] or "Failed (%d)" % code, starting + " · log " + str(log_path).replace(str(Path.home()), "~"))
sys.exit(code if code >= 0 else 128 - code)
' $argv
    end

    function __pkg_need -a cmd pkg
        command -v $cmd >/dev/null 2>&1; and return 0
        __pkg_run sudo pacman -S --noconfirm $pkg
    end

    function __pkg_need_yay
        command -v yay >/dev/null 2>&1; and return 0

        if test -f /var/lib/pacman/db.lck
            sudo rm -f /var/lib/pacman/db.lck
        end

        __pkg_need git git; or return 1

        if not pacman -Q base-devel >/dev/null 2>&1
            __pkg_run sudo pacman -S --noconfirm base-devel
        end

        set -l temp_dir (mktemp -d)
        __pkg_run git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"

        begin
            pushd "$temp_dir/yay" >/dev/null
            __pkg_run makepkg -si --noconfirm --needed
            popd >/dev/null
        end

        rm -rf $temp_dir
    end

    function __pkg_aur_cache -a cache_file
        mkdir -p (dirname "$cache_file")

        set -l should_update 0

        if not test -f "$cache_file"
            set should_update 1
        else if not test -s "$cache_file"
            set should_update 1
        else
            set -l file_time (stat -c %Y "$cache_file" 2>/dev/null; or date -r "$cache_file" +%s)
            set -l age (math (date +%s)" - $file_time")

            if test $age -gt 86400
                set should_update 1
            end
        end

        if test $should_update -eq 1
            set -l archive_file (mktemp)
            set -l unpacked_file "$cache_file.tmp"

            __pkg_run curl --fail --location --progress-bar --show-error \
                --output "$archive_file" \
                "https://aur.archlinux.org/packages.gz"; or begin
                rm -f "$archive_file"
                return 1
            end

            gunzip -c "$archive_file" > "$unpacked_file"; or begin
                rm -f "$archive_file" "$unpacked_file"
                return 1
            end

            mv "$unpacked_file" "$cache_file"; or begin
                rm -f "$archive_file" "$unpacked_file"
                return 1
            end
            rm -f "$archive_file"
        end
    end

    function __pkg_selected -a title badge_color item_color
        set -l pkgs $argv[4..-1]
        test (count $pkgs) -gt 0; or return
        if isatty stdout
            printf '\r\033[2K'
        end
        set_color $item_color
        printf '󰏗 %s · %s packages · %s' "$title" (count $pkgs) (string join ', ' -- $pkgs)
        set_color normal
        if not isatty stdout
            printf '\n'
        end
    end

    function __pkg_yay_install
        if command -v yay >/dev/null 2>&1
            __pkg_run yay -S --noconfirm $argv; or return 1
            __pkg_run yay -Yc --noconfirm 2>/dev/null
        else
            __pkg_run sudo pacman -S --noconfirm --color=always $argv; or return 1
        end
    end

    function __pkg_layout
        printf '%s\n' \
            --style=minimal \
            --height=75% \
            --layout=reverse \
            --border=rounded \
            --padding=0,1 \
            --input-border=none \
            --list-border=none \
            --ghost='Type a package name…' \
            --header= \
            --header-border=none \
            --footer='Tab select · Enter confirm · Ctrl-/ details · Esc close' \
            --footer-border=none \
            --no-separator \
            --highlight-line \
            --info=inline-right \
            --scrollbar='│' \
            --bind='ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all'
    end

    function __pkg_preview -a source
        printf '%s\n' --preview-window='right:50%:wrap:border-rounded' --preview-label-pos=2
        switch $source
            case installed
                printf '%s\n' --preview 'pacman -Qi --color=always {1}' --bind='focus:transform-preview-label:printf " %s " {1}'
            case aur
                printf '%s\n' --preview 'yay -Si --color=always {2}' --bind='focus:transform-preview-label:printf " %s " {2}'
            case packages
                printf '%s\n' --preview 'sh -c \'case "$1" in All) printf "ALL REPOSITORIES\\n\\nBrowse official repositories and AUR packages.";; Update) printf "SYSTEM UPDATE\\n\\nUpgrade installed packages and refresh repositories.";; Uninstall) printf "REMOVE PACKAGES\\n\\nChoose installed packages to remove.";; Clean) printf "PACKAGE CACHE\\n\\nRemove cached package files.";; *) pacman -Si --color=always "$1" 2>/dev/null || { command -v yay >/dev/null 2>&1 && yay -Si --color=always "$1"; };; esac\' sh {2}' --bind='focus:transform-preview-label:printf " %s " {2}'
        end
    end

    function __pkg_update
        if command -v yay >/dev/null 2>&1
            __pkg_run yay -Syu --noconfirm --color=always
        else
            __pkg_run sudo pacman -Syu --noconfirm --color=always
        end
    end

    function __pkg_clean
        if test -d /var/cache/pacman/pkg
            sudo find /var/cache/pacman/pkg -maxdepth 1 \( -name 'download-*' -o -name '*.part' \) -exec rm -rf -- {} + 2>/dev/null
        end
        if command -v yay >/dev/null 2>&1
            __pkg_run yay -Sc --noconfirm
        else
            __pkg_run sudo pacman -Sc --noconfirm
        end
    end

    function __pkg_uninstall -a UNINSTALL_COLORS
        set -l remove_pkgs (
            pacman -Qe | awk '{print $1}' | fzf --multi \
                (__pkg_layout) \
                $UNINSTALL_COLORS \
                --border-label=" 󰅙 Installed " \
                --border-label-pos=2 \
                --prompt="󰅙  " \
                --pointer="❯" \
                --marker="✖" \
                (__pkg_preview installed)
        )

        if test -n "$remove_pkgs"
            __pkg_selected "REMOVAL" f38ba8 f38ba8 $remove_pkgs
            __pkg_run sudo pacman -Rns --noconfirm $remove_pkgs
        end
    end

    function __pkg_aur_menu -a FZF_COLORS cache_file
        __pkg_need_yay; or return 1
        __pkg_aur_cache "$cache_file"

        set -l pkgs (
            awk '{print "󰣇 " $1}' "$cache_file" | fzf --multi \
                (__pkg_layout) \
                $FZF_COLORS \
                --border-label=" 󰣇 AUR " \
                --border-label-pos=2 \
                --prompt="󰣇  " \
                --pointer="❯" \
                --marker="✔" \
                (__pkg_preview aur)
        )

        set -l real_pkgs (printf "%s\n" $pkgs | awk '{print $NF}')
        if test -n "$real_pkgs"
            __pkg_selected "AUR" cba6f7 cba6f7 $real_pkgs
            __pkg_yay_install $real_pkgs
        end
    end

    function __pkg_help
        echo
        set_color -b 89b4fa 11111b --bold
        printf " 󰮯 INS "
        set_color normal
        echo
        echo
        set_color cdd6f4 --bold
        printf "Usage: "
        set_color 89dceb
        printf "ins "
        set_color a6adc8
        printf "[options] [package]\n\n"
        set_color 89b4fa
        printf "  ins                 "
        set_color cdd6f4
        printf "Interactive explorer\n"
        set_color 89b4fa
        printf "  ins <query>         "
        set_color cdd6f4
        printf "Search & install\n"
        set_color 89b4fa
        printf "  ins -u, --update    "
        set_color cdd6f4
        printf "Upgrade system\n"
        set_color 89b4fa
        printf "  ins -r, --remove    "
        set_color cdd6f4
        printf "Uninstall packages\n"
        set_color 89b4fa
        printf "  ins -a, --aur       "
        set_color cdd6f4
        printf "Search AUR\n"
        set_color 89b4fa
        printf "  ins -c, --clean     "
        set_color cdd6f4
        printf "Clean cache\n"
        set_color 89b4fa
        printf "  ins -h, --help      "
        set_color cdd6f4
        printf "Show help\n\n"
        set_color normal
    end

    __pkg_need fzf fzf; or return 1

    set -l FZF_COLORS "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#89b4fa,info:#cba6f7,pointer:#f5e0dc,marker:#a6e3a1,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8,border:#89b4fa,label:#89b4fa,query:#cdd6f4,list-border:#585b70,input-border:#89b4fa,input-label:#89b4fa,list-label:#cba6f7,preview-border:#585b70,preview-label:#cba6f7,footer:#9399b2,ghost:#6c7086,separator:#45475a"
    set -l UNINSTALL_COLORS "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f38ba8,marker:#f38ba8,fg+:#f38ba8,prompt:#f38ba8,hl+:#eba0ac,border:#f38ba8,label:#f38ba8,query:#cdd6f4,list-border:#585b70,input-border:#f38ba8,input-label:#f38ba8,list-label:#f38ba8,preview-border:#585b70,preview-label:#f38ba8,footer:#9399b2,ghost:#6c7086,separator:#45475a"
    set -l cache_file "$HOME/.cache/aur_packages"

    if test (count $argv) -gt 0
        switch $argv[1]
            case -h --help help
                __pkg_help
                return

            case -u --update update
                __pkg_update
                return

            case -r --remove remove uninstall
                __pkg_uninstall $UNINSTALL_COLORS
                return

            case -a --aur aur
                __pkg_aur_menu $FZF_COLORS "$cache_file"
                return

            case -c --clean clean
                __pkg_clean
                return

            case '*'
                set -l query $argv[1]

                pacman -Si "$query" >/dev/null 2>&1
                if test $status -eq 0
                    __pkg_run sudo pacman -S --noconfirm --color=always $argv
                    return
                end

                set -l selected (
                    pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}' | fzf --multi \
                        (__pkg_layout) \
                        $FZF_COLORS \
                        --query="$query" \
                        --border-label=" 󰮯 Search " \
                        --border-label-pos=2 \
                        --prompt="󰮯  " \
                        --pointer="❯" \
                        --marker="✔" \
                        (__pkg_preview packages)
                )

                set -l real_pkgs (printf "%s\n" $selected | awk '{print $NF}')
                if test -n "$real_pkgs"
                    __pkg_selected "PACKAGES" 89b4fa 89b4fa $real_pkgs
                    __pkg_run sudo pacman -S --noconfirm --color=always $real_pkgs
                end
                return
        end
    end

    set -l pkgs (
        begin
            printf "%s\n" "󰏗 All" "󰇚 Update" "󰅙 Uninstall" "󰃢 Clean"
            pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}'
        end | fzf --multi \
            (__pkg_layout) \
            $FZF_COLORS \
            --border-label=" 󰮯 Packages " \
            --border-label-pos=2 \
            --prompt="󰮯  " \
            --pointer="❯" \
            --marker="✔" \
            (__pkg_preview packages)
    )

    test -z "$pkgs"; and return

    switch $pkgs[1]
        case "*Update*"
            __pkg_update

        case "*Uninstall*"
            __pkg_uninstall $UNINSTALL_COLORS

        case "*Clean*"
            __pkg_clean

        case "*All*"
            __pkg_need_yay; or return 1
            __pkg_aur_cache "$cache_file"

            set -l pkgs (
                begin
                    pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}'
                    awk '{print "󰣇 " $1}' "$cache_file"
                end | fzf --multi \
                    (__pkg_layout) \
                    $FZF_COLORS \
                    --border-label=" 󰏗 Repos " \
                    --border-label-pos=2 \
                    --prompt="󰏗  " \
                    --pointer="❯" \
                    --marker="✔" \
                    (__pkg_preview packages)
            )

            set -l real_pkgs (printf "%s\n" $pkgs | awk '{print $NF}')
            if test -n "$real_pkgs"
                __pkg_selected "PACKAGES" cba6f7 cba6f7 $real_pkgs
                __pkg_yay_install $real_pkgs
            end

        case "*"
            set -l real_pkgs (printf "%s\n" $pkgs | grep -v -E "󰏗|󰇚|󰅙|󰃢" | awk '{print $NF}')
            if test -n "$real_pkgs"
                __pkg_selected "PACKAGES" 89b4fa 89b4fa $real_pkgs
                __pkg_run sudo pacman -S --noconfirm --color=always $real_pkgs
            end
    end
end
