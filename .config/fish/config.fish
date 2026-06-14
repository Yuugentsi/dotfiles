# ──────── shell ────────
# c          clear screen
# mkcd       create & enter dir
# rd         remove current dir
# empty      delete empty folders
# zipast     zip current folder
# dt         show date/time
# min        time until next hour
# bak          backup config dir
# note         append note to ~/notes.txt
# volume 100    set audio volume
# ───────────────────────
set -g fish_greeting

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

# ─────────── pager ───────────
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

# ─────────── zoxide ───────────
if command -q zoxide
    zoxide init fish | source
end

# ─────────── functions ───────────
for f in ~/.config/fish/functions/*.fish
    source $f
end

# --- functions ---
abbr -a c clear
# --- mkdir
function mkcd; mkdir -p $argv[1]; and cd $argv[1]; end
#function gh; git clone $argv[1]; and cd (basename (string replace -r '\.git$' '' $argv[1])); end
# --- clear
function rd; clear; set -l p (pwd); cd ..; read -l -P "󰅙 rm -rf $p ? [y/N] " confirm; test "$confirm" = y; and rm -rf $p; and clear; and echo "󰄬 deleted $p"; end
# --- empty
function empty; set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l); find (pwd) -type d -empty -delete 2>/dev/null; echo "$n folders deleted"; end
# --- zip
function zipast; zip -r (basename $PWD).zip . > /dev/null; clear; du -h (basename $PWD).zip; end
# --- time ---
function dt; clear; set -l now (date '+%s'); set -l midnight (date -d 'tomorrow 00:00:00' '+%s'); set -l left (math -s0 "$midnight - $now"); set -l h (math -s0 "$left / 3600"); set -l m (math -s0 "($left % 3600) / 60"); printf "󰔚 %s - 󰑔 %s - 󰕑 %sh%sm\n" (date '+%H:%M:%S') (date '+%m/%d/%Y') $h $m; end
# ---
function min; set -l n (date +%s); set -l h (date +%H); set -l nx (math "$h + 1"); set -l nxh (date -d "$nx:00:00" +%s); set -l l (math "$nxh - $n"); set -l m (math -s0 "$l / 60"); set -l s (math -s0 "$l % 60"); clear; echo "󰔚 $m min $s sec"; end
# --- volume ---
function volume; clear; set -q argv[1]; and set p $argv[1]; or set p 100; wpctl set-volume @DEFAULT_AUDIO_SINK@ (math "min(max($p, 30), 110) / 100"); end
# ---
function bak -d "backup dir to bak/"; set -l d (pwd); if set -q argv[1]; set d (realpath "$argv[1]"); end; mkdir -p "$d/bak"; for f in "$d"/*; test "$f" != "$d/bak"; and cp -r "$f" "$d/bak/"; end; clear; and echo "󰄬 $d/bak"; end

# ─────────── note ───────────
function note
    set -l file ~/notes.txt

    if set -q argv[1]
        set -l t (date "+%H:%M:%S")

        echo "─── $t ───" >> $file
        echo (string join " " -- $argv) >> $file
    end

    clear
    tail -10 $file
end
# ─────────── prompt ───────────
set -g fish_transient_prompt 1

function fish_prompt
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

    echo -s "$DIM╭─$N $DIR $pwd$N"
    echo -n -s "$DIM╰─$N " (set_color $status_color --bold) "ᗧ " (set_color normal)
end
# ─────────── venv ───────────
function venv
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
# --- venv requirements ---
function venvr; set -l req "$PWD/requirements.txt"; if not test -f "$req"; echo "requirements.txt not found"; return 1; end; venv; pip install -r "$req"; end
# ─────────── help ───────────
function h -d "list functions"
    set -l N (set_color normal)
    set -l colors \
        (set_color cba6f7) \
        (set_color a6e3a1) \
        (set_color 89b4fa) \
        (set_color f9e2af) \
        (set_color f38ba8) \
        (set_color 89dceb) \
        (set_color f5c2e7) \
        (set_color fab387)

    set -l skip _config_backup fish_command_not_found __extra_cnf

    set -l dir "$HOME/.config/fish/functions"
    set -l files (command ls -1 "$dir"/*.fish 2>/dev/null)

    if test -z "$files"
        echo "no functions found"
        return 1
    end

    set -l sections

    for file in $files
        set -l fname (basename "$file" .fish)
        set -l entries (grep -E "^function " "$file" 2>/dev/null)

        if test -z "$entries"
            continue
        end

        set -l visible
        for entry in $entries
            set -l name (string match -rg '^function\s+(\S+)' -- "$entry")
            if test -n "$name"; and contains -- "$name" $skip
                continue
            end
            if test -n "$name"; and string match -qr '^__' -- "$name"
                continue
            end
            set -a visible $entry
        end

        set -l count (count $visible)
        if test $count -eq 0
            continue
        end

        set -a sections "$count|$fname|"(string join '§' $visible)
    end

    set -l total_files (count $sections)
    set -l total_funcs 0
    for s in $sections
        set -l first (string split '|' $s)[1]
        set total_funcs (math $total_funcs + $first)
    end

    echo ""
    echo "  Fish Functions"
    echo ""

    set -l sorted (printf '%s\0' $sections | sort -t'|' -k1 -rn -z | string split0)
    set -l idx 0

    for section in $sorted
        set -l parts (string split '|' $section)
        set -l count $parts[1]
        set -l fname $parts[2]
        set -l entries_str $parts[3]
        set -l visible (string split '§' $entries_str)
        set idx (math $idx + 1)
        set -l c $colors[(math $idx % 8 + 1)]

        echo ""
        echo "$c━━━ $fname.fish ━━━$N"

        set -l i 0
        for entry in $visible
            set -l i (math $i + 1)
            set -l name (string match -rg '^function\s+(\S+)' -- "$entry")
            set -l desc (string match -rg -- '-(?:description|d)\s+[\x27"]([^\x27"]+)[\x27"]' -- "$entry")
            if test $i -eq $count
                if test -n "$desc"
                    printf "  $c└── %s$N → %s\n" "$name" "$desc"
                else
                    printf "  $c└── %s$N\n" "$name"
                end
            else
                if test -n "$desc"
                    printf "  $c├── %s$N → %s\n" "$name" "$desc"
                else
                    printf "  $c├── %s$N\n" "$name"
                end
            end
        end
    end

    echo ""
    printf "  · %s ·\n" (string repeat -n 40 '·')
    printf "  %s · %s\n" "$total_funcs funcs" "$total_files files"
    echo ""
end
# ─────────── ls ───────────
function l
    set -e folders zip audio video images text lua other

    for item in *
        if test -d $item
            set folders $folders " $item/"
        else if test -f $item
            switch $item
                case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                    set zip $zip " $item"
                case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                    set audio $audio " $item"
                case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                    set video $video " $item"
                case "*.txt" "*.md" "*.rst" "*.log"
                    set text $text " $item"
                case "*.lua"
                    set lua $lua " $item"
                case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                    set images $images " $item"
                case "*"
                    set other $other " $item"
            end
        end
    end

    _section brblue  " folders ($(count $folders))" $folders
    _section yellow  " zip ($(count $zip))"         $zip
    _section magenta " audio ($(count $audio))"     $audio
    _section magenta " video ($(count $video))"     $video
    _section yellow  " images ($(count $images))"   $images
    _section brgreen " text ($(count $text))"       $text
    _section cyan    " lua ($(count $lua))"         $lua
    _section white   " other ($(count $other))"     $other
end

function _section
    set -l color $argv[1]
    set -l title $argv[2]
    set -e argv[1]
    set -e argv[1]
    set -l items $argv

    if test (count $items) -eq 0
        return
    end

    set_color $color
    echo "$title"
    _grid $items
    set_color normal
    echo
end

function _grid
    set -l items $argv
    set -l i 1
    set -l c (count $items)

    while test $i -le $c
        set -l a $items[$i]
        set -l next (math $i + 1)

        if test $next -le $c
            set -l b $items[$next]
            if test (string length $a) -gt 42; or test (string length $b) -gt 42
                echo "  $a"
                echo "  $b"
            else
                printf "  %-42s │ %s\n" $a $b
            end
        else
            echo "  $a"
        end

        set i (math $i + 2)
    end
end
