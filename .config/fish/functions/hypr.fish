function hypr -d "hyprland tools"
    # ─── hypr ───
    # -------------------- variables --------------------
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l D (set_color brblack)
    set -l R (set_color red)
    set -l N (set_color normal)

    set -l mon_file "$HOME/.config/hypr/lua/monitors.lua"
    set -l rule_file "$HOME/.config/hypr/lua/windowrules.lua"
    set -l mono_file "$HOME/.config/hypr/lua/monochrome.lua"
    set -l appear_file "$HOME/.config/hypr/lua/appearance.lua"

    # -------------------- menu --------------------
    while true
        # check toggle states
        set -l opac_any 0
        grep -qE '^\s*hl\.window_rule\([^)]*name = ".*-opacity"' "$rule_file"; and set opac_any 1

        set -l mono_any 0
        grep -qE '^\s*hl\.' "$mono_file" 2>/dev/null; and set mono_any 1

        set -l anim_any 0
        grep -qE 'hl\.animation\(.*enabled = true' "$appear_file"; and set anim_any 1

        set -l fx_any 0
        grep 'enabled = true' "$appear_file" | grep -qv 'hl\.animation'; and set fx_any 1

        # status labels
        set -l O (set_color green)
        set -l X (set_color red)
        set -l opac_st "off"
        test $opac_any -eq 1; and set opac_st "on"
        set -l mono_st "off"
        test $mono_any -eq 1; and set mono_st "on"
        set -l anim_st "off"
        test $anim_any -eq 1; and set anim_st "on"
        set -l fx_st "off"
        test $fx_any -eq 1; and set fx_st "on"

        # current monitor
        set -l mon_res ""
        set -l mon_line (grep -n '^\s*hl\.monitor' "$mon_file" | head -1)
        if test -n "$mon_line"
            set mon_res (string match -rg 'mode\s*=\s*"([^"]+)"' -- $mon_line)
        end

        # current gaps
        set -l gaps_cur (sed -n '5p' "$appear_file" | string match -rg 'gaps_in\s*=\s*(\d+)')
        set -l gaps_label "normal"
        test "$gaps_cur" = 0; and set gaps_label "zero"
        test "$gaps_cur" = 2; and set gaps_label "work"

        echo "$P󰍹 Hypr$N"
        echo "  [1] 󰍹 Monitor  $O$mon_res$N"
        echo "  [2] 󰇀 Opacity  $(test $opac_any -eq 1; and echo $O; or echo $X)$opac_st$N"
        echo "  [3]  Monochrome  $(test $mono_any -eq 1; and echo $O; or echo $X)$mono_st$N"
        echo "  [4]  Animations  $(test $anim_any -eq 1; and echo $O; or echo $X)$anim_st$N"
        echo "  [5]  Effects  $(test $fx_any -eq 1; and echo $O; or echo $X)$fx_st$N"
        echo "  [6]  Gaps  $O$gaps_label$N"
        echo "$D  [0] 󰜺 exit$N"
        read -P "→ " main_choice

        switch $main_choice
            case 0
                return 0

            # ─── case 1: monitor ───
            case 1
                __hypr_monitor

            # ─── case 2: opacity ───
            case 2
                __hypr_opacity

            # ─── case 3: monochrome ───
            case 3
                __hypr_monochrome

            # ─── case 4: animations ───
            case 4
                __hypr_animations

            # ─── case 5: shadow/blur ───
            case 5
                __hypr_shadowblur

            # ─── case 6: gaps ───
            case 6
                __hypr_gaps

            case '*'
                clear
                echo "$P󰅙 invalid$N"
                sleep 0.8
        end
    end
end

# ─── monitor ───
function __hypr_monitor
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l D (set_color brblack)
    set -l N (set_color normal)

    set -l mon_file "$HOME/.config/hypr/lua/monitors.lua"

    while true
        set -l entries (grep -n 'hl.monitor' "$mon_file")
        if test -z "$entries"
            echo "$P󰅙 no monitor lines found$N"
            break
        end

        set -l nums
        set -l labels

        echo "$P󰍹 Monitor$N"
        set -l i 1
        for entry in $entries
            set -l num (string split ':' -- $entry)[1]
            set -l content (string split ':' -- $entry)[2..-1] | string join ':'

            set -l active 0
            if string match -qr '^\s*hl\.monitor' -- $content
                set active 1
            end

            set -l res (string match -rg 'mode\s*=\s*"([^"]+)"' -- $content)
            set -l scale (string match -rg 'scale\s*=\s*([0-9.]+)' -- $content)

            if test -n "$res"
                set nums $nums $num
                set labels $labels $res
                if test $active -eq 1
                    echo "  [$i] $G󰄬 $res @ $scale$N"
                else
                    echo "  [$i] $D$res @ $scale$N"
                end
                set i (math $i + 1)
            end
        end
        echo "$D  [b] 󰜺 back$N"
        read -P "→ " choice

        switch $choice
            case b B
                clear
                break

            case '*'
                if not string match -qr '^\d+$' -- $choice
                    or test $choice -lt 1
                    or test $choice -gt (count $nums)
                    echo "$P󰅙 invalid$N"
                    sleep 0.8
                    clear
                    continue
                end

                set -l line $nums[$choice]
                set -l label $labels[$choice]

                sed -i 's/^hl\.monitor(/-- hl.monitor(/' "$mon_file"
                sed -i "$line{s/^-- \\?hl\\.monitor(/hl.monitor(/}" "$mon_file"

                hyprctl reload
                clear
                echo "$G󰄬 $label$N"
        end
    end
