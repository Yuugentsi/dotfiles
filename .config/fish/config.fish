# -------- init --------
fish_add_path -g $HOME/.local/bin

if status is-interactive
end

set -g fish_greeting

# -------- functions --------
for f in ~/.config/fish/functions/*.fish
    source $f
end

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

# fish_prompt = prompt
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
    set -l cmd (string shorten -m 60 -- "$argv[1]")
    if test $last_status -eq 0
        hyprctl notify 5 3000 "rgb(a6e3a1)" "✓ $cmd" >/dev/null 2>&1
    else
        hyprctl notify 3 4000 "rgb(f38ba8)" "✗ $cmd ($last_status)" >/dev/null 2>&1
    end
end

# -------- init --------
function init --description 'Install apps and fonts'
    set -l groups hypr hypr hypr hypr hypr hypr hypr hypr hypr hypr hypr \
        shell shell shell shell shell shell shell shell shell shell shell \
        apps apps apps apps apps apps apps apps apps \
        media media media media media \
        fonts fonts fonts fonts fonts fonts
    set -l pkgs hyprland hypridle hyprlock hyprpaper hyprshot hyprsunset waybar rofi xdg-desktop-portal xdg-desktop-portal-hyprland xcursor-vanilla-dmz \
        fish fd fzf jq zoxide nano zip unzip wl-clipboard cliphist imagemagick \
        kitty thunar gvfs tumbler ffmpegthumbnailer zed zathura zathura-cb qt6ct \
        mpv mpv-mpris playerctl swayimg yt-dlp \
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra

    if contains -- all $argv
        sudo pacman -S --needed --noconfirm $pkgs
        return $status
    end

    set -l cyan (set_color --bold 00e5ff)
    set -l pink (set_color --bold ff4fbd)
    set -l green (set_color 78ffb7)
    set -l dim (set_color 7b849c)
    set -l reset (set_color normal)

    set -l installed (pacman -Qq $pkgs 2>/dev/null)
    set -l rows
    set -l done_rows
    for i in (seq (count $pkgs))
        if contains -- $pkgs[$i] $installed
            set -a done_rows (printf '%s\t%s● %s%-6s %s%s' $pkgs[$i] $green $dim $groups[$i] $pkgs[$i] $reset)
        else
            set -a rows (printf '%s\t%s○%s %s%-6s%s %s' $pkgs[$i] $pink $reset $dim $groups[$i] $reset $pkgs[$i])
        end
    end
    set -l missing (count $rows)
    set -a rows $done_rows

    if not isatty stdin; or not isatty stdout; or not command -q fzf
        sudo pacman -S --needed --noconfirm $pkgs
        return $status
    end

    printf '\e[H\e[2J'
    set -l total (count $pkgs)
    set -l selection (printf '%s\n' $rows | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
        --ansi --multi --height=80% --layout=reverse --border=sharp \
        --border-label="  init · $missing/$total missing " --prompt='⌁ ' --pointer='▶' --marker='✓' \
        --header='Tab ✓ · Ctrl-A all · Ctrl-D none · Alt-M missing · ↵ install · Esc ×' \
        --delimiter='\t' --with-nth=2.. --no-sort \
        --bind='ctrl-a:select-all,ctrl-d:deselect-all' \
        --expect=alt-m \
        --color='bg+:#202039,fg+:#e6faff,border:#ff4fbd,label:#00e5ff,pointer:#00e5ff,marker:#78ffb7,prompt:#ff4fbd,hl:#ffd166,hl+:#ffd166,info:#7b849c,header:#7b849c')
    or return 0

    set -l chosen
    if test "$selection[1]" = alt-m
        for p in $pkgs
            contains -- $p $installed; or set -a chosen $p
        end
    else
        for line in $selection[2..]
            set -a chosen (string split -m1 \t -- $line)[1]
        end
    end
    test -n "$chosen[1]"; or return 0

    printf '\n  %s╱╱ %s %s%d selected%s\n' $cyan $reset $dim (count $chosen) $reset
    printf '  %s%s%s\n\n' $dim (string join ' ' -- $chosen) $reset
    sudo pacman -S --needed --noconfirm $chosen
end
# -------- aliases --------

# 0 = home folder
abbr 0 "cd ~/0"
# documents = documents
alias documents="cd ~/0/documents"
# music = music
alias music="cd ~/0/music"
# pictures = pictures
alias pictures="cd ~/0/pictures"
# videos = videos
alias videos="cd ~/0/videos"

# myip = ip and dns
alias myip="echo -n 'IP:  '; ip -4 -o a show | awk '/inet / && !/127.0.0.1/{print \$4}' | cut -d/ -f1 | head -1; echo -n 'DNS: '; awk '/^nameserver/{print \$2}' /etc/resolv.conf | head -1"

# .venv = project venv
function .venv -d "project venv"; set -l env "$PWD/.venv"; if test "$VIRTUAL_ENV" = "$env"; deactivate; or return $status; clear; echo "venv off: $env"; return 0; end; if not test -f "$env/bin/activate.fish"; python3 -m venv "$env"; or return $status; end; source "$env/bin/activate.fish"; or return $status; if test -f requirements.txt; echo "installing requirements.txt..."; python -m pip install -r requirements.txt; or return $status; end; clear; echo "venv on: $env"; end
# .venvd = remove project venv
function .venvd -d "delete venv"; set -l env "$PWD/.venv"; if not test -e "$env"; and not test -L "$env"; echo "no .venv in this directory"; return 1; end; if test "$VIRTUAL_ENV" = "$env"; deactivate; or return $status; end; command rm -rf -- "$env"; or return $status; echo "deleted: $env"; end
# venv = global venv
function venv -d "global venv"; set -l green (set_color green); set -l red (set_color red); set -l reset (set_color normal); set -l env "$HOME/.venv"; if test -n "$VIRTUAL_ENV"; deactivate; clear; echo -s $red "󰄬 venv off" $reset; else; if not test -d "$env"; python3 -m venv "$env"; end; source "$env/bin/activate.fish"; if test -f requirements.txt; echo -s $green "  installing requirements.txt..." $reset; pip install -q -r requirements.txt; end; clear; echo -s $green "󰄬 venv on" $reset; end; end
# py = run python
function py; test -z "$VIRTUAL_ENV"; and venv; if test -n "$argv"; python3 $argv; else if test -f main.py; python3 main.py; else if test -f bot.py; python3 bot.py; else; python3 main.py; end; end

# pi = pip install
function pi -d "pip install in project venv"; if test "$VIRTUAL_ENV" != "$PWD/.venv"; .venv; or return $status; end; pip install $argv; end

# update = system update
function update -d "upgrade system packages"; sudo pacman -Syyu; end

# internet = toggle network
function internet -d "toggle network access"; if not command -q nmcli; printf 'internet: nmcli not found\n' >&2; return 1; end; set -l state (nmcli networking); if test "$state" = enabled; nmcli networking off; or return $status; echo "network disconnected"; else; nmcli networking on; or return $status; echo "network reconnected"; end; end
