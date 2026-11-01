# ─────────── network ───────────
function network -d "Network"
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
function dns --description '󰹋'
    argparse h/help s/status -- $argv; or return 2
    if set -q _flag_help
        printf 'dns — resolver control\n\nUsage: dns [provider | number] [--status]\n\nProviders: auto, cloudflare, google, quad9, adguard, opendns, mullvad\nAliases:   dhcp, cf, gg, q9, ag, od, mv\n\n  -s, --status  Show the current profile without changing DNS\n  -h, --help    Show this help\n\nSelect a profile and press Enter to apply. Esc exits.\nProfiles configure IPv4 DNS on the selected active connection.\n'
        return 0
    end
    if not command -q nmcli
        printf 'dns: nmcli not found. NetworkManager is required.\n' >&2
        return 1
    end
    if test (count $argv) -gt 1
        printf 'dns: expected one provider or number.\n' >&2
        return 2
    end

    set -l cyan ''
    set -l pink ''
    set -l green ''
    set -l dim ''
    set -l reset ''
    set -l width 72
    if set -q COLUMNS; and string match -qr '^[0-9]+$' -- "$COLUMNS"
        set width (math "min(88, max(32, $COLUMNS - 4))")
    end
    if isatty stdout; and not set -q NO_COLOR
        set cyan (set_color --bold 00e5ff)
        set pink (set_color --bold ff4fbd)
        set green (set_color 78ffb7)
        set dim (set_color 7b849c)
        set reset (set_color normal)
    end

    set -l connection_id (command nmcli -t -f UUID,TYPE connection show --active 2>/dev/null | command awk -F : '$2 != "loopback" { print $1; exit }')
    if test -z "$connection_id"
        printf 'dns: no active network connection found.\n' >&2
        return 1
    end
    set -l connection_name (command nmcli -g connection.id connection show uuid "$connection_id" 2>/dev/null)
    set -l current (command nmcli -g ipv4.dns connection show uuid "$connection_id" 2>/dev/null | string replace -ar '[,;[:space:]]+' ' ' | string trim)
    set -l ignore_auto (command nmcli -g ipv4.ignore-auto-dns connection show uuid "$connection_id" 2>/dev/null | string trim)
    set -l titles Automatic Cloudflare Google Quad9 AdGuard OpenDNS Mullvad
    set -l servers '' '1.1.1.1 1.0.0.1' '8.8.8.8 8.8.4.4' '9.9.9.9' '94.140.14.14 94.140.15.15' '208.67.222.222 208.67.220.220' '194.242.2.2 194.242.2.3'
    set -l active_index 0
    set -l active_label Custom
    set -l mode 'STATIC + DHCP'
    if test "$ignore_auto" = yes
        set mode STATIC
    end
    if test -z "$current"; and test "$ignore_auto" = no
        set active_index 1
        set active_label Automatic
        set mode DHCP
    else if test "$ignore_auto" = yes
        for index in (seq 2 (count $servers))
            if test "$current" = "$servers[$index]"
                set active_index $index
                set active_label "$titles[$index]"
                break
            end
        end
    end
    set -l displayed_servers "$current"
    if test -z "$displayed_servers"
        set displayed_servers '—'
    end

    if not set -q argv[1]; or set -q _flag_status
        if isatty stdin; and isatty stdout; and not set -q _flag_status
            printf '\e[H\e[2J'
        end
        set -l rule (string repeat -n "$width" '─')
        printf '\n  %s╱╱ 󰹋%s\n' "$cyan" "$reset"
        printf '  %s%s%s\n' "$dim" "$rule" "$reset"
        printf '  %s●%s     %s\n' "$green" "$reset" "$connection_name"
        printf '  %s◈%s  %s%s%s\n' "$dim" "$reset" "$cyan" "$active_label" "$reset"
        printf '  %s⇄%s  %s\n' "$dim" "$reset" "$mode"
        printf '  %s⌁%s  %s\n' "$dim" "$reset" "$displayed_servers"
        printf '  %s%s%s\n\n' "$dim" "$rule" "$reset"
        if set -q _flag_status
            return 0
        end
    end

    set -l choice ''
    if set -q argv[1]
        switch (string lower -- "$argv[1]")
            case auto dhcp automatic
                set choice 1
            case cf cloudflare
                set choice 2
            case gg google
                set choice 3
            case q9 quad9
                set choice 4
            case ag adguard
                set choice 5
            case od opendns
                set choice 6
            case mv mullvad
                set choice 7
            case '*'
                set choice "$argv[1]"
        end
    else
        set -l rows
        for index in (seq 1 (count $titles))
            set -l marker '○'
            set -l color "$cyan"
            set -l label "$servers[$index]"
            if test "$index" -eq 1
                set label '∞ DHCP'
            end
            if test "$index" -eq "$active_index"
                set marker '●'
                set color "$green"
                set label "$label  ◉"
            end
            if test "$width" -lt 62
                set -a rows (printf '%d\t%s%s [%d] %-10s%s' "$index" "$color" "$marker" "$index" "$titles[$index]" "$reset")
            else
                set -a rows (printf '%d\t%s%s [%d] %-10s%s  %s%s%s' "$index" "$color" "$marker" "$index" "$titles[$index]" "$reset" "$dim" "$label" "$reset")
            end
        end
        if isatty stdin; and isatty stdout; and command -q fzf
            set -l selection (printf '%s\n' $rows | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
                --ansi --height=14 --layout=reverse --border=sharp \
                --border-label=' 󰹋 ' --prompt='⌁ ' --pointer='▶' \
                --header='↵ ✓ · Esc × · ⌕' \
                --delimiter='\t' --with-nth=2.. --no-multi --no-sort \
                --color='bg+:#202039,fg+:#e6faff,border:#ff4fbd,label:#00e5ff,pointer:#00e5ff,prompt:#ff4fbd,hl:#ffd166,hl+:#ffd166,info:#7b849c,header:#7b849c')
            set -l picker_status $status
            if test "$picker_status" -eq 1; or test "$picker_status" -eq 130
                return 0
            else if test "$picker_status" -ne 0
                return "$picker_status"
            end
            set choice (string split \t -- "$selection")[1]
        else
            printf '%s\n' $rows | string replace -r '^[0-9]+\t' '  '
            if not isatty stdin
                printf '\n  ⌁ dns <provider>\n\n'
                return 0
            end
            printf '\n  %s[0] ×%s\n\n' "$dim" "$reset"
            read -l -P '  ⌁ ' choice; or return 0
        end
    end

    if test "$choice" = 0; or test -z "$choice"
        return 0
    end
    if not contains -- "$choice" 1 2 3 4 5 6 7
        printf 'dns: invalid profile: %s\n' "$choice" >&2
        return 2
    end
    set -l ignore_dns yes
    if test "$choice" -eq 1
        set ignore_dns no
    end
    printf '\n  %s⇄%s  %s\n' "$pink" "$reset" "$titles[$choice]"
    if not command nmcli connection modify uuid "$connection_id" ipv4.dns "$servers[$choice]" ipv4.ignore-auto-dns "$ignore_dns"
        printf '  Failed to save the DNS profile.\n' >&2
        return 1
    end
    if not command nmcli connection up uuid "$connection_id" >/dev/null 2>&1
        printf '  Profile saved, but connection activation failed.\n' >&2
        return 1
    end
    printf '  %s●%s  %s\n' "$green" "$reset" "$titles[$choice]"
    if test -n "$servers[$choice]"
        printf '  %s%s%s\n' "$dim" "$servers[$choice]" "$reset"
    end
    printf '\n'
    command -q hyprctl; and hyprctl notify 5 3000 'rgb(a6e3a1)' "DNS set: $titles[$choice]" >/dev/null 2>&1
    return 0