end

# ─── opacity toggle ───
function __hypr_opacity
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l R (set_color red)
    set -l N (set_color normal)

    set -l rule_file "$HOME/.config/hypr/lua/windowrules.lua"
    set -l lines (grep -nE 'hl\.window_rule\([^)]*name = ".*-opacity"' "$rule_file" | cut -d: -f1)

    set -l any 0
    grep -qE '^\s*hl\.window_rule\([^)]*name = ".*-opacity"' "$rule_file"; and set any 1

    for l in $lines
        if test $any -eq 1
            sed -i "$l s/^[[:space:]]*/&-- /" "$rule_file"
        else
            sed -i "$l s/^[[:space:]]*-- //" "$rule_file"
        end
    end

    hyprctl reload
    clear
    if test $any -eq 1
        echo "$R󰄬 opacity off$N"
    else
        echo "$G󰄬 opacity on$N"
    end
end

# ─── monochrome toggle ───
function __hypr_monochrome
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l R (set_color red)
    set -l N (set_color normal)

    set -l mono_file "$HOME/.config/hypr/lua/monochrome.lua"
    set -l any 0

    if string match -qr '^\s*hl\.' -- (sed -n '2p' "$mono_file")
        set any 1
    end

    if test $any -eq 1
        for l in 2 3 4 5 6
            sed -i "$l s/^[[:space:]]*/&-- /" "$mono_file"
        end
    else
        for l in 2 3 4 5 6
            sed -i "$l s/^[[:space:]]*-- //" "$mono_file"
        end
    end

    hyprctl reload
    clear
    if test $any -eq 1
        echo "$R󰄬 monochrome off$N"
    else
        echo "$G󰄬 monochrome on$N"
    end
end

# ─── animations toggle ───
function __hypr_animations
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l R (set_color red)
    set -l N (set_color normal)

    set -l appear_file "$HOME/.config/hypr/lua/appearance.lua"
    set -l lines (grep -nE 'hl\.animation\(.*enabled\s*=' "$appear_file" | cut -d: -f1)

    set -l any 0
    grep -qE 'hl\.animation\(.*enabled = true' "$appear_file"; and set any 1

    for l in $lines
        if test $any -eq 1
            sed -i "$l s/enabled\s*=\s*true/enabled = false/" "$appear_file"
        else
            sed -i "$l s/enabled\s*=\s*false/enabled = true/" "$appear_file"
        end
    end

    hyprctl reload
    clear
    if test $any -eq 1
        echo "$R󰄬 animations off$N"
    else
        echo "$G󰄬 animations on$N"
    end
end

# ─── shadow/blur toggle ───
function __hypr_shadowblur
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l R (set_color red)
    set -l N (set_color normal)

    set -l appear_file "$HOME/.config/hypr/lua/appearance.lua"
    set -l lines (grep -nE 'enabled\s*=' "$appear_file" | grep -v 'hl\.animation' | cut -d: -f1)

    set -l any 0
    grep 'enabled = true' "$appear_file" | grep -qv 'hl\.animation'; and set any 1

    for l in $lines
        if test $any -eq 1
            sed -i "$l s/enabled\s*=\s*true/enabled = false/" "$appear_file"
        else
            sed -i "$l s/enabled\s*=\s*false/enabled = true/" "$appear_file"
        end
    end

    hyprctl reload
    clear
    if test $any -eq 1
        echo "$R󰄬 shadow/blur off$N"
    else
        echo "$G󰄬 shadow/blur on$N"
    end
end

# ─── gaps cycle ───
function __hypr_gaps
    set -l P (set_color cba6f7)
    set -l G (set_color green)
    set -l R (set_color red)
    set -l Y (set_color yellow)
    set -l N (set_color normal)

    set -l appear_file "$HOME/.config/hypr/lua/appearance.lua"

    set -l cur (sed -n '5p' "$appear_file" | string match -rg 'gaps_in\s*=\s*([0-9]+)')
    set -l in
    set -l out
    set -l label

    switch "$cur"
        case 5
            set in 0;   set out 0;  set label "zero";   set c $R
        case 0
            set in 2;   set out 8;  set label "work";   set c $Y
        case 2
            set in 5;   set out 20; set label "normal";  set c $G
        case '*'
            set in 5;   set out 20; set label "normal";  set c $G
    end

    sed -i "5c\        gaps_in          = $in," "$appear_file"
    sed -i "6c\        gaps_out         = $out," "$appear_file"

    hyprctl reload
    clear
    echo "$c󰄬 gaps: $label ($in/$out)$N"
end
