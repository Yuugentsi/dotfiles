# ─────────── shell ───────────
set -g fish_greeting

# ─────────── functions ───────────
for f in ~/.config/fish/functions/*.fish
    source $f
end

# functions
function c; clear; end
function mkcd; mkdir -p $argv[1]; and cd $argv[1]; end
#function gh; git clone $argv[1]; and cd (basename (string replace -r '\.git$' '' $argv[1])); end
function rd; set -l p (pwd); cd ..; rm -rf $p; end
function empty; set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l); find (pwd) -type d -empty -delete 2>/dev/null; echo "$n folders deleted"; end
function zipast; zip -r (basename $PWD).zip . > /dev/null; clear; du -h (basename $PWD).zip; end
function dt; clear; set -l now (date '+%s'); set -l midnight (date -d 'tomorrow 00:00:00' '+%s'); set -l left (math -s0 "$midnight - $now"); set -l h (math -s0 "$left / 3600"); set -l m (math -s0 "($left % 3600) / 60"); printf "󰔚 %s - 󰑔 %s - 󰕑 %sh%sm\n" (date '+%H:%M:%S') (date '+%m/%d/%Y') $h $m; end

# ─────────── prompt ───────────
function fish_prompt
    set -l last_status $status

    set -l status_color f5c2e7
    if test $last_status -ne 0
        set status_color ff6b8a
    end

    set -l parts (string split / (string replace -r "^$HOME/" "" "$PWD"))
    set -l pwd (string join / $parts[-2..-1])
    string match -q "$HOME" "$PWD"; and set pwd "~"

    echo -n -s \
        (set_color c8b8de --bold) $pwd " " \
        (set_color $status_color --bold) "❯ " \
        (set_color normal)
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
