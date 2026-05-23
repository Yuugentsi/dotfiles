# ─────────── shell ───────────
set -g fish_greeting

# ─────────── functions ───────────
for f in ~/.config/fish/functions/*.fish
    source $f
end

# functions
function c; clear; end
function mkcd; mkdir -p $argv[1]; and cd $argv[1]; end
function gh; git clone $argv[1]; and cd (basename (string replace -r '\.git$' '' $argv[1])); end
function rd; set -l p (pwd); cd ..; rm -rf $p; end
function empty; set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l); find (pwd) -type d -empty -delete 2>/dev/null; echo "$n folders deleted"; end
function zipast; zip -r (basename $PWD).zip . > /dev/null; clear; du -h (basename $PWD).zip; end
function dt; clear; set -l now (date '+%s'); set -l midnight (date -d 'tomorrow 00:00:00' '+%s'); set -l left (math -s0 "$midnight - $now"); set -l h (math -s0 "$left / 3600"); set -l m (math -s0 "($left % 3600) / 60"); printf "󰔚 %s - 󰑔 %s - 󰕑 %sh%sm\n" (date '+%H:%M:%S') (date '+%m/%d/%Y') $h $m; end

# ─────────── prompt ───────────
function fish_prompt
    set -l last_status $status

    set -l status_color 20d0fc
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
# ─────────── ls ───────────
function ls
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




