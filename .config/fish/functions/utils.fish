# ───────── utils ─────────
# │
# ├── n         neovim
# │
# ├── mu        play music
# │
# ├── power     power menu
# ├── sunset    screen warmth
# ├── playing   now playing
# │
# ├── clip      clipboard
# ├── mem       memory monitor
# ├── del       remove packages
# ├── pomodoro  15min timer
# ├── merge     move files up
# ├── lf        list files
# ├── search    find files by name
# ├── word      word search
# │
# ├── lrc       embed lyrics
# ├── past      thunar bookmarks
# ├── font      switch fonts
# ├── ps        delete config dirs
# ├── nodisplay hide/show desktop apps
# │
# ├── archives
# │   ├── cbz       create .cbz
# │   ├── extract   extract archives
# │   └── zips      zip directory
# │
# ├── venv     toggle ~/.venv
# ├── venvr    venv + requirements
# ├── venvl    toggle local .venv
# ├── venvreq  generate requirements.txt
# ├── venvall  list all venvs
# ├── venvrmall remove all venvs
# │
# ├── clients   hyprctl clients
# └── at        push to SD
# ─────────── n ───────────
function n -d "neovim"
    nvim $argv
end

# ─────────── music ───────────
set -g MU_PURPLE (set_color cba6f7)
set -g MU_GREEN (set_color a6e3a1)
set -g MU_BLUE (set_color 89b4fa)
set -g MU_DIM (set_color brblack)
set -g MU_RESET (set_color normal)

