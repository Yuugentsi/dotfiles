# ─────────── network ───────────
function network -d "Network: WiFi or DNS"
    set -l P (set_color cba6f7)
    set -l B (set_color 89dceb)
    set -l G (set_color a6e3a1)
    set -l R (set_color f38ba8)
    set -l D (set_color 6c7086)
    set -l TXT (set_color cdd6f4)
    set -l N (set_color normal)

    set -l ssid (nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
    set -l ip (ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
    set -l dns_ip (grep '^nameserver' /etc/resolv.conf 2>/dev/null | grep -v '^nameserver fe80' | awk '{print $2}' | head -1)

    set -l wifi_status "$R󰤭 Disconnected$N"
    if test -n "$ssid"
        set -l ping_ms ""
        set -l gw (ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
        if test -n "$gw"
            set -l raw_ping (ping -c 1 -W 1 $gw 2>/dev/null | grep -oP 'time=\K[\d.]+')
            if test -n "$raw_ping"
                set ping_ms " $D•$N $B󱌅 "$raw_ping"ms$N"
            end
        end
        set wifi_status "$G󰤨 $ssid$N $D($ip)$N$ping_ms"
    end

    set -l dns_status "$D$dns_ip$N"
    test -z "$dns_ip"; and set dns_status "$DNone$N"

    clear
    echo ""
    echo "  $P╭─ 󱻳  Network Center ─────────────────────────────────────╮$N"
    echo "  $P│$N  $wifi_status"
    echo "  $P│$N  $P󰹋 DNS:$N $dns_status"
    echo "  $P╰────────────────────────────────────────────────────────╯$N"
    echo ""
    echo "   [1]  󰤨  WiFi Manager"
    echo "   [2]  󰹋  DNS Profiles"
    echo "   [0]  󱌺  Exit"
    echo ""

    read -P "  ╰─ ❯ " choice
    switch $choice
        case 1
            wifi
        case 2
            dns
        case '*'
            return 0
    end
end

# ─────────── DNS ───────────
function dns --description "Change DNS easily"
    if not command -v nmcli >/dev/null 2>&1
        echo "nmcli not found. Install NetworkManager to manage DNS."
        return 1
    end

    set -l CONN (nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | head -1 | cut -d: -f1)
    if test -z "$CONN"
        echo "No active network connection found"
        return 1
    end

    set -l P (set_color cba6f7)
    set -l B (set_color 89dceb)
    set -l G (set_color a6e3a1)
    set -l Y (set_color f9e2af)
    set -l R (set_color f38ba8)
    set -l D (set_color 6c7086)
    set -l TXT (set_color cdd6f4)
    set -l N (set_color normal)

    set -l names automatic cloudflare google quad9 adguard opendns mullvad
    set -l titles "Automatic" "Cloudflare" "Google" "Quad9" "AdGuard" "OpenDNS" "Mullvad"
    set -l icons "󱑐" "󰀄" "󰮶" "󰁴" "󰁪" "󰁂" "󰁘"
    set -l desc "DHCP default" "1.1.1.1, 1.0.0.1 (Fast)" "8.8.8.8, 8.8.4.4" "9.9.9.9 (Malware Block)" "94.140.14.14 (Ad-Block)" "208.67.222.222" "194.242.2.2 (Privacy)"
    set -l servers "" "1.1.1.1 1.0.0.1" "8.8.8.8 8.8.4.4" "9.9.9.9" "94.140.14.14 94.140.15.15" "208.67.222.222 208.67.220.220" "194.242.2.2 194.242.2.3"

    set -l current (nmcli -g ipv4.dns connection show "$CONN" 2>/dev/null | string trim | string replace -a ',' ' ')
    set -l active_idx 1
    for i in (seq 2 (count $servers))
        if test "$current" = "$servers[$i]"
            set active_idx $i
            break
        end
    end

    set -l active_label "$titles[$active_idx]"
    test -n "$servers[$active_idx]"; and set active_label "$active_label ($servers[$active_idx])"

    set -l choice ""
    if test -n "$argv[1]"
        set -l arg (string lower "$argv[1]")
        switch "$arg"
            case auto dhcp automatic; set choice 1
            case cf cloudflare; set choice 2
            case gg google; set choice 3
            case q9 quad9; set choice 4
            case ag adguard; set choice 5
            case od opendns; set choice 6
            case mv mullvad; set choice 7
            case '*'; set choice "$argv[1]"
        end
    else
        clear
        echo ""
        echo "  $P╭─ 󰹋  DNS Profiles ──────────────────────────────────────╮$N"
        echo "  $P│$N  $TXT Active Connection: $G$CONN$N"
        echo "  $P│$N  $TXT Current DNS:       $P$active_label$N"
        echo "  $P╰────────────────────────────────────────────────────────╯$N"
        echo ""
        echo "   $D#   PROVIDER         CONFIG / SERVERS$N"
        echo "  $D──────────────────────────────────────────────────────────$N"

        for i in (seq 1 (count $titles))
            set -l mark "  "
            set -l num_col "$D"
            set -l name_col "$TXT"
            if test "$i" = "$active_idx"
                set mark "$G●$N "
                set num_col "$G"
                set name_col "$G"(set_color --bold)
            end

            printf "  %s[%d]%s  %s %-14s%s %-32s %s\n" "$num_col" $i "$N" "$icons[$i]" "$name_col$titles[$i]" "$N" "$D$desc[$i]$N" "$mark"
        end

        echo "  $D──────────────────────────────────────────────────────────$N"
        echo "   [0]  Exit"
        echo ""
        read -P "  ╰─ ❯ " choice
    end

    if test "$choice" = 0 -o "$choice" = ""
        return 0
    end

    if not string match -qr '^\d+$' -- "$choice"
        or test "$choice" -lt 1
        or test "$choice" -gt (count $names)
        echo "  $R󰅙 Invalid selection$N"
        return 1
    end

    set -l name $titles[$choice]
    set -l dns $servers[$choice]

    if test "$choice" -eq 1
        nmcli con mod "$CONN" ipv4.dns "" ipv4.ignore-auto-dns no
    else
        nmcli con mod "$CONN" ipv4.dns "$dns" ipv4.ignore-auto-dns yes
    end
    nmcli con up "$CONN" >/dev/null 2>&1

    if test $status -eq 0
        echo "  $G󰄬 DNS updated to $name$N"
        test -n "$dns"; and echo "  $D   $dns$N"
        command -q hyprctl; and hyprctl notify 5 3000 "rgb(a6e3a1)" "DNS set: $name" >/dev/null 2>&1
    else
        echo "  $R󰅙 Failed to apply DNS configuration$N"
        return 1
    end
end

# ─────────── wifi ───────────
function wifi --description 'Network Manager'
    if not command -v nmcli >/dev/null 2>&1
        echo "nmcli not found. Install NetworkManager to manage WiFi."
        return 1
    end

    while true
        clear
        set -l P (set_color cba6f7)
        set -l B (set_color 89dceb)
        set -l G (set_color a6e3a1)
        set -l Y (set_color f9e2af)
        set -l O (set_color fab387)
        set -l R (set_color f38ba8)
        set -l D (set_color 6c7086)
        set -l TXT (set_color cdd6f4)
        set -l N (set_color normal)

        set -l ssid (nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
        set -l ip (ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
        set -l dns (grep '^nameserver' /etc/resolv.conf 2>/dev/null | grep -v '^nameserver fe80' | awk '{print $2}' | command tr '\n' ' ' | string trim)
        set -l wifi_dev (nmcli -t -f device,type dev 2>/dev/null | grep wifi | cut -d: -f1 | head -1)

        echo ""
        echo "  $P╭─ 󰤨  WiFi Control ──────────────────────────────────────╮$N"
        if test -n "$ssid"
            set -l freq (nmcli -t -f active,chan dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
            set -l band "2.4GHz"
            test -n "$freq"; and test "$freq" -gt 14; and set band "5GHz"

            set -l ping_ms ""
            set -l gw (ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
            if test -n "$gw"
                set -l raw_ping (ping -c 1 -W 1 $gw 2>/dev/null | grep -oP 'time=\K[\d.]+')
                test -n "$raw_ping"; and set ping_ms " $D•$N $B󱌅 "$raw_ping"ms$N"
            end

            echo "  $P│$N  $G󰄬 Connected:$N $TXT$ssid$N"
            echo "  $P│$N  $D  IP:$N $TXT$ip$N $D•$N $P$band$N$ping_ms"
            echo "  $P│$N  $D  DNS:$N $D$dns$N"
        else
            echo "  $P│$N  $R󰤭 Disconnected$N"
            echo "  $P│$N  $D  Interface: $wifi_dev$N"
        end
        echo "  $P╰────────────────────────────────────────────────────────╯$N"
        echo ""

        set -l networks (nmcli -t -f ssid,signal,security,chan dev wifi list 2>/dev/null | grep -v '^:' | sort -t: -k2 -rn | awk -F: '!seen[$1]++ && $1!=""')

        if test (count $networks) -eq 0
            echo "  $Y󰤭 No Wi-Fi networks found$N"
            echo ""
            read -P "  [r] Rescan  [0] Exit ╰─ ❯ " choice
            if test "$choice" = "0"
                return 0
            end
            nmcli dev wifi rescan >/dev/null 2>&1
            continue
        end

        echo "   $D#   SSID                        SIGNAL    BAND   SEC$N"
        echo "  $D──────────────────────────────────────────────────────────$N"

        set -l i 1
        set -l ssids
        for net in $networks
            set -l name (echo $net | cut -d: -f1)
            set -l sig (echo $net | cut -d: -f2)
            set -l sec (echo $net | cut -d: -f3)
            set -l chan (echo $net | cut -d: -f4)

            set -l bar
            if test $sig -ge 75
                set bar "$G████$N"
            else if test $sig -ge 50
                set bar "$Y███ $N"
            else if test $sig -ge 25
                set bar "$O██  $N"
            else
                set bar "$R█   $N"
            end

            set -l band "$P 2.4G$N"
            test -n "$chan"; and test "$chan" -gt 14 2>/dev/null; and set band "$B   5G$N"

            set -l lock "$D󰌉 Open$N"
            test -n "$sec"; and test "$sec" != "--"; and set lock "$Y󰌾 WPA $N"

            set -l mark "  "
            set -l num_col "$D"
            set -l name_col "$TXT"
            if test "$name" = "$ssid"
                set mark "$G●$N "
                set num_col "$G"
                set name_col "$G"(set_color --bold)
            end

            set -l display_name (string sub -l 24 "$name")
            printf "  %s[%2d]%s  %-24s  %s %3d%%  %s  %s  %s\n" "$num_col" $i "$N" "$name_col$display_name$N" "$bar" $sig "$band" "$lock" "$mark"

            set ssids $ssids "$name"
            set i (math $i + 1)
        end

        echo "  $D──────────────────────────────────────────────────────────$N"
        echo "  $D [d] Disconnect  [r] Rescan  [p] Passwords  [f] Forget  [0] Exit$N"
        echo ""
        read -P "  ╰─ ❯ " choice

        switch $choice
            case 0 ''
                return 0
            case d
                if test -n "$ssid"
                    nmcli dev disconnect $wifi_dev >/dev/null 2>&1
                    command -q hyprctl; and hyprctl notify 0 2500 "rgb(f9e2af)" "WiFi disconnected" >/dev/null 2>&1
                    echo "  $Y× Disconnected$N"
                    sleep 0.8
                else
                    echo "  $D! Not connected$N"
                    sleep 0.8
                end
            case r
                nmcli dev wifi rescan >/dev/null 2>&1
            case p
                set -l saved_wifi (nmcli -t -f NAME,TYPE con show 2>/dev/null | grep '802-11-wireless' | cut -d: -f1)
                echo ""
                if test (count $saved_wifi) -eq 0
                    echo "  $D! No saved networks$N"
                else
                    echo "  $P╭─ 󰌾  Saved Passwords ──────────────────────────────╮$N"
                    for net in $saved_wifi
                        set -l pass (nmcli -s -t -f 802-11-wireless-security.psk con show "$net" 2>/dev/null | cut -d: -f2-)
                        if test -n "$pass"
                            printf "  $P│$N  $TXT%-24s$N  $G%s$N\n" "$net" "$pass"
                        else
                            printf "  $P│$N  $D%-24s  [Open / None]$N\n" "$net"
                        end
                    end
                    echo "  $P╰──────────────────────────────────────────────────╯$N"
                end
                echo ""
                read -P "  Press Enter to continue..." cont
            case f
                set -l saved_wifi (nmcli -t -f NAME,TYPE con show 2>/dev/null | grep '802-11-wireless' | cut -d: -f1)
                if test (count $saved_wifi) -eq 0
                    echo "  $D! No saved networks to forget$N"
                    sleep 1
                else
                    read -P "  󱷜 Forget all "(count $saved_wifi)" saved networks? [y/N]: " confirm
                    if string match -qi 'y*' $confirm
                        for net in $saved_wifi
                            nmcli con delete "$net" >/dev/null 2>&1
                        end
                        command -q hyprctl; and hyprctl notify 0 2500 "rgb(f38ba8)" "All WiFi networks forgotten" >/dev/null 2>&1
                        echo "  $R󱷜 All saved networks removed$N"
                    else
                        echo "  $DCancelled$N"
                    end
                    sleep 1
                end
            case '*'
                if string match -qr '^\d+$' $choice; and test $choice -ge 1 -a $choice -le (count $ssids)
                    set -l target $ssids[$choice]
                    if test "$target" = "$ssid"
                        echo "  $G󰄬 Already connected to $target$N"
                        sleep 0.8
                        continue
                    end

                    set -l saved (nmcli -t -f name con show 2>/dev/null | grep -Fx "$target")
                    if test -n "$saved"
                        echo "  $B󰤨 Connecting to $target...$N"
                        nmcli con up "$target" >/dev/null 2>&1
                    else
                        read -sP "  󰌾 Password for $target: " pass
                        echo ""
                        echo "  $B󰤨 Connecting to $target...$N"
                        nmcli dev wifi connect "$target" password "$pass" >/dev/null 2>&1
                    end

                    if test $status -eq 0
                        echo "  $G󰄬 Connected to $target$N"
                        command -q hyprctl; and hyprctl notify 5 3000 "rgb(a6e3a1)" "WiFi connected: $target" >/dev/null 2>&1
                    else
                        echo "  $R󰅙 Connection failed$N"
                        command -q hyprctl; and hyprctl notify 3 3000 "rgb(f38ba8)" "Connection failed: $target" >/dev/null 2>&1
                    end
                    sleep 1
                else
                    echo "  $R! Invalid option$N"
                    sleep 0.8
                end
        end
    end
end
