# ─────────── utils ───────────
# cls        → clear screen
# extract    → extract archives
# mu         → play music
# nodisplay  → hide/show apps
# power      → shutdown/reboot/logout
# sunset     → screen warmth
# zips       → zip directory
# cbz        → create .cbz
#
# ─────────── music ───────────
set -g MU_PURPLE (set_color cba6f7)
set -g MU_GREEN (set_color a6e3a1)
set -g MU_BLUE (set_color 89b4fa)
set -g MU_DIM (set_color brblack)
set -g MU_RESET (set_color normal)

function mu
    pkill -9 mpv 2>/dev/null
    sleep 0.1
    clear

    set music_dir "$HOME/media/music"
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
function power -d "Shutdown, reboot or logout"
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
function sunset
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

# ─────────── nodisplay ───────────
# nodisplay on
# nodisplay off
function nodisplay -d "Hide or show desktop entries"
    set -l apps \
        avahi-discover.desktop bssh.desktop bvnc.desktop \
        xfce4-about.desktop qv4l2.desktop qvidcap.desktop \
        xgps.desktop xgpsspeed.desktop org.freedesktop.Xwayland.desktop \
        kitty-open.desktop thunar-bulk-rename.desktop thunar-settings.desktop \
        org.gnupg.pinentry-qt5.desktop org.gnupg.pinentry-qt.desktop \
        electron36.desktop electron37.desktop \
        rofi.desktop rofi-theme-selector.desktop

    set -l G (set_color green)
    set -l R (set_color red)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    switch $argv[1]
        case off remove
            for app in $apps
                set -l file "/usr/share/applications/$app"
                test -f "$file" && sudo sed -i '/^NoDisplay=true$/d' "$file"
            end
            clear
            echo "$G󰄬 visible$N"

        case on
            for app in $apps
                set -l file "/usr/share/applications/$app"
                if test -f "$file"; and not grep -q '^NoDisplay=true$' "$file"
                    echo "NoDisplay=true" | sudo tee -a "$file" >/dev/null
end
            end
            clear
            echo "$R󰄬 hidden$N"

        case '' '*'
            echo "$D󰇙 nodisplay$N"
            echo "  $G[on]$N  hide entries"
            echo "  $R[off]$N show entries"
    end
end

# ─────────── archives ───────────
# extract
# zips
# cbz
function extract
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

function zips
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
        echo "󰄬 $file"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
    end
end

function cbz
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
        echo "󰄬 $file"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
    end
end

# ─────────── playing ───────────
function playing
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

# ─────────── samba ───────────
function samba -d "samba"
    sudo -v >/dev/null 2>&1

    while true
        set -l PURPLE (set_color cba6f7)
        set -l GREEN (set_color green)
        set -l RED (set_color red)
        set -l DIM (set_color brblack)
        set -l RESET (set_color normal)

        set -l is_on 0
        if systemctl is-active --quiet smb
            set is_on 1
        end

        set -l ip (ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)

        echo "$PURPLE󰤐 Samba$RESET"
        echo "$DIM────────────────────────────$RESET"
        if test $is_on -eq 1
            echo "$GREEN  [1] 󰄬 online$RESET $DIM$ip$RESET"
            echo "  [2] 󰄬 offline"
        else
            echo "  [1] 󰄬 online"
            echo "$RED  [2] 󰄬 offline$RESET"
        end
        echo "$DIM────────────────────────────$RESET"
        echo "$DIM  [0] 󰜺 exit$RESET"
        echo ""
        read -n 1 -P "→ " choice

        switch $choice
            case 0
                return 0

            case 1
                if not command -v smbd >/dev/null 2>&1
                    sudo pacman -S samba --noconfirm >/dev/null 2>&1
                end

                set -l share "$HOME/samba/"
                test -d "$share"; or mkdir -p "$share" >/dev/null 2>&1
                chmod 777 "$share" >/dev/null 2>&1

                echo "[global]
   workgroup = WORKGROUP
   map to guest = Bad User