function mu -d "play music"
    pkill -9 mpv 2>/dev/null
    sleep 0.1
    clear

    set music_dir "$HOME/0/music"
    if not test -d "$music_dir"
        set music_dir "$HOME/music"
    end
    if not test -d "$music_dir"
        set music_dir (pwd)
    end

    if test (count $argv) -gt 0
        set artist (string join ' ' $argv)
        set search_path "$music_dir/$artist"
    else
        set search_path "$music_dir"
    end

    if test -d "$search_path"
        set files (find "$search_path" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.m4a" -o -name "*.ogg" \) 2>/dev/null)
    else
        set files (find "$music_dir" -maxdepth 1 -type d -iname "*$artist*" -exec find {} -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.m4a" -o -name "*.ogg" \) \; 2>/dev/null)
    end

    if test -z "$files"
        echo "$MU_PURPLE✦ Not found$MU_RESET"
        return 1
    end

    set total (printf '%s\n' $files | wc -l)
    echo "$MU_DIM-- $total songs --$MU_RESET"

    set -l counts
    for a in (ls -1 "$music_dir" 2>/dev/null)
        set count (find "$music_dir/$a" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.wav" -o -name "*.m4a" -o -name "*.ogg" \) 2>/dev/null | wc -l)
        if test $count -gt 0
            set -a counts "$count $a"
        end
    end

    for line in (printf '%s\n' $counts | sort -rn)
        set -l c (string split ' ' $line)
        echo "$MU_PURPLE♪ $c[2..-1]$MU_DIM ($c[1])$MU_RESET"
    end

    set playlist_file /tmp/mu_playlist.m3u
    printf '%s\n' $files | shuf > $playlist_file
    nohup mpv --no-video --loop-playlist=no "$playlist_file" > /dev/null 2>&1 &
end

# ─────────── power ───────────
function power -d "power menu"
    set -l R (set_color red)
    set -l Y (set_color yellow)
    set -l P (set_color cba6f7)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    echo "$D󰐥 Power$N"
    echo "  [1] $R󰐥 shutdown$N"
    echo "  [2] $Y󰜉 reboot$N"
    echo "  [3] $P󰍃 logout$N"
    echo "$D  [0] 󰜺 exit$N"
    read -P "→ " choice

    switch $choice
        case 1
            systemctl poweroff
        case 2
            systemctl reboot
        case 3
            hyprctl dispatch exit
        case 0 ''
            return 0
    end
end

# ─────────── sunset ───────────
function sunset -d "hyprsunset"
    if not pgrep -x hyprsunset >/dev/null
        hyprsunset >/dev/null 2>&1 &
        disown $last_pid
        sleep 0.2
    end

    switch $argv[1]
        case off reset
            hyprctl hyprsunset identity
            hyprctl hyprsunset gamma 100
            clear
        case warm
            set -l temp (random 1900 2600)
            set -l gam (random 40 60)
            hyprctl hyprsunset temperature $temp
            hyprctl hyprsunset gamma $gam
            clear
        case gamma
            hyprctl hyprsunset gamma $argv[2]
            clear
        case ''
            echo "warm"
            echo "3000"
            echo "gamma 60"
            echo "reset"
        case '*'
            hyprctl hyprsunset temperature $argv[1]
            clear
    end
end

# ─────────── playing ───────────
function playing -d "now playing"
    if not command -q playerctl
        echo "playerctl not installed"
        return 1
    end

    clear
    tput civis

    set -l cover /tmp/nowplaying_cover.jpg
    set -l P (set_color cba6f7)
    set -l G (set_color a6e3a1)
    set -l B (set_color 89b4fa)
    set -l M (set_color brmagenta)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    while true
        set -l artist (playerctl metadata xesam:artist 2>/dev/null)
        set -l album  (playerctl metadata xesam:album 2>/dev/null)
        set -l title  (playerctl metadata xesam:title 2>/dev/null)

        set -l length_us (playerctl metadata mpris:length 2>/dev/null)
        set -l pos_sec (playerctl position 2>/dev/null)

        if test -z "$pos_sec"
            set pos_sec 0
        end

        set -l total_sec 0
        if test -n "$length_us"
            set total_sec (math "$length_us / 1000000")
        end

        set -l percent 0
        if test $total_sec -gt 0
            set percent (math "$pos_sec / $total_sec")
        end

        set -l width 30
        set -l pos (math -s0 "$percent * $width")
        set -l bar ""
        for i in (seq 0 (math "$width - 1"))
            if test $i -eq $pos
                set bar "$bar$P●$N"
            else
                set bar "$bar "
            end
        end

        set -l url (playerctl metadata xesam:url 2>/dev/null)
        set -l media_path (string replace "file://" "" -- $url)
        set media_path (string unescape --style=url $media_path)

        if test -f "$media_path"
            ffmpeg -loglevel quiet -y -i "$media_path" -an -vcodec copy "$cover"
        end

        tput cup 0 0
        tput el
        echo "$B󰝚 $artist$N"
        tput el
        echo "$P󰏤 $album$N"
        tput el
        echo "$G󰎆 $title$N"
        tput el

        set -l cur_m (math -s0 "$pos_sec / 60")
        set -l cur_s (math -s0 "$pos_sec % 60")

        set -l tot_m 0
        set -l tot_s 0
        if test $total_sec -gt 0
            set tot_m (math -s0 "$total_sec / 60")
            set tot_s (math -s0 "$total_sec % 60")
        end

        tput cup 4 0
        tput el
        echo -ns "$M󰏫 "(printf "%02d:%02d / %02d:%02d" $cur_m $cur_s $tot_m $tot_s)"$N"

        tput cup 5 0

        if test -f "$cover"
            kitty +kitten icat --clear >/dev/null 2>&1
            kitty +kitten icat --place 30x15@0x5 "$cover"
        else
            kitty +kitten icat --clear >/dev/null 2>&1
        end

        tput cup 19 0
        tput el
        echo "$bar"

        sleep 0.4
    end
end


# ─────────── clip ───────────
function clip -d "clipboard manager"
    switch "$argv[1]"
        case clear
            cliphist wipe
            echo "clipboard cleared"
        case images
            set -l sel (cliphist list | grep -i 'image/\|png\|jpg\|jpeg\|gif\|webp\|bmp' | fzf \
                --exact \
                --prompt="󰋩 img > " \
                --border=rounded \
                --margin=1 \
                --padding=1 \
                --info=inline \
                --no-multi \
                --height=40% \
                --layout=reverse \
                --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
            if test -n "$sel"
                echo "$sel" | cliphist decode | wl-copy
            end
        case last
            cliphist list | head -1 | cliphist decode | wl-copy
            echo "󰄬 last copied"
        case count
            set -l n (cliphist list | wc -l)
            echo "󰅍 $n items in clipboard"
        case pin
            set -l sel (cliphist list | fzf \
                --exact \
                --prompt="󰸗 pin > " \
                --border=rounded \
                --margin=1 \
                --padding=1 \
                --info=inline \
                --no-multi \
                --height=40% \
                --layout=reverse \
                --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
            if test -n "$sel"
                set -l pinned "$HOME/.cache/scripts/clipboard/pinned"
                mkdir -p (dirname "$pinned")
                echo "$sel" >> "$pinned"
                echo "󰸗 pinned"
            end
        case url
            set -l sel (cliphist list | grep -E 'https?://|ftp://' | fzf \
                --exact \
                --prompt="󰖟 url > " \
                --border=rounded \
                --margin=1 \
                --padding=1 \
                --info=inline \
                --no-multi \
                --height=40% \
                --layout=reverse \
                --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
            if test -n "$sel"
                echo "$sel" | cliphist decode | wl-copy
            end
        case uninstall
            set -l sel (sudo apk list --installed 2>/dev/null | string replace -r '^.+- ' '' | fzf \
                --exact \
                --prompt="󰛗 uninstall > " \
                --border=rounded \
                --margin=1 \
                --padding=1 \
                --info=inline \
                --multi \
                --height=60% \
                --layout=reverse \
                --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
            if test -n "$sel"
                printf '%s\n' $sel | wl-copy
                echo "copied: $sel"
            end
        case ''
            set -l sel (cliphist list | fzf \
                --exact \
                --prompt="󰆵 clip > " \
                --preview "cliphist decode {1} 2>/dev/null | head -50" \
                --preview-window='right:50%:wrap' \
                --border=rounded \
                --margin=1 \
                --padding=1 \
                --info=inline \
                --no-multi \
                --height=60% \
                --layout=reverse \
                --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
            if test -n "$sel"
                echo "$sel" | cliphist decode | wl-copy
            end
        case '*'
            echo "󰆵 clip [clear|images|last|count|pin|url]"
    end
end
# ─────────── mem ───────────
function mem -d "memory"
    set -l P (set_color cba6f7)
    set -l G (set_color a6e3a1)
    set -l R (set_color f38ba8)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    while true
        clear
        set -l total (math -s0 (cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 1024)
        set -l avail (math -s0 (cat /proc/meminfo | grep MemAvailable | awk '{print $2}') / 1024)
        set -l used (math "$total - $avail")
        set -l pct (math -s0 "$used * 100 / $total")

        echo ""
        echo "    Name              Mem     RAM"
        echo "    ─────────────────────────────"
        ps aux | awk 'NR>1 {
            cmd = $11; gsub(/.*\//,"",cmd); gsub(/^-/,"",cmd);
            mem[cmd] += $4; rss[cmd] += $6
        } END {
            for (c in mem) printf "%.1f %d %s\n", mem[c], rss[c], c
        }' | sort -k1 -rn | head -5 | awk -v P="$P" -v R="$R" -v N="$N" '{
            cmd = $3; for(i=4;i<=NF;i++) cmd = cmd " " $i
            mem = $1; rss = $2/1024
            color = (mem+0 > 5) ? R : P
            printf "    %s󰘚 %-14s %5.1f%%  %6.0fM%s\n", color, cmd, mem, rss, N
        }'

        set -l wave "⣀⣄⣤⣶⣷⣾⣿⣾⣷⣶⣤⣄⣀"
        set -l wave_len 14
        set -l bar ""
        for i in (seq 1 30)
            set -l pos (math -s0 "($i - 1) * 100 / 30")
            if test $pos -le $pct
                set -l idx (math -s0 "($i % $wave_len) + 1")
                set bar "$bar$P"(string sub -s $idx -l 1 $wave)"$N"
            else
                set bar "$bar$D░$N"
            end
        end
        echo ""
        echo "    $bar $G$pct%$N — $used/$total MB"
        sleep 2
    end
end
# ─────────── del ───────────
function del -d "remove packages"
    set -l sel (pacman -Qq | fzf \
        --exact \
        --prompt="󰛗 del > " \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --info=inline \
        --multi \
        --height=60% \
        --layout=reverse-list \
        --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)
    if test -n "$sel"
        printf '%s\n' $sel | wl-copy
        echo "󰛗"
    end
end
# ─────────── pomodoro ───────────
function pomodoro -d "pomodoro"
    set -l total 1500
    if test $total -ge 60
        set -l m (math -s0 "$total / 60")
        set -l label "$m"m
    else
        set -l label "$total"s
    end

    if set -q argv[1]; and test "$argv[1]" = "rm"
        rm -f /tmp/pomodoro
        echo "pomodoro cancelled"
        return
    end

    set -l file /tmp/pomodoro
    set -q POMODORO_LOG; or set POMODORO_LOG "$HOME/0/documents"
    set -l logdir $POMODORO_LOG

    if test -e $file
        set -l end (cat $file)
        set -l now (date '+%s')
        set -l left (math -s0 "$end - $now")

        if test $left -gt $total
            rm $file
            set -l end (math -s0 (date '+%s') + $total)
            echo $end > $file
            set -l start (date '+%H:%M:%S')
            set -l endf (date -d "@$end" '+%H:%M:%S')
            echo "󰔚 $start - $endf - 󰔚 $label"
            return
        end

        set -l start_ts (math "$end - $total")
        set -l start_f (date -d "@$start_ts" '+%H:%M:%S')
        set -l end_f (date -d "@$end" '+%H:%M:%S')

        if test $left -gt 0
            clear
            set -l done (math -s0 "$total - $left")
            set -l pct (math -s0 "$done * 100 / $total")
            set -l width 30
            set -l filled (math -s0 "$pct * $width / 100")
            set -l bar ""
            for i in (seq $width)
                if test $i -le $filled
                    set bar "$bar█"
                else
                    set bar "$bar░"
    end
end

            echo "󰔚 $start_f - $end_f - 󰔚 $left"s
            hyprctl notify 5 4000 "rgb(cba6f7)" "fontsize:18 󰔚  $start_f - $end_f - $left"s >/dev/null 2>&1
            echo "$bar $pct%"
        else
            echo "󰔚  pomodoro"
            hyprctl notify 5 4000 "rgb(cba6f7)" "fontsize:18 󰔚  pomodoro" >/dev/null 2>&1

            mkdir -p $logdir
            set -l bar ""
            for i in (seq 30)
                set bar "$bar█"
            end
            echo "󰔚 $start_f - $end_f" >> $logdir/pomodoro.txt
            echo "$bar 100%" >> $logdir/pomodoro.txt
            echo "-------------------------------" >> $logdir/pomodoro.txt
            rm $file
        end
    else
        set -l end (math -s0 (date '+%s') + $total)
        echo $end > $file
        set -l start (date '+%H:%M:%S')
        set -l endf (date -d "@$end" '+%H:%M:%S')
        hyprctl notify 5 4000 "rgb(cba6f7)" "fontsize:18 󰔚  $start - $endf" >/dev/null 2>&1
        nohup fish -c "
            sleep $total
            if test -f $file
                set -l end (cat $file)
                set -l start_ts (math \"\$end - $total\")
                set -l start_f (date -d @\$start_ts '+%H:%M:%S')
                set -l end_f (date -d @\$end '+%H:%M:%S')
                set -l bar ''
                for i in (seq 30); set bar \"\$bar█\"; end
                mkdir -p $logdir
                echo \"󰔚 \$start_f - \$end_f\" >> $logdir/pomodoro.txt
                echo \"\$bar 100%\" >> $logdir/pomodoro.txt
                echo ------------------------------- >> $logdir/pomodoro.txt
                hyprctl notify 5 4000 'rgb(cba6f7)' 'fontsize:18 󰔚  pomodoro'
                rm -f $file
            end
        " >/dev/null 2>&1 &
        disown
        echo "󰔚 $start - $endf - 󰔚 $label"
    end
end
# ─────────── merge ───────────
function merge -d "merge folders"
    set -l target (string trim -r -c '/' -- $argv[1])
    if test -z "$target"
        set target (pwd)
    end
    if not test -d "$target"
        echo "not a directory: $target"
        return 1
    end

    for dir in "$target"/*/
        set dir (string trim -r -c '/' -- "$dir")
        test -d "$dir" || continue

        find "$dir" -mindepth 1 -type f | while read -l f
            set -l base (basename "$f")
            mv -n "$f" "$dir/$base"
        end

        find "$dir" -mindepth 1 -type d -empty -delete
    end

    echo "done: $target"
end

# ─────────── lf ───────────
function lf -d "list files"
    set -l N (set_color normal)
    set -l P (set_color cba6f7)

    set -l target "."
    if test (count $argv) -ge 1
        set target $argv[1]
    end

    if not test -d "$target"
        echo "$P󰅙 not a directory$N"
        return 1
    end

    set -l files (command ls -1t "$target" 2>/dev/null)

    if test -z "$files"
        echo "$P󰉖 empty$N"
        return 0
    end

    for f in $files
        set -l full "$target/$f"
        if not test -f "$full"
            continue
        end

        set -l mdate (date -r "$full" "+%d/%m" 2>/dev/null)
        set -l mtime (date -r "$full" "+%H:%M:%S" 2>/dev/null)
        set -l lines (wc -l < "$full" 2>/dev/null | string trim)

        set -l c $P
        set -l icon ""
        switch $f
            case '*.lua'
                set icon ""
                set c (set_color cba6f7)
            case '*.sh' '*.bash' '*.zsh' '*.fish'
                set icon ""
                set c (set_color a6e3a1)
            case '*.conf' '*.cfg' '*.ini'
                set icon ""
                set c (set_color fab387)
            case '*.png' '*.jpg' '*.jpeg' '*.gif' '*.svg' '*.webp'
                set icon ""
                set c (set_color f9e2af)
            case '*.mp3' '*.wav' '*.flac' '*.ogg' '*.m4a'
                set icon ""
                set c (set_color f5c2e7)
            case '*.mp4' '*.mkv' '*.avi' '*.mov' '*.webm'
                set icon ""
                set c (set_color 89dceb)
            case '*.zip' '*.tar' '*.tar.gz' '*.tar.xz' '*.7z' '*.rar'
                set icon ""
                set c (set_color f38ba8)
            case '*.txt' '*.md' '*.rst'
                set icon ""
                set c (set_color a6adc8)
            case '*.json' '*.yaml' '*.yml' '*.toml'
                set icon ""
                set c (set_color 89b4fa)
            case '*.py'
                set icon ""
                set c (set_color 89b4fa)
            case '*.html' '*.css' '*.js' '*.ts' '*.jsx' '*.tsx'
                set icon ""
                set c (set_color fab387)
        end

        printf "%s %s:%s · %s  · %s\n" \
            "$c$icon$N" \
            "$c$f$N" \
            "$c$lines$N" \
            "$c$mdate$N" \
            "$c$mtime$N"
    end
end

# ─────────── search ───────────
function search -d "find files"
    set -e zip audio video images text lua other

    if test (count $argv) -eq 0
        echo "Usage: search <pattern> [path]"
        return 1
    end

    set -l pattern $argv[1]
    set -l base "$HOME"

    if test (count $argv) -ge 2 -a -n "$argv[2]"
        set base $argv[2]
    end

    if not test -d "$base"
        echo "Directory not found: $base"
        return 1
    end

    set -l N (set_color normal)
    set -l T (printf '\t')
    set -l colors cba6f7 f5c2e7 fab387 f9e2af a6e3a1 89b4fa 89dceb

    for file in (find "$base" -maxdepth 5 -iname "*$pattern*" -type f -not -path "*/.local/*" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/.cache/*" -not -path "*/.npm/*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/__pycache__/*" -not -path "*/.cargo/*" -not -path "*/.rustup/*" -not -path "*/.var/*" -not -path "*/.config/chrome/*" -not -path "*mozilla*" -not -path "*BraveSoftware*" -not -path "*/.ssh/*" -not -path "*/.wine/*" -not -path "*/.android/*" -not -path "*/BACKUP/*" -not -type l 2>/dev/null)
        set -l name (basename "$file")
        set -l mtime (date -r "$file" "+%d/%m · %H:%M:%S" 2>/dev/null)
        set -l dir (dirname "$file")
        set -l label "$dir"

        switch $file
            case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                set zip $zip "$label$T$T$name$T$mtime"
            case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                set audio $audio "$label$T$T$name$T$mtime"
            case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                set video $video "$label$T$T$name$T$mtime"
            case "*.txt" "*.md" "*.rst" "*.log"
                set text $text "$label$T$T$name$T$mtime"
            case "*.lua"
                set lua $lua "$label$T$T$name$T$mtime"
            case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                set images $images "$label$T$T$name$T$mtime"
            case "*"
                set other $other "$label$T$T$name$T$mtime"
        end
    end

    set -l ci 0
    for var in zip audio video images text lua other
        if test (count $$var) -eq 0
            continue
        end
        set -l icon (string split $T -- $$var[1])[2]
        echo "$icon $var ("(count $$var)")"
        set -l prev_label ""
        for entry in $$var
            set -l parts (string split $T -- $entry)
            if test "$parts[1]" != "$prev_label"
                set ci (math $ci + 1)
                set -l ci_mod (math $ci % 7 + 1)
                set -l c (set_color $colors[$ci_mod])
                echo ""
                echo "$c━━━ $parts[1]/ ━━━$N"
                set prev_label $parts[1]
            end
            echo "  $parts[2] $parts[3] · $parts[4]"
        end
        echo ""
    end
end
#
# ─────────── wallhaven ───────────
function fish_command_not_found --on-event fish_command_not_found
    if string match -qr '^https://wallhaven\.cc/' -- $argv[1]
        if not command -v gallery-dl >/dev/null 2>&1; echo "gallery-dl not found"; return; end
        if not command -v hyprctl >/dev/null 2>&1; echo "hyprctl not found"; return; end
        echo "  [1] 󰋱 wallpaper"; echo "  [2] 󰖯 blur"
        read -P "→ " c
        set -l Y (set_color yellow); set -l N (set_color normal); set -l G (set_color green); set -l R (set_color red)
        set -l cache $HOME/.cache/scripts/wallpapers; mkdir -p $cache
        echo -s "󱎫 " $Y "downloading..." $N
        set -l i (realpath (gallery-dl $argv[1] 2>&1 | tail -n1 | string replace -r '^#\s+' '') 2>/dev/null)
        if test -z "$i"; or not test -f "$i"; echo -s $R "download failed" $N; return; end
        if test "$c" = 2
            if not command -v magick >/dev/null 2>&1; and not command -v convert >/dev/null 2>&1; and not command -v gm >/dev/null 2>&1; echo -s $R "imagemagick not found" $N; return; end
            echo -s "󱎫 " $Y "blurring..." $N
            if command -v magick >/dev/null 2>&1; magick $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current
            else if command -v convert >/dev/null 2>&1; convert $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current
            else; gm convert $i -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 $cache/current; end
            if test $status -ne 0; echo -s $R "blur failed" $N; return; end
        else; cp -- $i $cache/current; end
        printf "%s\n" $cache/current > $cache/wallpaper
        printf "splash = false\nipc = true\npreload = %s\nwallpaper = ,%s,cover\n" $cache/current $cache/current > $cache/hyprpaper.conf
        if not pgrep -x hyprpaper >/dev/null; hyprpaper -c $cache/hyprpaper.conf >/tmp/hyprpaper-wl.log 2>&1 &; sleep 0.5; end
        hyprctl hyprpaper preload $cache/current >/dev/null 2>&1; or true
        hyprctl hyprpaper wallpaper ",$cache/current,cover" >/dev/null 2>&1
        hyprctl hyprpaper unload unused >/dev/null 2>&1; or true
        set -l s "wallpaper set"; if test "$c" = 2; set s "wallpaper set (blur)"; end
        echo -s $G "󰄬 $s" $N; hyprctl notify -1 2200 "rgb(cba6f7)" "󰄬 $s" >/dev/null 2>&1
        return
    end
    if type -q __extra_cnf; __extra_cnf $argv; and return; end
    __fish_default_command_not_found_handler $argv
end

# ─────────── word ───────────
function word -d "word search"
    set -e code markup text other

    set -l pattern
    if test (count $argv) -ge 1
        set pattern (string join ' ' $argv)
    else
        echo "Usage: word <pattern>"
        echo "Or:    word (then type pattern freely)"
        read -P "pattern: " -l pattern
        if test -z "$pattern"
            return 1
        end
    end
    set -l base "$HOME"

    if not test -d "$base"
        echo "Directory not found: $base"
        return 1
    end

    set -l N (set_color normal)
    set -l T (printf '\t')
    set -l colors cba6f7 f5c2e7 fab387 f9e2af a6e3a1 89b4fa 89dceb

    set -l skip .git/ .cache/ node_modules/ .venv/ venv/ __pycache__/ .cargo/ .rustup/ .var/ mozilla/ BraveSoftware/ .local/ .npm/ .ssh/ .wine/ .android/ BACKUP/

    set -l matches
    if command -v rg >/dev/null 2>&1
        set -l globs
        for dir in $skip
            set globs $globs -g "!$dir"
        end
        set matches (rg -ni --no-heading $globs -- "$pattern" "$base" 2>/dev/null)
    else
        set matches (grep -rni "$pattern" "$base" 2>/dev/null | string match -v -r '/\.(git|cache|npm|ssh|wine|android|local|cargo|rustup|var)/|/node_modules/|/\.venv/|/venv/|/__pycache__/|/mozilla/|/BraveSoftware/|/BACKUP/')
    end

    if test -z "$matches"
        return
    end

    for line in $matches
        set -l parts (string split -m 2 -- ':' "$line")
        set -l filepath $parts[1]
        set -l lineno $parts[2]
        set -l content $parts[3]

        set -l dir (dirname "$filepath")
        set -l name (basename "$filepath")

        switch $filepath
            case '*.lua' '*.py' '*.sh' '*.bash' '*.zsh' '*.fish' '*.js' '*.ts' '*.jsx' '*.tsx' '*.go' '*.rs' '*.c' '*.h' '*.cpp' '*.hpp' '*.java' '*.kts' '*.swift' '*.rb' '*.php' '*.pl' '*.r' '*.m' '*.mm'
                set code $code "$dir$T$T$name:$lineno$T$content"
            case '*.html' '*.css' '*.scss' '*.less' '*.xml' '*.json' '*.yaml' '*.yml' '*.toml' '*.md' '*.rst' '*.tex'
                set markup $markup "$dir$T$T$name:$lineno$T$content"
            case '*.conf' '*.cfg' '*.ini' '*.txt' '*.log' '*.env' '*.gitignore' '*.editorconfig'
                set text $text "$dir$T$T$name:$lineno$T$content"
            case '*'
                set other $other "$dir$T$T$name:$lineno$T$content"
        end
    end

    set -l ci 0
    for var in code markup text other
        if test (count $$var) -eq 0
            continue
        end
        set -l first_parts (string split $T -- $$var[1])
        echo "$first_parts[2] $var ("(count $$var)")"
        set -l prev_dir ""
        for entry in $$var
            set -l p (string split $T -- $entry)
            if test "$p[1]" != "$prev_dir"
                set ci (math $ci + 1)
                set -l ci_mod (math $ci % 7 + 1)
                set -l c (set_color $colors[$ci_mod])
                echo ""
                echo "$c━━━ $p[1]/ ━━━$N"
                set prev_dir $p[1]
            end
            echo "  $p[2] $p[3] · $p[4]"
        end
        echo ""
    end
end
# ─────────── lrc ───────────
function lrc --description 'embed lrc lyrics'
    if not python3 -c "import mutagen" 2>/dev/null
        echo "python-mutagen not installed"
        return 1
    end

    set -l mp3s (find "$PWD" -maxdepth 1 -type f -name "*.mp3" | sort)
    if test (count $mp3s) -eq 0
        echo "no .mp3 files in $PWD"
        return 1
    end

    echo "  lrc — embed lyrics into mp3 files"
    echo "  paste lrc → Ctrl+D save  |  D skip"
    echo ""

    echo "files:"
    for mp3 in $mp3s
        set -l name (basename "$mp3")
        python3 -c '
import sys
from mutagen.id3 import ID3
f = sys.argv[1]
try:
    t = ID3(f)
    if t.getall("USLT"): sys.exit(0)
    for k in t.keys():
        if "USLT" in k.upper() or "LYRICS" in k.upper():
            sys.exit(0)
except: pass
sys.exit(1)
' "$mp3" 2>/dev/null
        if test $status -eq 0
            echo "  ✓ $name"
        else
            echo "    $name"
        end
    end
    echo ""

    for mp3 in $mp3s
        set -l name (basename "$mp3")
        echo "→ $name"
        echo "paste lrc (Ctrl+D save, D skip):"

        set -l tmp (mktemp)
        while read -l line
            if test "$line" = "D"
                break
            end
            echo "$line" >> "$tmp"
        end

        if not test -s "$tmp"
            rm -f "$tmp"
            echo "skipped"
            continue
        end

        python3 -c '
import sys
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, USLT

f = sys.argv[1]
with open(sys.argv[2]) as fh:
    lyrics = fh.read()

tags = ID3(f)
tags.add(USLT(encoding=3, lang="eng", desc="", text=lyrics))
tags.save()
' "$mp3" "$tmp" 2>/dev/null
        rm -f "$tmp"

        if test $status -eq 0
            echo "✓ done"
        else
            echo "✗ failed"
        end
    end

    echo "all done"
end

# ─────────── past ───────────
function past -d "thunar bookmarks"
    set -l bookmarks_file ~/.config/gtk-3.0/bookmarks

    if test -f "$bookmarks_file"
        rm -f "$bookmarks_file"
        echo "bookmarks removed"
    else
        set -l home_dir $HOME

        set -l paths \
            "$home_dir/.config" \
            "$home_dir/Downloads" \
            "$home_dir/0" \
            "$home_dir/0/documents" \
            "$home_dir/0/music" \
            "$home_dir/0/pictures" \
            "$home_dir/0/videos"

        mkdir -p ~/.config/gtk-3.0
        mkdir -p $paths

        printf '%s\n' \
            "file://$home_dir/.config/" \
            "file://$home_dir/Downloads/" \
            "file://$home_dir/0" \
            "file://$home_dir/0/documents" \
            "file://$home_dir/0/music" \
            "file://$home_dir/0/pictures" \
            "file://$home_dir/0/videos" \
            > "$bookmarks_file"

        echo "bookmarks restored"
    end
end
#
# ─────────── font ───────────
function font -d "switch fonts"
    # ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-cascadia-code-nerd ttf-hack-nerd ttf-iosevka-nerd
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    set -l kitty "$HOME/.config/kitty/kitty.conf"
    set -l rofi "$HOME/.config/rofi/config.rasi"
    set -l waybar "$HOME/.config/waybar/style.css"
    set -l zed "$HOME/.config/zed/settings.json"


    while true
        set -l presets
        set -l names
        set -l active

        set -l blocks (grep -nE '^(#\s*)?font_family\s' "$kitty")
        if test -z "$blocks"
            echo "$P󰅙 no font presets found$N"
            break
        end

        set -l i 1
        for line in $blocks
            set -l parts (string split ':' -- $line)
            set -l num $parts[1]
            set -l content (string join ':' -- $parts[2..-1])

            set -l raw_name (string replace -r '^\s*#\s*' '' -- "$content" | string replace 'font_family ' '')
            set names $names $raw_name
            set presets $presets $num

            if string match -qr '^\s*font_family' -- "$content"
                set active $i
            end

            echo "  [$i] $(test "$i" = "$active"; and echo $G; or echo $D)$raw_name$N"
            set i (math $i + 1)
        end

        echo "$D  [0] 󰜺 exit$N"
        read -P "→ " choice

        switch $choice
            case 0
                clear
                return 0

            case '*'
                if not string match -qr '^\d+$' -- $choice
                    or test $choice -lt 1
                    or test $choice -gt (count $presets)
                    echo "$P󰅙 invalid$N"
                    sleep 0.5
                    clear
                    continue
                end

                set -l chosen $presets[$choice]
                set -l chosen_name $names[$choice]

                # ── kitty ──
                sed -i 's/^font_family/#font_family/' "$kitty"
                sed -i 's/^bold_font/#bold_font/' "$kitty"
                sed -i 's/^italic_font/#italic_font/' "$kitty"
                sed -i 's/^bold_italic_font/#bold_italic_font/' "$kitty"

                sed -i $chosen's/^#//' "$kitty"
                sed -i (math $chosen + 1)'s/^#//' "$kitty"
                sed -i (math $chosen + 2)'s/^#//' "$kitty"
                sed -i (math $chosen + 3)'s/^#//' "$kitty"

                # ── waybar ──
                if string match -qr 'JetBrains' -- "$chosen_name"
                    sed -i 's/font-family: "[^"]*"/font-family: "JetBrains Mono"/' "$waybar"
                else
                    sed -i 's/font-family: "[^"]*"/font-family: "monofur"/' "$waybar"
                end
                pkill -x waybar 2>/dev/null; waybar &>/dev/null &

                # ── rofi ──
                set -l active_line (grep -n '^\s*font: "' "$rofi" | tail -1)
                set -l rofi_size (string match -rg 'font:\s*".*?\s+([\d.]+)' -- $active_line)
                if test -z "$rofi_size"
                    set rofi_size "10.5"
                end

                sed -i 's/^\(\s*\)font: "/\1\/\/font: "/' "$rofi"
                if string match -qr 'JetBrains' -- "$chosen_name"
                    sed -i 's|^\(\s*\)//font: "JetBrainsMono[^"]*"|\1font: "JetBrainsMono Nerd Font Medium '$rofi_size'"|' "$rofi"
                else
                    sed -i 's|^\(\s*\)//font: "monofur[^"]*"|\1font: "monofur '$rofi_size'"|' "$rofi"
                end

                # ── zed ──
                if string match -qr 'JetBrains' -- "$chosen_name"
                    sed -i 's/"font_family": "[^"]*"/"font_family": "JetBrains Mono"/g' "$zed"
                    sed -i 's/"ui_font_family": "[^"]*"/"ui_font_family": "JetBrains Mono"/' "$zed"
                    sed -i 's/"buffer_font_family": "[^"]*"/"buffer_font_family": "JetBrains Mono"/' "$zed"
                else
                    sed -i 's/"font_family": "[^"]*"/"font_family": "monofur"/g' "$zed"
                    sed -i 's/"ui_font_family": "[^"]*"/"ui_font_family": "monofur"/' "$zed"
                    sed -i 's/"buffer_font_family": "[^"]*"/"buffer_font_family": "monofur"/' "$zed"
                end

                clear
                echo "$G󰄬 $chosen_name$N"
        end
    end
end
# ─────────── ps ───────────
function ps -d "find & delete config dirs"
    set -l P (set_color cba6f7)
    set -l R (set_color red)
    set -l G (set_color green)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    clear
    set dirs (find "$HOME/.config" -maxdepth 1 -type d | grep -i "$argv[1]")

    if test -z "$dirs"
        echo "$P󰅙 no matches for$N $D$argv[1]$N"
        return 1
    end

    echo "$P󰇘 Delete Config$N"
    echo "$D──────────────────────────────$N"
    set sel (printf "%s\n" $dirs | fzf --prompt="󰇘 delete? ")

    if test -z "$sel"
        clear
        return
    end

    echo ""
    read -P "󰅙 rm -rf $sel ? [y/N] " -l confirm
    if test "$confirm" = y
        rm -rf "$sel"
        clear
        echo "$G󰄬 deleted$N $D$sel$N"
    else
        clear
        echo "$P󰄬 cancelled$N"
    end
end
# ─────────── no display ───────────
function nodisplay -d "hide/show desktop apps"
    set -l apps \
        avahi-discover.desktop bssh.desktop bvnc.desktop \
        xfce4-about.desktop qv4l2.desktop qvidcap.desktop \
        xgps.desktop xgpsspeed.desktop org.freedesktop.Xwayland.desktop \
        kitty-open.desktop thunar-bulk-rename.desktop thunar-settings.desktop \
        org.gnupg.pinentry-qt5.desktop org.gnupg.pinentry-qt.desktop \
        electron36.desktop electron37.desktop \
        rofi.desktop rofi-theme-selector.desktop

    switch $argv[1]
        case off remove
            for app in $apps
                set -l file "/usr/share/applications/$app"
                test -f "$file" && sudo sed -i '/^NoDisplay=true$/d' "$file"
            end
            echo (set_color green)"󰄬 visible"(set_color normal)

        case on
            for app in $apps
                set -l file "/usr/share/applications/$app"
                if test -f "$file"; and not grep -q '^NoDisplay=true$' "$file"
                    echo "NoDisplay=true" | sudo tee -a "$file" >/dev/null
                end
            end
            echo (set_color red)"󰄬 hidden"(set_color normal)

        case '' '*'
            echo (set_color brblack)"󰇙 nodisplay"(set_color normal)
            echo "  "(set_color green)"[on]"(set_color normal)"  hide entries"
            echo "  "(set_color red)"[off]"(set_color normal)" show entries"
    end
end

# ─────────── extract-zips-cbz ───────────
# ─────────── cbz ───────────
function cbz -d "create cbz"
    if not command -v zip >/dev/null 2>&1
        sudo pacman -S --noconfirm zip >/dev/null 2>&1
    end
    set -l name (basename "$PWD")
    set -l file "$name.cbz"
    set -l cols (tput cols)
    set -l max (math $cols - 4)
    zip -r "$file" . -x "$file" | while read -l line
        set -l item (string match -rg 'adding: (.+) \(' -- "$line")
        if test -n "$item"
            set -l truncated (string sub -l $max -- "$item")
            printf "\r\033[K󰿺 %s" "$truncated"
        end
    end
    if test $pipestatus[1] -eq 0
        printf "\r\033[K"
        set -l size (du -h "$file" | cut -f1)
        echo "󰄬 $file ($size)"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
    end
end

# ─────────── extract ───────────
function extract -d "extract archives"
    if not command -v unzip >/dev/null 2>&1
        sudo pacman -S --noconfirm unzip >/dev/null 2>&1
    end
    set -l found 0
    for file in *.zip *.tar *.tar.gz *.tar.xz *.tar.bz2 *.tgz
        test -f "$file"; or continue
        set found 1
        set -l folder (string replace -r '\.(zip|tar\.gz|tar\.xz|tar\.bz2|tgz|tar)$' '' "$file")
        mkdir -p "$folder"
        switch "$file"
            case '*.zip'
                unzip -oq "$file" -d "$folder"
            case '*'
                tar -xf "$file" -C "$folder"
        end
        if test $status -eq 0
            rm -f "$file"
        else
            echo "󰅙 $file"
            return 1
        end
    end
    clear
    if test $found -eq 1
        echo "󰄬 extracted"
    else
        echo "empty"
    end
end

# ─────────── zips ───────────
function zips -d "zip directory with progress"
    if not command -v zip >/dev/null 2>&1
        sudo pacman -S --noconfirm zip >/dev/null 2>&1
    end
    set -l name (basename "$PWD")
    set -l file "$name.zip"
    set -l cols (tput cols)
    set -l max (math $cols - 4)
    zip -r "$file" . -x "$file" | while read -l line
        set -l item (string match -rg 'adding: (.+) \(' -- "$line")
        if test -n "$item"
            set -l truncated (string sub -l $max -- "$item")
            printf "\r\033[K󰿺 %s" "$truncated"
        end
    end
    if test $pipestatus[1] -eq 0
        printf "\r\033[K"
        set -l size (du -h "$file" | cut -f1)
        echo "󰄬 $file ($size)"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
    end
end
# ─────────── clients ───────────
function clients -d "hyprctl clients"
    clear && hyprctl clients | python3 -c '
import sys, re
from collections import defaultdict

def c(n):
    return f"\033[38;5;{n}m"

def vlen(s):
    return len(re.sub(r"\033\[[0-9;]*m", "", s))
NN = "\033[0m"

PALETTE = [117, 120, 222, 140, 110, 215, 150, 175, 117, 120, 222]

APP_COLORS = {
    "spotify":      82,
    "librewolf":    39,
    "kitty":        206,
    "dev.zed.Zed": 221,
    "org.telegram.desktop": 75,
}

PAIRS = [
    ("mapped","hidden"),("visible","acceptsInput"),("at","size"),
    ("workspace","floating"),("monitor","class"),
    ("xwayland","pinned"),("fullscreen","fullscreenClient"),
    ("overFullscreen","grouped"),("focusHistoryID","inhibitingIdle"),
    ("contentType","stableID"),
]

SINGLE = ["swallowing"]
SKIP = {"tags","xdgTag","xdgDescription"}

windows = []

for b in sys.stdin.read().strip().split("\n\n"):
    lines = b.strip().split("\n")
    if not lines: continue
    title = re.search(r"-> (.+):$", lines[0])
    title = title.group(1) if title else ""

    f = {}
    for l in lines[1:]:
        m = re.match(r"\s*([a-zA-Z]+):\s*(.*)", l)
        if m: f[m.group(1)] = m.group(2)

    ws = f.get("workspace", "0")
    ws_num = int(re.search(r"\d+", ws).group()) if re.search(r"\d+", ws) else 0
    windows.append((ws_num, title, f))

windows.sort(key=lambda x: x[0])

by_ws = defaultdict(list)
for ws_num, title, f in windows:
    by_ws[ws_num].append((title, f))

for ws_num in sorted(by_ws.keys()):
    ws_label = f" Workspace {ws_num} "
    side = (40 - len(ws_label)) // 2
    rest = 40 - len(ws_label) - side
    print(f"{c(240)}" + "\u2501" * side + f"\033[1m{ws_label}{c(240)}" + "\u2501" * rest + f"{NN}")

    for title, f in by_ws[ws_num]:

        cls = f.get("class", "")
        ac = APP_COLORS.get(cls, 44)
        sz = f.get("size", "").split(",")
        w, h = sz[0], sz[1] if len(sz) > 1 else ""
        print(f"{c(ac)}\u250a {cls}  {c(240)}\u00b7{NN}  {w}\u00d7{h}{NN}")
        print(f"{c(ac)}\u250a {title}{NN}")
        ic = f.get("initialClass","")
        pidi = f.get("pid","")
        print(f"initialClass: {ic}")
        print(f"pid: {pidi}")

        items = []
        for a, b in PAIRS:
            for k in (a, b):
                v = f.get(k, "")
                if k in SKIP and not v: continue
                items.append((k, v))
        for k in SINGLE:
            v = f.get(k, "")
            if k in SKIP and not v: continue
            items.append((k, v))

        def sort_key(item):
            k, v = item
            if v == "0":               return (2, k)
            if v.replace("-","").isdigit(): return (1, k)
            return (0, k)

        items.sort(key=sort_key)

        for i in range(0, len(items), 2):
            col = PALETTE[(i // 2) % len(PALETTE)]
            a, va = items[i]
            if i + 1 < len(items):
                b, vb = items[i + 1]
                left = f"{c(col)}{a}: \033[1m{va}\033[0m{NN}"
                right = f"{c(col)}{b}: \033[1m{vb}\033[0m{NN}"
                if vlen(left) > 42 or vlen(right) > 42:
                    print(left)
                    print(right)
                else:
                    print(f"{left:<42} {c(col)}\u2502{NN} {right}")
            else:
                print(f"{c(col)}{a}: \033[1m{va}\033[0m{NN}")

        print()

    print()

for ws, title, f in windows:
    cls = f.get("class", "")
    ac = APP_COLORS.get(cls, 44)
    sz = f.get("size", "").split(",")
    w, h = sz[0], sz[1] if len(sz) > 1 else ""
    print(f"{c(ac)}{cls}  {c(240)}\u00b7{NN}  {w}\u00d7{h}  {c(240)}\u2503{NN}  {ws}")
'
end
# ─────────── adb ───────────
function at -d "push folder/file to SD"
    set -l sd (command adb shell ls /storage/ 2>/dev/null | grep -vE 'emulated|self|sdcard0' | head -n1)
    set -l target (basename (pwd))

    switch "$argv[1]"
        case zip
            set -l zipfile "/tmp/$target.zip"
            rm -f "$zipfile"

            cd ..
            zip -rq "$zipfile" "$target" 2>/dev/null
            cd - >/dev/null

            and command adb push "$zipfile" "/storage/$sd/0/others/$target.zip"
            and rm -f "$zipfile"

        case install
            if set -q argv[2]
                command adb install-multiple $argv[2..-1]
            else
                set -l apks (find . -maxdepth 1 -type f -name "*.apk" 2>/dev/null)
                if test (count $apks) -eq 0
                    echo "No APKs found."
                    return 1
                end
                command adb install-multiple $apks
            end

        case '*'
            if set -q argv[1]
                set -l name (basename "$argv[1]")
                command adb push "$argv[1]" "/storage/$sd/0/others/$name"
            else
                command adb push . "/storage/$sd/0/others/$target"
            end
    end
end

# ─────────── chmod ───────────
function chmod -d "chmod +x on .sh files"
    if test (count $argv) -eq 0
        command chmod +x (pwd)/*.sh
    else
        command chmod -R $argv (pwd)
    end
end

function at_ -d "at help"
    set -l w (set_color white)
    set -l g (set_color green)
    set -l c (set_color cyan)
    set -l d (set_color brblack)
    set -l r (set_color normal)

    echo "$w# ─────────── at ───────────$r"
    echo "$w~/.config/fish/functions/at.fish$r"
    echo ""
    echo "  $g at$r                 → Push current folder"
    echo "  $g at <file>$r          → Push specific file"
    echo "  $g at <folder>$r        → Push folder"
    echo "  $g at zip$r             → Zip and push"
    echo "  $g at install$r         → Install all APKs"
    echo ""
    echo "  $d Examples:$r"
    echo "    $c at Wallpapers$r"
    echo "    $c at install *.apk$r"
    echo "    $c at install base.apk split_config.arm64_v8a.apk$r"
    echo ""
end

# ─────────── venv ───────────
function venvr -d "venv and install requirements"
    set -l req "$PWD/requirements.txt"
    if not test -f "$req"
        echo "requirements.txt not found"
        return 1
    end
    venv
    pip install -r "$req"
end

function venvl -d "toggle local .venv and install requirements"
    set -l env "$PWD/.venv"
    set -l req "$PWD/requirements.txt"
    set -l green (set_color green)
    set -l red (set_color red)
    set -l reset (set_color normal)

    clear

    if test "$VIRTUAL_ENV" = "$env"
        deactivate
        echo -s $red "󰄬 local venv off" $reset
        return
    end

    if test -n "$VIRTUAL_ENV"
        deactivate
    end

    if not test -d "$env"
        python3 -m venv "$env"
        echo -s $green "󰄬 .venv created" $reset
    else
        echo -s $green "󰄬 .venv already exists" $reset
    end

    source "$env/bin/activate.fish"
    echo -s $green "󰄬 local venv on" $reset

    if test -f "$req"
        pip install -q -r "$req"
        echo -s $green "󰄬 requirements installed" $reset
    else
        echo -s $red "󰅙 requirements.txt not found" $reset
    end
end

function venvreq -d "generate requirements.txt from active venv"
    set -l env "$VIRTUAL_ENV"

    if test -z "$env"
        set -l current "$PWD"
        while test "$current" != /
            if test -f "$current/bin/activate.fish"
                set env "$current"
                break
            end
            if test -f "$current/.venv/bin/activate.fish"
                set env "$current/.venv"
                break
            end
            set current (dirname "$current")
        end
    end

    if test -z "$env"
        echo "no active venv found"
        return 1
    end

    source "$env/bin/activate.fish"
    pip freeze > requirements.txt
    echo "󰄬 requirements.txt saved"
end

function venvall -d "list all .venv and venv folders"
    set -l found (find ~ -maxdepth 4 -type d \( -name ".venv" -o -name "venv" \) 2>/dev/null)
    if test -z "$found"
        echo "no .venv or venv folders found"
        return 1
    end
    echo "found venvs:"
    for v in $found
        echo "  • $v"
    end
end

function venvrmall -d "remove all .venv and venv folders"
    set -l found (find ~ -maxdepth 4 -type d \( -name ".venv" -o -name "venv" \) 2>/dev/null)
    if test -z "$found"
        echo "no .venv or venv folders found"
        return 1
    end

    echo "this will remove:"
    for v in $found
        echo "  • $v"
    end

    read -l -P "confirm? [y/N] " confirm
    if test "$confirm" != y
        echo "cancelled"
        return 1
    end

    for v in $found
        rm -rf "$v"
        echo "󰄬 removed $v"
    end
end

# ─────────── v ───────────
function v -d "show venv commands help"
    set -l N (set_color normal)
    set -l cyan (set_color 89dceb)
    set -l green (set_color a6e3a1)
    set -l red (set_color red)
    set -l gray (set_color 6c7086)

    clear
    echo ""
    echo "  $cyan venv commands$N"
    echo ""
    printf "  $green󰄬 %-8s$N %s\n" "venv"    "toggle ~/.venv"
    printf "  $green󰄬 %-8s$N %s\n" "venvr"   "toggle ~/.venv + requirements.txt"
    printf "  $green󰄬 %-8s$N %s\n" "venvl"   "toggle ./.venv + requirements.txt"
    printf "  $green󰄬 %-8s$N %s\n" "venvreq" "generate requirements.txt"
    printf "  $green󰄬 %-8s$N %s\n" "venvall" "list all venv folders"
    printf "  $red󰅙 %-8s$N %s\n"   "venvrmall" "remove all venv folders"
    echo ""
end

# ─────────── l ───────────
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
    set -l FS (printf '\x1f')

    set -l cfg_sections
    set -l cfg "$HOME/.config/fish/config.fish"
    if test -f "$cfg"
        set -l entries (grep -E "^function " "$cfg" 2>/dev/null)
        set -l visible
        for entry in $entries
            set -l name (string match -rg '^function\s+(\S+)' -- "$entry")
            if test -n "$name"; and contains -- "$name" $skip
                continue
            end
            if test -n "$name"; and string match -qr '^_' -- "$name"
                continue
            end
            set -a visible $entry
        end
        set -l count (count $visible)
        if test $count -gt 0
            set -a cfg_sections "$count$FS""config""$FS"(string join '§' $visible)
        end
    end

    set -l sections
    set -l dir "$HOME/.config/fish/functions"
    set -l files
    if test -d "$dir"
        set files (find "$dir" -maxdepth 1 -type f -name '*.fish' 2>/dev/null)
    end

    for file in $files
        set -l fname (basename "$file" .fish)
        if test "$fname" = "config"
            set fname "functions/config"
        end
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
            if test -n "$name"; and string match -qr '^_' -- "$name"
                continue
            end
            set -a visible $entry
        end

        set -l count (count $visible)
        if test $count -eq 0
            continue
        end

        set -a sections "$count$FS$fname$FS"(string join '§' $visible)
    end

    set -l ordered $cfg_sections
    if test (count $sections) -gt 0
        set -a ordered (printf '%s\0' $sections | sort -t "$FS" -k1 -rn -z | string split0)
    end

    set -l total_files (count $ordered)
    set -l total_funcs 0
    for s in $ordered
        set -l first (string split "$FS" $s)[1]
        set total_funcs (math $total_funcs + $first)
    end

    if test $total_files -eq 0
        echo "no functions found"
        return 1
    end

    echo ""
    echo "  Fish Functions"
    echo ""

    set -l idx 0
    for section in $ordered
        set -l parts (string split "$FS" $section)
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
            set -l name (string match -rg '^function\s+([^;\s]+)' -- "$entry")
            set -l desc (string match -rg -- '^function\s+[^;\s]+\s+(?:-d|-description)\s+[\x27"]([^\x27"]+)[\x27"]' -- "$entry")
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

function l -d "categorized ls"
    set -e folders zip audio video images text lua other

    for item in *
        if test -d $item
            set folders $folders " $item/"
        else if test -f $item
            switch $item
                case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                    set zip $zip " $item"
                case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                    set audio $audio " $item"
                case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                    set video $video " $item"
                case "*.txt" "*.md" "*.rst" "*.log"
                    set text $text " $item"
                case "*.lua"
                    set lua $lua " $item"
                case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                    set images $images " $item"
                case "*"
                    set other $other " $item"
            end
        end
    end

    _section brblue  " folders ($(count $folders))" $folders
    _section yellow  " zip ($(count $zip))"         $zip
    _section magenta " audio ($(count $audio))"     $audio
    _section magenta " video ($(count $video))"     $video
    _section yellow  " images ($(count $images))"   $images
    _section brgreen " text ($(count $text))"       $text
    _section cyan    " lua ($(count $lua))"         $lua
    _section white   " other ($(count $other))"     $other
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
