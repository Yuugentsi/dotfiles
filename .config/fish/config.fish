# ───────── config ─────────
# │
# ├── abbr
# │   └── c    clear
# │
# ├── mkcd     mkdir + cd
# ├── rd       rm -rf current dir
# ├── empty    delete empty dirs
# ├── zipast   zip current dir
# ├── dt       date & time
# ├── min      minutes to next hour
# ├── volume   set audio volume
# │
# ├── bak      backup dir to bak/
# │
# ├── pw       copy pwd to clipboard
# │
# ├── prompt   custom prompt
# └── zoxide   smart cd

set -g fish_greeting

# ── path
fish_add_path ~/.local/bin

# ── prompt
set -g fish_transient_prompt 1

function fish_prompt -d "custom prompt"
    if set -q argv[1]
        echo -n "ᗧ "
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
    set -l DIR (set_color a89cc8 --bold)
    set -l N (set_color normal)

    echo -s "$DIM╭─$N $DIR $pwd$N"
    echo -n -s "$DIM╰─$N " (set_color $status_color --bold) "ᗧ " (set_color normal)
end

# ── zoxide
if command -q zoxide
    zoxide init fish | source
end

# ─────────── syntax highlight ───────────
set -g fish_color_normal cdd6f4
set -g fish_color_command 89b4fa
set -g fish_color_keyword cba6f7
set -g fish_color_quote a6e3a1
set -g fish_color_redirection fab387
set -g fish_color_end f5c2e7
set -g fish_color_error f38ba8 --bold
set -g fish_color_param cdd6f4
set -g fish_color_valid_path --underline
set -g fish_color_option f9e2af
set -g fish_color_comment 6c7086
set -g fish_color_selection --background=585b70
set -g fish_color_operator f5c2e7
set -g fish_color_escape f5c2e7
set -g fish_color_autosuggestion 585b70
set -g fish_color_cwd 89b4fa
set -g fish_color_cwd_root f38ba8
set -g fish_color_user a6e3a1
set -g fish_color_host 89b4fa
set -g fish_color_host_remote f9e2af
set -g fish_color_status f38ba8
set -g fish_color_cancel f5c2e7
set -g fish_color_search_match --background=585b70
set -g fish_color_history_current 94e2d5

# ── pager
set -g fish_pager_color_progress cba6f7
set -g fish_pager_color_prefix 89b4fa
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086
set -g fish_pager_color_selected_background 313244
set -g fish_pager_color_selected_prefix b4befe
set -g fish_pager_color_selected_completion cdd6f4
set -g fish_pager_color_selected_description a6adc8
set -g fish_pager_color_secondary_background 1e1e2e
set -g fish_pager_color_secondary_prefix 89b4fa
set -g fish_pager_color_secondary_completion cdd6f4
set -g fish_pager_color_secondary_description 6c7086

# ── functions
for f in ~/.config/fish/functions/*.fish
    source $f
end

abbr -a c clear

# ── mkcd
function mkcd -d "mkdir and cd"
    mkdir -p $argv[1]; and cd $argv[1]
end

# ── rd
function rd -d "remove current dir"
    clear
    set -l p (pwd)
    cd ..
    read -l -P "󰅙 rm -rf $p ? [y/N] " confirm
    test "$confirm" = y; and rm -rf $p; and clear; and echo "󰄬 deleted $p"
end

# ── empty
function empty -d "delete empty dirs"
    set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l)
    find (pwd) -type d -empty -delete 2>/dev/null
    echo "$n folders deleted"
end

# ── zipast
function zipast -d "zip current dir"
    zip -r (basename $PWD).zip . > /dev/null
    clear
    du -h (basename $PWD).zip
end

# ── dt
function dt -d "date and time"
    clear
    set -l now (date '+%s')
    set -l midnight (date -d 'tomorrow 00:00:00' '+%s')
    set -l left (math -s0 "$midnight - $now")
    set -l h (math -s0 "$left / 3600")
    set -l m (math -s0 "($left % 3600) / 60")
    printf "󰔚 %s - 󰑔 %s - 󰕑 %sh%sm\n" (date '+%H:%M:%S') (date '+%m/%d/%Y') $h $m
end

# ── min
function min -d "minutes to next hour"
    set -l n (date +%s)
    set -l h (date +%H)
    set -l nx (math "$h + 1")
    set -l nxh (date -d "$nx:00:00" +%s)
    set -l l (math "$nxh - $n")
    set -l m (math -s0 "$l / 60")
    set -l s (math -s0 "$l % 60")
    clear
    echo "󰔚 $m min $s sec"
end

# ── volume
function volume -d "set audio volume"
    clear
    set -q argv[1]; and set p $argv[1]; or set p 100
    wpctl set-volume @DEFAULT_AUDIO_SINK@ (math "min(max($p, 30), 110) / 100")
end

# ── pw
function pw -d "copy pwd to clipboard"
    echo -n "'"(pwd)"'" | wl-copy
end

# ── gcbz
function gcbz -d "gallery-dl --cbz"
    gallery-dl --cbz $argv
end

# ── venv
function venv -d "toggle python venv"
    set -l green (set_color green)
    set -l red (set_color red)
    set -l reset (set_color normal)
    set -l env "$HOME/.venv"

    if test -n "$VIRTUAL_ENV"
        deactivate
        clear
        echo -s $red "󰄬 venv off" $reset
    else
        if not test -d "$env"
            python3 -m venv "$env"
        end
        source "$env/bin/activate.fish"
        clear
        echo -s $green "󰄬 venv on" $reset
    end
end

if status is-interactive
end

# ── bak
function bak -d "backup dir to bak/"
    set -l d (pwd)
    if set -q argv[1]
        set d (realpath "$argv[1]")
    end
    mkdir -p "$d/bak"
    for f in "$d"/*
        test "$f" != "$d/bak"; and cp -r "$f" "$d/bak/"
    end
    clear
    and echo "󰄬 $d/bak"
end