end

# ─────────── wifi ───────────
function wifi --description '󰤨'
    argparse h/help s/status -- $argv; or return 2
    if set -q _flag_help
        printf 'wifi [--status]\n\n↵ connect · Ctrl-B band · Ctrl-R rescan · Ctrl-D disconnect\nAlt-2 2.4 GHz · Alt-5 5 GHz · Alt-A Auto · Esc exit\nCtrl-P saved passwords · Ctrl-F forget saved networks\n'
        return 0
    end
    if set -q argv[1]
        printf 'wifi: unexpected argument: %s\n' "$argv[1]" >&2
        return 2
    end
    if not command -q nmcli
        printf 'wifi: nmcli required.\n' >&2
        return 1
    end
    set -l cyan ''
    set -l pink ''
    set -l green ''
    set -l yellow ''
    set -l dim ''
    set -l reset ''
    set -l picker_color bw
    if isatty stdout; and not set -q NO_COLOR
        set cyan (set_color --bold 00e5ff)
        set pink (set_color --bold ff4fbd)
        set green (set_color 78ffb7)
        set yellow (set_color ffd166)
        set dim (set_color 7b849c)
        set reset (set_color normal)
        set picker_color 'bg+:#202039,fg+:#e6faff,border:#ff4fbd,label:#00e5ff,pointer:#00e5ff,prompt:#ff4fbd,hl:#ffd166,hl+:#ffd166,info:#7b849c,header:#7b849c'
    end
    set -l width 68
    if set -q COLUMNS; and string match -qr '^[0-9]+$' -- "$COLUMNS"
        set width (math "min(80, max(28, $COLUMNS - 4))")
    end
    set -l name_width (math "min(26, max(8, $width - 28))")
    set -l rule (string repeat -n "$width" '─')
    set -l interactive 0
    if isatty stdin; and isatty stdout; and not set -q _flag_status
        set interactive 1
    end
    set -l picker_height 15
    if set -q LINES; and string match -qr '^[0-9]+$' -- "$LINES"
        set picker_height (math "max(8, min(17, $LINES - 10))")
    end

    while true
        set -l devices (command nmcli --colors no -t -f DEVICE,TYPE,STATE device status 2>/dev/null)
        if test "$status" -ne 0
            printf 'wifi: NetworkManager unavailable.\n' >&2
            return 1
        end
        set -l device (printf '%s\n' $devices | command awk -F : '$2 == "wifi" { if ($3 == "connected") { print $1; exit } if (!first) first = $1 } END { if (!($2 == "wifi" && $3 == "connected") && first) print first }' | command head -n 1)
        if test -z "$device"
            printf '\n  %s× 󰤭%s\n\n' "$pink" "$reset"
            return 1
        end
        set -l raw (command nmcli --colors no -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID,FREQ device wifi list ifname "$device" --rescan no 2>/dev/null)
        if test "$status" -ne 0
            printf 'wifi: could not read networks.\n' >&2
            return 1
        end
        set -l networks (printf '%s\n' $raw | command awk '
            function fields(line, values, i, char, escaped, count) {
                delete values
                count = 1
                for (i = 1; i <= length(line); i++) {
                    char = substr(line, i, 1)
                    if (escaped) { values[count] = values[count] char; escaped = 0 }
                    else if (char == "\\\\") escaped = 1
                    else if (char == ":") count++
                    else values[count] = values[count] char
                }
                return count
            }
            {
                if (fields($0, value) != 6 || value[2] == "") next
                frequency = value[6] + 0
                band = frequency >= 2400 && frequency < 2500 ? "bg" : frequency >= 4900 && frequency < 5925 ? "a" : frequency >= 5925 ? "6" : "-"
                key = value[2] SUBSEP value[4]
                bands[key, band] = 1
                score = (value[1] == "*" ? 1000 : 0) + value[3]
                if (!(key in best) || score > best[key]) {
                    best[key] = score
                    ssid[key] = value[2]
                    bssid[key] = value[5]
                    strength[key] = value[3]
                    actual[key] = band
                    active[key] = value[1] == "*" ? 1 : 0
                    secured[key] = value[4] != "" && value[4] != "--" ? 1 : 0
                }
            }
            END {
                for (key in best) {
                    labels = ""
                    if (bands[key, "bg"]) labels = "2.4"
                    if (bands[key, "a"]) labels = labels (labels ? "/" : "") "5"
                    if (bands[key, "6"]) labels = labels (labels ? "/" : "") "6"
                    if (labels == "") labels = "-"
                    gsub(/[[:cntrl:]]/, " ", ssid[key])
                    printf "%d\t%s\t%s\t%s\t%d\t%s\t%d\t%d\n", best[key], bssid[key], actual[key], labels, secured[key], ssid[key], strength[key], active[key]
                }
            }
        ' | command sort -k1,1nr)
        set -l profile (command nmcli --colors no -g GENERAL.CON-UUID device show "$device" 2>/dev/null | string trim)
        set -l current_mode ''
        if string match -qr '^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$' -- "$profile"
            set current_mode (command nmcli --colors no -g 802-11-wireless.band connection show uuid "$profile" 2>/dev/null)
            if test "$status" -ne 0
                set profile ''
            end
            if test "$current_mode" = --
                set current_mode ''
            end
        else
            set profile ''
        end
        set -l connected ''
        set -l actual_band ''
        set -l available_bands ''
        set -l rows
        set -l index 0
        for network in $networks
            set index (math "$index + 1")
            set -l fields (string split \t -- "$network")
            set -l marker ○
            set -l name_color "$cyan"
            if test "$fields[8]" = 1
                set marker "$green●$reset"
                set name_color "$green"
                set connected "$fields[6]"
                set actual_band "$fields[3]"
                set available_bands (string split / -- "$fields[4]")
            end
            set -l filled (math "max(1, min(4, ceil($fields[7] / 25)))")
            set -l signal_color "$pink"
            if test "$fields[7]" -ge 75
                set signal_color "$green"
            else if test "$fields[7]" -ge 50
                set signal_color "$cyan"
            else if test "$fields[7]" -ge 25
                set signal_color "$yellow"
            end
            set -l bar ''
            for segment in 1 2 3 4
                if test "$segment" -le "$filled"
                    set bar "$bar▰"
                else
                    set bar "$bar▱"
                end
            end
            set -l lock 󰌿
            if test "$fields[5]" = 1
                set lock 󰌾
            end
            set -l label (string sub -l "$name_width" -- "$fields[6]")
            set -a rows (printf '%d\t%s %s%-*s%s %s%s%s %3d%% %s%s%s %s' "$index" "$marker" "$name_color" "$name_width" "$label" "$reset" "$signal_color" "$bar" "$reset" "$fields[7]" "$pink" "$fields[4]" "$reset" "$lock")
        end
        if test "$interactive" -eq 1
            printf '\e[H\e[2J'
        end
        printf '\n  %s╱╱ 󰤨%s\n  %s%s%s\n' "$cyan" "$reset" "$dim" "$rule" "$reset"
        if test -n "$connected"
            set -l band_label ''
            switch "$actual_band"
                case bg
                    set band_label '2.4 GHz'
                case a
                    set band_label '5 GHz'
                case 6
                    set band_label '6 GHz'
            end
            printf '  %s●%s %s  %s%s%s\n' "$green" "$reset" "$connected" "$dim" "$band_label" "$reset"
        else
            printf '  %s○%s %s\n' "$pink" "$reset" "$device"
        end
        printf '  ⇄  '
        for band in bg a auto
            set -l label ∞
            set -l supported 1
            set -l selected_mode "$current_mode"
            if test -z "$selected_mode"
                set selected_mode auto
            end
            switch "$band"
                case bg
                    set label '2.4 GHz'
                    contains -- 2.4 $available_bands; or set supported 0
                case a
                    set label '5 GHz'
                    contains -- 5 $available_bands; or set supported 0
            end
            set -l marker ○
            set -l color "$dim"
            if test -n "$connected"; and test "$supported" -eq 1
                set color "$reset"
            end
            if test -n "$connected"; and test "$selected_mode" = "$band"
                set marker ◉
                set color "$cyan"
            end
            printf '%s%s %s%s   ' "$color" "$marker" "$label" "$reset"
        end
        printf '\n  %s%s%s\n\n' "$dim" "$rule" "$reset"
        if test "$interactive" -eq 0
            if set -q rows[1]
                printf '%s\n' $rows | string replace -r '^[0-9]+\t' '  '
            else
                printf '  ∅\n'
            end
            printf '\n'
            return 0
        end
        set -l choice ''
        set -l selected ''
        if command -q fzf
            set -l picker_rows $rows
            if not set -q picker_rows[1]
                set picker_rows (printf '0\t∅')
            end
            set -l selection (printf '%s\n' $picker_rows | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
                --ansi --height="$picker_height" --layout=reverse --border=sharp --border-label=' 󰤨 ' \
                --prompt='⌁ ' --pointer='▶' --header='↵ ⌁ · ^B ⇄ · ^R ⟳ · ^D ⏻ · ^P 󰌾 · ^F ⌫ · Esc ×' \
                --delimiter='\t' --with-nth=2.. --no-multi --no-sort --color="$picker_color" \
                --expect=ctrl-b,ctrl-r,ctrl-d,ctrl-p,ctrl-f,alt-2,alt-5,alt-a)
            set -l picker_status $status
            if test "$picker_status" -eq 1; or test "$picker_status" -eq 130
                return 0
            else if test "$picker_status" -ne 0
                return "$picker_status"
            end
            switch "$selection[1]"
                case ctrl-b
                    set choice b
                case ctrl-r
                    set choice r
                case ctrl-d
                    set choice d
                case ctrl-p
                    set choice p
                case ctrl-f
                    set choice f
                case alt-2
                    set choice band-bg
                case alt-5
                    set choice band-a
                case alt-a
                    set choice band-auto
                case '*'
                    set choice connect
                    set selected (string split \t -- "$selection[-1]")[1]
            end
        else
            for row in $rows
                set -l fields (string split \t -- "$row")
                printf '  [%s] %s\n' "$fields[1]" "$fields[2]"
            end
            printf '\n  [b] ⇄ · [r] ⟳ · [d] ⏻ · [p] 󰌾 · [f] ⌫ · [0] ×\n'
            read -l -P '  ⌁ ' choice; or return 0
            if string match -qr '^[0-9]+$' -- "$choice"; and test "$choice" != 0
                set selected "$choice"
                set choice connect
            end
        end
        switch "$choice"
            case 0 ''
                return 0
            case b
                if test -z "$connected"
                    printf '  × Wi-Fi\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                set -l band_rows
                contains -- 2.4 $available_bands; and set -a band_rows (printf 'bg\t2.4 GHz')
                contains -- 5 $available_bands; and set -a band_rows (printf 'a\t5 GHz')
                set -a band_rows (printf 'auto\t∞')
                if command -q fzf
                    set -l selection (printf '%s\n' $band_rows | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
                        --ansi --height=9 --layout=reverse --border=sharp --border-label=' ⇄ ' \
                        --prompt='⌁ ' --pointer='▶' --header='↵ ✓ · Esc ×' \
                        --delimiter='\t' --with-nth=2.. --no-multi --no-sort --color="$picker_color")
                    if test "$status" -ne 0
                        continue
                    end
                    set choice band-(string split \t -- "$selection")[1]
                else
                    printf '\n  [2] 2.4 GHz · [5] 5 GHz · [a] ∞ · [0] ×\n'
                    read -l -P '  ⇄ ' selected; or return 0
                    switch "$selected"
                        case 2
                            set choice band-bg
                        case 5
                            set choice band-a
                        case a
                            set choice band-auto
                        case '*'
                            continue
                    end
                end
        end
        switch "$choice"
            case band-bg band-a band-auto
                if test -z "$connected"; or test -z "$profile"
                    printf '  × Wi-Fi\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                set -l requested (string replace 'band-' '' -- "$choice")
                if test "$requested" = auto
                    set requested ''
                else
                    set -l required_band 2.4
                    if test "$requested" = a
                        set required_band 5
                    end
                    if not contains -- "$required_band" $available_bands
                        printf '  × %s GHz\n' "$required_band"
                        read -l -P '  ↵ ' pause; or return 0
                        continue
                    end
                end
                if test "$requested" = "$current_mode"
                    continue
                end
                set -l previous_channel (command nmcli --colors no -g 802-11-wireless.channel connection show uuid "$profile" 2>/dev/null)
                if test "$status" -ne 0
                    printf '  × Profile\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                set -l previous_bssid (command nmcli --colors no --escape no -g 802-11-wireless.bssid connection show uuid "$profile" 2>/dev/null)
                if test "$status" -ne 0
                    printf '  × Profile\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                if contains -- "$previous_channel" 0 --
                    set previous_channel ''
                end
                if test "$previous_bssid" = --
                    set previous_bssid ''
                end
                if not command nmcli --colors no connection modify uuid "$profile" 802-11-wireless.channel '' 802-11-wireless.band "$requested" 802-11-wireless.bssid '' >/dev/null 2>&1
                    printf '  × Profile\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                printf '  %s⇄%s\n' "$cyan" "$reset"
                if not command nmcli --colors no --wait 30 connection up uuid "$profile" ifname "$device" >/dev/null 2>&1
                    if command nmcli --colors no connection modify uuid "$profile" 802-11-wireless.channel '' 802-11-wireless.band "$current_mode" 802-11-wireless.channel "$previous_channel" 802-11-wireless.bssid "$previous_bssid" >/dev/null 2>&1
                        and command nmcli --colors no --wait 30 connection up uuid "$profile" ifname "$device" >/dev/null 2>&1
                        printf '  × Band switch failed; previous connection restored.\n'
                    else
                        printf '  × Band switch failed; reconnect to restore access.\n'
                    end
                    read -l -P '  ↵ ' pause; or return 0
                end
            case r
                if not command nmcli --colors no device wifi rescan ifname "$device" >/dev/null 2>&1
                    printf '  × ⟳\n'
                    read -l -P '  ↵ ' pause; or return 0
                end
            case d
                if not command nmcli --colors no device disconnect "$device" >/dev/null 2>&1
                    printf '  × ⏻\n'
                    read -l -P '  ↵ ' pause; or return 0
                end
            case connect
                if not string match -qr '^[1-9][0-9]*$' -- "$selected"; or test "$selected" -gt (count $networks)
                    continue
                end
                set -l fields (string split \t -- "$networks[$selected]")
                if test "$fields[8]" = 1
                    continue
                end
                if not string match -qr '^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$' -- "$fields[2]"
                    continue
                end
                if not command nmcli --colors no --wait 25 --ask device wifi connect "$fields[2]" ifname "$device"
                    printf '  × ⌁\n'
                    read -l -P '  ↵ ' pause; or return 0
                end
            case p f
                set -l saved (command nmcli --colors no -t -f UUID,TYPE connection show 2>/dev/null | command awk -F : '$2 == "wifi" || $2 == "802-11-wireless" { print $1 }')
                if not set -q saved[1]
                    printf '  ∅\n'
                    read -l -P '  ↵ ' pause; or return 0
                    continue
                end
                if test "$choice" = f
                    read -l -P '  Forget all saved Wi-Fi networks? [y/N] ' confirm; or return 0
                    if test "$confirm" != y
                        continue
                    end
                    for uuid in $saved
                        if not command nmcli --colors no connection delete uuid "$uuid" >/dev/null 2>&1
                            printf '  × ⌫\n'
                        end
                    end
                else
                    for uuid in $saved
                        set -l name (command nmcli --colors no -g connection.id connection show uuid "$uuid" 2>/dev/null)
                        set -l password (command nmcli --colors no --show-secrets -g 802-11-wireless-security.psk connection show uuid "$uuid" 2>/dev/null)
                        printf '  󰌾 %s  %s\n' "$name" "$password"
                        set -e password
                    end
                    read -l -P '  ↵ ' pause; or return 0
                end
        end
    end
end
