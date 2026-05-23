# ─────────── pkg ───────────
function pkg --description 'Unified package manager'
    set -g PKG_PREVIEW true
    set -g PKG_SHOW_ALL true
    set -g PKG_SHOW_PACMAN true
    set -g PKG_SHOW_YAY true
    set -g PKG_SHOW_UPDATE true
    set -g PKG_SHOW_UNINSTALL true

    function __pkg_color -a color text bg
        if test -n "$bg"
            set_color -b $bg $color --bold
        else
            set_color $color
        end
        echo $text
        set_color normal
    end

    function __pkg_need -a cmd pkg
        command -v $cmd >/dev/null 2>&1; and return 0
        __pkg_color cc7832 "  Installing $pkg..."
        sudo pacman -S --noconfirm $pkg
    end

    function __pkg_need_yay
        command -v yay >/dev/null 2>&1; and return 0

        __pkg_color ff6b68 " 󰀦 yay not found! "

        if test -f /var/lib/pacman/db.lck
            sudo rm -f /var/lib/pacman/db.lck
        end

        __pkg_need git git; or return 1

        if not pacman -Q base-devel >/dev/null 2>&1
            sudo pacman -S --noconfirm base-devel
        end

        set -l temp_dir (mktemp -d)

        git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"

        begin
            pushd "$temp_dir/yay" >/dev/null
            yes | makepkg -si --noconfirm --needed
            popd >/dev/null
        end

        rm -rf $temp_dir
    end

    function __pkg_aur_cache -a cache_file
        mkdir -p (dirname "$cache_file")

        set -l should_update 0

        if not test -f "$cache_file"
            set should_update 1
        else if not test -s "$cache_file"
            set should_update 1
        else
            set -l file_time (stat -c %Y "$cache_file" 2>/dev/null; or date -r "$cache_file" +%s)
            set -l age (math (date +%s)" - $file_time")

            if test $age -gt 86400
                set should_update 1
            end
        end

        if test $should_update -eq 1
            curl -L -s "https://aur.archlinux.org/packages.gz" | gunzip > "$cache_file"
        end
    end

    function __pkg_selected -a title title_color item_color
        set -l pkgs $argv[4..-1]

        echo
        __pkg_color $title_color "  "(count $pkgs)" $title " 2b2b2b

        for pkg in $pkgs
            __pkg_color $item_color "   $pkg"
        end

        echo
    end

    function __pkg_yay_install
        yay -S --noconfirm $argv; or return 1
        yay -Yc --noconfirm 2>/dev/null
    end

    function __pkg_preview
        test "$PKG_PREVIEW" = true; or return

        switch $argv[1]
            case pacman
                printf '%s\n' --preview 'pacman -Si {1}' --preview-window='right:60%:wrap'

            case yay
                printf '%s\n' --preview 'yay -Si {1} 2>/dev/null || echo "Package not found"' --preview-window='right:60%:wrap'

            case all
                printf '%s\n' --preview 'yay -Si {1} 2>/dev/null || pacman -Si {1}' --preview-window='right:60%:wrap'

            case uninstall
                printf '%s\n' --preview 'pacman -Qi {1}' --preview-window='right:60%:wrap'
        end
    end

    function __pkg_main_menu
        test "$PKG_SHOW_ALL" = true; and echo "󰏗  All Repositories"
        test "$PKG_SHOW_PACMAN" = true; and echo "󰮯  Pacman"
        test "$PKG_SHOW_YAY" = true; and echo "󰣇  Yay"
        test "$PKG_SHOW_UPDATE" = true; and echo "󰇚  Update"
        test "$PKG_SHOW_UNINSTALL" = true; and echo "󰅙  Uninstall"
    end

    function __pkg_pacman_menu -a FZF_COLORS
        set -l pkgs (
            pacman -Sl | awk '!/\[installed\]$/ {print $2}' | fzf --multi \
                $FZF_COLORS \
                (__pkg_preview pacman) \
                --height 60% \
                --layout reverse \
                --border rounded \
                --prompt="󰮯 Pacman > " \
                --pointer="" \
                --marker="󰄬"
        )

        if test -n "$pkgs"
            __pkg_selected "PACKAGES SELECTED" cc7832 6a8759 $pkgs
            sudo pacman -S --noconfirm --color=always $pkgs
        end
    end

    function __pkg_yay_menu -a FZF_COLORS cache_file
        __pkg_need_yay; or return 1
        __pkg_aur_cache "$cache_file"

        set -l aur_pkgs (cat "$cache_file")

        set -l pkgs (
            printf "%s\n" $aur_pkgs | fzf --multi \
                $FZF_COLORS \
                (__pkg_preview yay) \
                --height 60% \
                --layout reverse \
                --border rounded \
                --prompt="󰣇 Yay > " \
                --pointer="" \
                --marker="󰄬"
        )

        if test -n "$pkgs"
            __pkg_selected "PACKAGES SELECTED" 9876aa 9876aa $pkgs
            __pkg_yay_install $pkgs
        end
    end

    __pkg_need fzf fzf; or return 1

    set -l FZF_COLORS "--color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,fg+:#cdd6f4,bg+:#313244,hl+:#cba6f7,info:#a6adc8,prompt:#89dceb,pointer:#f38ba8,marker:#a6e3a1,spinner:#f9e2af,header:#a6e3a1"
    set -l UNINSTALL_COLORS "--color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8,fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8,info:#a6adc8,prompt:#f38ba8,pointer:#f38ba8,marker:#f38ba8,header:#f38ba8"
    set -l cache_file "$HOME/.cache/aur_packages"

    if test (count $argv) -gt 0
        set -l query $argv[1]

        pacman -Si "$query" >/dev/null 2>&1
        set -l pacman_exists $status

        if test $pacman_exists -eq 0
            sudo pacman -S --noconfirm --color=always $argv
            return
        end

        set -l official_pkgs (pacman -Slq)

        set -l selected (
            printf "%s\n" $official_pkgs | fzf --multi \
                $FZF_COLORS \
                (__pkg_preview pacman) \
                --query="$query" \
                --height 60% \
                --layout reverse \
                --border rounded \
                --prompt="󰮯 Similar Packages > " \
                --pointer="" \
                --marker="󰄬"
        )

        if test -n "$selected"
            __pkg_selected "SIMILAR PACKAGES SELECTED" cc7832 6a8759 $selected
            sudo pacman -S --noconfirm --color=always $selected
        end

        return
    end

    set -l source_mode (
        __pkg_main_menu | fzf \
            $FZF_COLORS \
            --height 25% \
            --layout reverse \
            --border rounded \
            --prompt=" Action > " \
            --pointer="" \
            --header="Select Action"
    )

    test -z "$source_mode"; and return

    switch $source_mode
        case "*Update*"
            sudo pacman -Syu --noconfirm --color=always

        case "*Pacman*"
            __pkg_pacman_menu "$FZF_COLORS"

        case "*All*"
            __pkg_need_yay; or return 1
            __pkg_aur_cache "$cache_file"

            set -l official_pkgs (pacman -Sl | awk '!/\[installed\]$/ {print $2}')
            set -l aur_pkgs (cat "$cache_file")

            set -l all_pkgs (
                printf "%s\n" $official_pkgs $aur_pkgs | sort -u
            )

            set -l pkgs (
                printf "%s\n" $all_pkgs | fzf --multi \
                    $FZF_COLORS \
                    (__pkg_preview all) \
                    --height 60% \
                    --layout reverse \
                    --border rounded \
                    --prompt="󰏗 All Repos > " \
                    --pointer="" \
                    --marker="󰄬"
            )

            if test -n "$pkgs"
                __pkg_selected "PACKAGES SELECTED" 9876aa 9876aa $pkgs
                __pkg_yay_install $pkgs
            end

        case "*Yay*"
            __pkg_yay_menu "$FZF_COLORS" "$cache_file"

        case "*Uninstall*"
            set -l pkgs (
                pacman -Qe | awk '{print $1}' | fzf --multi \
                    $UNINSTALL_COLORS \
                    (__pkg_preview uninstall) \
                    --height 60% \
                    --layout reverse \
                    --border rounded \
                    --prompt="󰅙 Uninstall > " \
                    --pointer="" \
                    --marker="✗" \
                    --header="Select packages to REMOVE"
            )

            if test -n "$pkgs"
                __pkg_selected "PACKAGES MARKED FOR DELETION" ff6b68 ff6b68 $pkgs
                sudo pacman -Rns --noconfirm $pkgs
            end
    end
end
