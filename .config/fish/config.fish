# -------- init --------
if status is-interactive
end

set -g fish_greeting

# -------- functions --------
for f in ~/.config/fish/functions/*.fish
    source $f
end

# -------- aliases --------
alias pwd="command pwd | wl-copy; and command pwd"
alias myip="echo -n 'IP:  '; ip -4 -o a show | awk '/inet / && !/127.0.0.1/{print \$4}' | cut -d/ -f1 | head -1; echo -n 'DNS: '; awk '/^nameserver/{print \$2}' /etc/resolv.conf | head -1"
alias f="rg -l . | fzf"
alias d="cd ~/Downloads"
alias c="clear"

function r -d "delete by ext"; if test (count $argv) -ne 1; printf 'Usage: r .extension\n' >&2; return 2; end; if not string match -rq '^\.[A-Za-z0-9][A-Za-z0-9._-]*$' -- "$argv[1]"; printf 'Invalid extension. Example: r .mp4\n' >&2; return 2; end; set -l deleted 0; set -l files (command find "$HOME" -type f -name "*$argv[1]" -print0 | string split0); for file in $files; if command rm -- "$file"; set deleted (math $deleted + 1); end; end; printf ' %s\n' "$deleted"; end
function security -d adb; command -q adb; or begin; echo 'ADB not found.' >&2; return 1; end; command adb get-state >/dev/null; or return; set -l p com.miui.securitycenter; set -l r (command adb shell pm list packages --user 0 "$p"); or return; if contains -- "package:$p" (string trim -- $r); set r (command adb shell pm uninstall -k --user 0 "$p"); or return; if not contains -- Success (string trim -- $r); printf '%s\n' $r >&2; return 1; end; set_color ff6b8a; printf '✓ Security · removed (data preserved)\n'; set_color normal; else; set r (command adb shell cmd package install-existing --user 0 "$p"); or begin; set -l s $status; printf '%s\n' $r >&2; return $s; end; set r (command adb shell pm enable --user 0 "$p"); or begin; set -l s $status; printf '%s\n' $r >&2; return $s; end; set_color a6e3a1; printf '✓ Security · restored and enabled\n'; set_color normal; end; end
function sd -d adb; if test (count $argv) -ne 0; printf 'Usage: sd\n' >&2; return 2; end; command python3 "$HOME/.local/bin/adb-push-folder" "$PWD"; end
function clock; clear; while true; printf '\r◷ %s' (date '+%H:%M:%S'); sleep 1; end; end
function rd -d "remove dir"; clear; set -l p (pwd); if test "$p" = /; or test "$p" = /home; or test "$p" = $HOME; set_color red; echo "refuse to remove protected dir: $p"; set_color normal; return 1; end; cd ..; read -l -P "rm -rf $p ? [y/N] " confirm; test "$confirm" = y; and rm -rf $p; and clear; and echo "deleted $p"; end
function chmod -d "make executable"; clear; if test (count $argv) -eq 0; set -l sh (find (pwd) -maxdepth 1 -name "*.sh" -type f); if test (count $sh) -gt 0; command chmod +x $sh; or return $status; for f in $sh; set_color a6e3a1; printf "  ✓ "; set_color normal; printf "%s" (basename $f); set_color --dim; printf "  +x\n"; set_color normal; end; end; else; command chmod -R $argv (pwd); end; end
function empty -d "remove empty dirs"; set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l); find (pwd) -type d -empty -delete 2>/dev/null; echo "$n folders deleted"; end
function .venv -d "project venv"; set -l env "$PWD/.venv"; if test "$VIRTUAL_ENV" = "$env"; deactivate; or return $status; clear; echo "venv off: $env"; return 0; end; if not test -f "$env/bin/activate.fish"; python3 -m venv "$env"; or return $status; end; source "$env/bin/activate.fish"; or return $status; if test -f requirements.txt; echo "installing requirements.txt..."; python -m pip install -r requirements.txt; or return $status; end; clear; echo "venv on: $env"; end
function .venvd -d "delete venv"; set -l env "$PWD/.venv"; if not test -e "$env"; and not test -L "$env"; echo "no .venv in this directory"; return 1; end; if test "$VIRTUAL_ENV" = "$env"; deactivate; or return $status; end; command rm -rf -- "$env"; or return $status; echo "deleted: $env"; end
function venv -d "global venv"; set -l green (set_color green); set -l red (set_color red); set -l reset (set_color normal); set -l env "$HOME/.venv"; if test -n "$VIRTUAL_ENV"; deactivate; clear; echo -s $red "󰄬 venv off" $reset; else; if not test -d "$env"; python3 -m venv "$env"; end; source "$env/bin/activate.fish"; if test -f requirements.txt; echo -s $green "  installing requirements.txt..." $reset; pip install -q -r requirements.txt; end; clear; echo -s $green "󰄬 venv on" $reset; end; end
function py; test -z "$VIRTUAL_ENV"; and venv; if test -n "$argv"; python3 $argv; else if test -f main.py; python3 main.py; else if test -f bot.py; python3 bot.py; else; python3 main.py; end; end
function copy -d "copy file"; if test (count $argv) -ne 1; printf 'Usage: copy <file>\n' >&2; return 1; end; if not test -f "$argv[1]"; or not test -r "$argv[1]"; printf 'File does not exist or is not readable: %s\n' "$argv[1]" >&2; return 1; end; command wl-copy --type text/plain < "$argv[1]"; or return $status; set -l line_count (awk 'END { print NR }' < "$argv[1]"); printf '✓ %s\n' "$line_count"; end
function s -d "dir size"; if test (count $argv) -gt 1; printf 'Usage: s [directory]\n' >&2; return 1; end; set -l directory .; if test (count $argv) -eq 1; set directory "$argv[1]"; end; if not test -d "$directory"; printf 'Directory does not exist: %s\n' "$directory" >&2; return 1; end; command du -sh -- "$directory"; end
function mkcd -d "mkdir + cd"; mkdir -p $argv[1]; and cd $argv[1]; end

function pass -d "toggle sudo"; if test (count $argv) -ne 0; printf 'Usage: pass\n' >&2; return 2; end; sudo /usr/bin/bash -c 'set -euo pipefail; export PATH=/usr/bin:/usr/sbin; export LC_ALL=C; user_id="$1"; [[ "$user_id" =~ ^[0-9]+$ ]]; shopt -s nullglob; rule_files=(/etc/sudoers.d/zz-ai-pass-${user_id}-*); if ((${#rule_files[@]})); then rm -f -- "${rule_files[@]}"; visudo -c >/dev/null; printf "Passwordless sudo disabled.\\n"; exit 0; fi; expires_at=$(date -u -d "+30 minutes" +%Y%m%d%H%M%SZ); expires_display=$(date -d "+30 minutes" "+%H:%M:%S %Z"); rule_file=$(mktemp "/etc/sudoers.d/zz-ai-pass-${user_id}-XXXXXXXX"); trap "rm -f -- \\"$rule_file\\"" EXIT; chmod 0440 "$rule_file"; printf "#%s ALL=(ALL:ALL) NOTAFTER=%s NOPASSWD: ALL\\n" "$user_id" "$expires_at" > "$rule_file"; visudo -cf "$rule_file" >/dev/null; visudo -c >/dev/null; unit_name="ai-pass-$(basename "$rule_file")"; systemd-run --quiet --unit="$unit_name" --on-active=30min /usr/bin/rm -f -- "$rule_file"; trap - EXIT; printf "Passwordless sudo enabled for 30 minutes, until %s.\\n" "$expires_display"' -- (id -u); or return $status; command sudo -k; end

# -------- zoxide --------
if command -q zoxide
    zoxide init fish | source
end

# -------- fzf --------
if command -q fzf
    fzf --fish | source
end

# -------- prompt --------
set -g fish_transient_prompt 1

function fish_prompt
    if set -q argv[1]
        echo -n "❯ "
        return
    end

    set -l last_status $status

    set -l status_color f5c2e7
    if test $last_status -ne 0
        set status_color ff6b8a
    end

    set -l pwd (string replace -r "^$HOME/" "" "$PWD")
    string match -q "$HOME" "$PWD"; and set pwd "~"

    set -l DIM (set_color 7c5cbf)
    set -l DIR (set_color c8b8de --bold)
    set -l N (set_color normal)

    echo -s "$DIM●$N $DIR$pwd$N"
    echo -n -s "$DIM╰─$N " (set_color $status_color --bold) "❯ " (set_color normal)
end

# -------- notify --------
function __hypr_notify_cmd --on-event fish_postexec
    set -l last_status $status
    set -l cmd (string trim "$argv[1]")
    test -z "$cmd"; and return

    if test $last_status -eq 0
        hyprctl notify 5 2500 "rgb(a6e3a1)" "OK: $cmd" > /dev/null 2>&1
    else
        hyprctl notify 3 3500 "rgb(f38ba8)" "Failed ($last_status): $cmd" > /dev/null 2>&1
    end
    if test -f "$HOME/.local/share/sounds/notify.wav"
        pw-play "$HOME/.local/share/sounds/notify.wav" > /dev/null 2>&1 &
    end
end

# -------- init --------
function init --description 'Install apps and fonts'
    sudo pacman -S --needed \
        cliphist fish fd gvfs hyprland hypridle hyprlock hyprpaper hyprshot hyprsunset \
        imagemagick jq kitty mpv mpv-mpris playerctl nano rofi swayimg thunar qt6ct \
        wl-clipboard yt-dlp zathura zathura-cb zoxide ffmpegthumbnailer fzf tumbler \
        zed zip unzip xdg-desktop-portal-hyprland waybar xcursor-vanilla-dmz \
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
end
