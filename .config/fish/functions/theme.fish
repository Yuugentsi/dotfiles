function theme --description "Change icon theme"
    set -l PURPLE (set_color cba6f7)
    set -l GREEN (set_color a6e3a1)
    set -l DIM (set_color brblack)
    set -l RESET (set_color normal)

    set -l current (GSETTINGS_BACKEND=dconf gsettings get org.gnome.desktop.interface icon-theme | string trim -c "'")

    set -l icon_dirs /usr/share/icons $HOME/.local/share/icons
    set -l themes
    for dir in $icon_dirs
        if test -d "$dir"
            for t in "$dir"/*/
                set base (basename "$t")
                if test -n "$base"
                    set -a themes "$base"
                end
            end
        end
    end
    set themes (printf "%s\n" $themes | sort -u)

    while true
        clear
        echo ""
        echo "$PURPLE󰉋 Icon Theme$RESET"
        echo "$DIM────────────────────────────$RESET"
        echo "$DIM  current: $current$RESET"
        echo ""

        set -l i 1
        for t in $themes
            if test "$t" = "$current"
                echo "  [$i] $GREEN$t  ●$RESET"
            else
                echo "  [$i] $t"
            end
            set i (math $i + 1)
        end

        echo ""
        echo "$DIM  [0] exit$RESET"
        echo ""
        read -P "→ " choice

        if test "$choice" = 0 -o "$choice" = ""
            return 0
        end

        if not string match -qr '^\d+$' -- "$choice"
            or test "$choice" -lt 1
            or test "$choice" -gt (count $themes)
            continue
        end

        set selected $themes[$choice]

        GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme "$selected"
        sed -i "s/icon-theme\"] = \".*\"/icon-theme\"] = \"$selected\"/" "$HOME/.config/hypr/lua/env.lua"
        set current "$selected"
    end
end