# ─────────── utils ───────────
# cbz        → create .cbz
# clients    → hyprctl clients
# clip       → clipboard manager
# cls        → clear screen
# del        → uninstall packages
# extract    → extract archives
# zips       → zip directory
# lf         → list files with date
# mem        → memory monitor
# merge      → move files up from subfolders
# mu         → play music
# n          → neovim
# nodisplay  → hide/show apps
# playing    → now playing playerctl
# pomodoro   → 15min timer
# power      → shutdown/reboot/logout
# samba      → samba share
# search     → find files by name
# sunset     → screen warmth
# up         → update system
#
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

# ─────────── nodisplay ───────────
# nodisplay on
# nodisplay off
function nodisplay -d "hide desktop"
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

function zips -d "zip directory"
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
        echo "󰄬 $file"
    else
        printf "\r\033[K"
        echo "󰅙"
        return 1
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

# ─────────── samba ───────────
function samba -d "samba share"
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
    set -q POMODORO_LOG; or set POMODORO_LOG "$HOME/media/documents"
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
'
end