[all]
   path = $share
   writable = yes
   guest ok = yes
   guest only = yes" | sudo tee /etc/samba/smb.conf >/dev/null 2>&1

                if sudo systemctl enable --now smb nmb >/dev/null 2>&1
                    set -l ip (ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
                    clear
                    echo -s $GREEN "󰄬 online $ip" $RESET
                else
                    echo "󰅙 offline"
                end

            case 2
                sudo systemctl stop smb nmb >/dev/null 2>&1
                sudo systemctl disable smb nmb >/dev/null 2>&1
                sudo pacman -Rs samba --noconfirm >/dev/null 2>&1
                sudo rm -rf /etc/samba /var/lib/samba /var/log/samba >/dev/null 2>&1
                sudo rm -rf "$HOME/samba/" >/dev/null 2>&1
                clear
                echo -s $RED "󰄬 offline" $RESET

            case '*'
                echo "! invalid option"
                sleep 0.8
        end

        clear
    end
end
# ─────────── clip ───────────
function clip
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
function mem
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
        ps aux --sort=-%mem | head -6 | tail -5 | awk -v P="$P" -v R="$R" -v N="$N" '{
            cmd=$11; gsub(/.*\//,"",cmd); gsub(/^-/,"",cmd);
            mem=$4; rss=$6/1024;
            if (mem+0 > 5) color=R; else color=P;
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
function del
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
function pomodoro
    set -l file /tmp/pomodoro

    if test -e $file
        set -l end (cat $file)
        set -l now (date '+%s')
        set -l left (math -s0 "$end - $now")
        set -l m (math -s0 "$left / 60")
        set -l s (math -s0 "$left % 60")
        set -l total 900
        set -l done (math -s0 "$total - $left")
        set -l pct (math -s0 "$done * 100 / $total")
        set -l width 30
        set -l filled (math -s0 "$pct * $width / 100")
        set -l bar ""
        for i in (seq 1 $width)
            if test $i -le $filled
                set bar "$bar█"
            else
                set bar "$bar░"
            end
        end
        if test $left -gt 0
            echo "$bar $pct% — $m:$s remaining"
        else
            echo "pomodoro done"
            rm $file
        end
    else
        set -l end (math -s0 (date '+%s') + 900)
        echo $end > $file
        echo "pomodoro started — 15min"
    end
end
# ─────────── search ───────────
function search -d "Find files by name"
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

    for file in (find "$base" -maxdepth 5 -iname "*$pattern*" -type f -not -path "*/.local/*" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/.cache/*" -not -path "*/.npm/*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/__pycache__/*" -not -path "*/.cargo/*" -not -path "*/.rustup/*" -not -path "*/.var/*" -not -path "*/.config/chrome/*" -not -path "*mozilla*" -not -path "*BraveSoftware*" -not -path "*/.ssh/*" -not -path "*/.wine/*" -not -path "*/.android/*" -not -path "*/BACKUP/*" -not -type l 2>/dev/null)
        if string match -q '* *' -- $file
            set quoted "'$file'"
        else
            set quoted "$file"
        end

        switch $file
            case "*.zip" "*.tar.gz" "*.tar.xz" "*.7z" "*.rar"
                set zip $zip " $quoted"
            case "*.mp3" "*.wav" "*.flac" "*.m4a" "*.ogg"
                set audio $audio " $quoted"
            case "*.mp4" "*.mkv" "*.avi" "*.webm" "*.mov"
                set video $video " $quoted"
            case "*.txt" "*.md" "*.rst" "*.log"
                set text $text " $quoted"
            case "*.lua"
                set lua $lua " $quoted"
            case "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.webp" "*.bmp" "*.ico"
                set images $images " $quoted"
            case "*"
                set other $other " $quoted"
        end
    end

    test (count $zip) -eq 0; or echo " zip ("(count $zip)")" && for f in $zip; echo "  $f"; end
    test (count $audio) -eq 0; or echo " audio ("(count $audio)")" && for f in $audio; echo "  $f"; end
    test (count $video) -eq 0; or echo " video ("(count $video)")" && for f in $video; echo "  $f"; end
    test (count $images) -eq 0; or echo " images ("(count $images)")" && for f in $images; echo "  $f"; end
    test (count $text) -eq 0; or echo " text ("(count $text)")" && for f in $text; echo "  $f"; end
    test (count $lua) -eq 0; or echo " lua ("(count $lua)")" && for f in $lua; echo "  $f"; end
    test (count $other) -eq 0; or echo " other ("(count $other)")" && for f in $other; echo "  $f"; end
end

# ─────────── merge ───────────

function merge -d "Move files up inside each subfolder"
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
