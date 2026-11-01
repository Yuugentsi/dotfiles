# ─────────── pkg ───────────
function ins --description 'Unified package manager'
    set -g PKG_PREVIEW true

    function __pkg_need -a cmd pkg
        command -v $cmd >/dev/null 2>&1; and return 0
        set_color -b f9e2af 11111b --bold
        printf " 󰋼 %s " "$pkg"
        set_color normal
        printf " installing...\n"
        sudo pacman -S --noconfirm $pkg
    end

    function __pkg_need_yay
        command -v yay >/dev/null 2>&1; and return 0

        set_color -b f38ba8 11111b --bold
        printf " 󰀦 YAY "
        set_color normal
        printf " building from AUR...\n"

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
            set_color -b 89dceb 11111b --bold
            printf " 󰇚 AUR "
            set_color normal
            printf " downloading package catalog...\n"

            set -l archive_file (mktemp)
            set -l unpacked_file "$cache_file.tmp"

            curl --fail --location --progress-bar --show-error \
                --output "$archive_file" \
                "https://aur.archlinux.org/packages.gz"; or begin
                rm -f "$archive_file"
                return 1
            end

            printf '\033[1A\r\033[2K\033[1A\r\033[2K' >&2
            printf " 󰇚 AUR unpacking package catalog...\n"
            gunzip -c "$archive_file" > "$unpacked_file"; or begin
                rm -f "$archive_file" "$unpacked_file"
                return 1
            end
            printf '\033[1A\r\033[2K' >&2

            mv "$unpacked_file" "$cache_file"; or begin
                rm -f "$archive_file" "$unpacked_file"
                return 1
            end
            rm -f "$archive_file"
        end
    end

    function __pkg_selected -a title badge_color item_color
        set -l pkgs $argv[4..-1]
        set -l total (count $pkgs)
        test $total -gt 0; or return
        echo
        set_color -b $badge_color 11111b --bold
        printf " 󰏗 %s " "$title"
        set_color -b 313244 cdd6f4
        printf " %s " "$total"
        set_color normal
        echo
        for i in (seq $total)
            set_color $item_color
            if test $total -eq 1
                printf "  ╰─❯ "
            else if test $i -eq $total
                printf "  ╰─❯ "
            else
                printf "  ├─❯ "
            end
            set_color cdd6f4 --bold
            printf "%s\n" "$pkgs[$i]"
        end
        set_color normal
        echo
    end

    function __pkg_yay_install
        if command -v yay >/dev/null 2>&1
            yay -S --noconfirm $argv; or return 1
            yay -Yc --noconfirm 2>/dev/null
        else
            sudo pacman -S --noconfirm --color=always $argv; or return 1
        end
    end

    function __pkg_preview -a source
        switch $source
            case installed
                printf '%s\n' --preview 'pacman -Qi --color=always {1}' --preview-window='right:55%:wrap:border-rounded'
            case aur
                printf '%s\n' --preview 'yay -Si --color=always {2}' --preview-window='right:55%:wrap:border-rounded'
            case packages
                printf '%s\n' --preview 'pacman -Si --color=always {2} 2>/dev/null || yay -Si --color=always {2} 2>/dev/null' --preview-window='right:55%:wrap:border-rounded'
        end
    end

    function __pkg_update
        echo
        set_color -b 89b4fa 11111b --bold
        printf " 󰇚 UPGRADE "
        set_color normal
        echo
        if command -v yay >/dev/null 2>&1
            yay -Syu --noconfirm --color=always
        else
            sudo pacman -Syu --noconfirm --color=always
        end
    end

    function __pkg_clean
        echo
        set_color -b f9e2af 11111b --bold
        printf " 󰃢 CLEAN "
        set_color normal
        echo
        if test -d /var/cache/pacman/pkg
            sudo find /var/cache/pacman/pkg -maxdepth 1 \( -name 'download-*' -o -name '*.part' \) -exec rm -rf -- {} + 2>/dev/null
        end
        if command -v yay >/dev/null 2>&1
            yay -Sc --noconfirm
        else
            sudo pacman -Sc --noconfirm
        end
    end

    function __pkg_uninstall -a UNINSTALL_COLORS
        set -l remove_pkgs (
            pacman -Qe | awk '{print $1}' | fzf --multi \
                $UNINSTALL_COLORS \
                --height=75% \
                --layout=reverse \
                --border=rounded \
                --border-label=" 󰅙 Installed " \
                --border-label-pos=2 \
                --prompt="󰅙  " \
                --header="󰘳 Tab 󰌑 Enter 󰍉 Ctrl-/" \
                --pointer="❯" \
                --marker="✖" \
                --separator="─" \
                --scrollbar="│" \
                --highlight-line \
                --info=inline-right \
                --bind="ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all" \
                (__pkg_preview installed) \
                --preview-label=" 󰋼 Info " \
                --preview-label-pos=2
        )

        if test -n "$remove_pkgs"
            __pkg_selected "REMOVAL" f38ba8 f38ba8 $remove_pkgs
            sudo pacman -Rns --noconfirm $remove_pkgs
        end
    end

    function __pkg_aur_menu -a FZF_COLORS cache_file
        __pkg_need_yay; or return 1
        __pkg_aur_cache "$cache_file"

        set -l pkgs (
            awk '{print "󰣇 " $1}' "$cache_file" | fzf --multi \
                $FZF_COLORS \
                --height=75% \
                --layout=reverse \
                --border=rounded \
                --border-label=" 󰣇 AUR " \
                --border-label-pos=2 \
                --prompt="󰣇  " \
                --header="󰘳 Tab 󰌑 Enter 󰍉 Ctrl-/" \
                --pointer="❯" \
                --marker="✔" \
                --separator="─" \
                --scrollbar="│" \
                --highlight-line \
                --info=inline-right \
                --bind="ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all" \
                (__pkg_preview aur) \
                --preview-label=" 󰋼 Details " \
                --preview-label-pos=2
        )

        set -l real_pkgs (printf "%s\n" $pkgs | awk '{print $NF}')
        if test -n "$real_pkgs"
            __pkg_selected "AUR" cba6f7 cba6f7 $real_pkgs
            __pkg_yay_install $real_pkgs
        end
    end

    function __pkg_help
        echo
        set_color -b 89b4fa 11111b --bold
        printf " 󰮯 INS "
        set_color normal
        echo
        echo
        set_color cdd6f4 --bold
        printf "Usage: "
        set_color 89dceb
        printf "ins "
        set_color a6adc8
        printf "[options] [package]\n\n"
        set_color 89b4fa
        printf "  ins                 "
        set_color cdd6f4
        printf "Interactive explorer\n"
        set_color 89b4fa
        printf "  ins <query>         "
        set_color cdd6f4
        printf "Search & install\n"
        set_color 89b4fa
        printf "  ins -u, --update    "
        set_color cdd6f4
        printf "Upgrade system\n"
        set_color 89b4fa
        printf "  ins -r, --remove    "
        set_color cdd6f4
        printf "Uninstall packages\n"
        set_color 89b4fa
        printf "  ins -a, --aur       "
        set_color cdd6f4
        printf "Search AUR\n"
        set_color 89b4fa
        printf "  ins -c, --clean     "
        set_color cdd6f4
        printf "Clean cache\n"
        set_color 89b4fa
        printf "  ins -h, --help      "
        set_color cdd6f4
        printf "Show help\n\n"
        set_color normal
    end

    __pkg_need fzf fzf; or return 1

    set -l FZF_COLORS "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#89b4fa,info:#cba6f7,pointer:#f5e0dc,marker:#a6e3a1,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8,border:#89b4fa,label:#89b4fa,query:#cdd6f4"
    set -l UNINSTALL_COLORS "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f38ba8,marker:#f38ba8,fg+:#f38ba8,prompt:#f38ba8,hl+:#eba0ac,border:#f38ba8,label:#f38ba8,query:#cdd6f4"
    set -l cache_file "$HOME/.cache/aur_packages"

    if test (count $argv) -gt 0
        switch $argv[1]
            case -h --help help
                __pkg_help
                return

            case -u --update update
                __pkg_update
                return

            case -r --remove remove uninstall
                __pkg_uninstall $UNINSTALL_COLORS
                return

            case -a --aur aur
                __pkg_aur_menu $FZF_COLORS "$cache_file"
                return

            case -c --clean clean
                __pkg_clean
                return

            case '*'
                set -l query $argv[1]

                pacman -Si "$query" >/dev/null 2>&1
                if test $status -eq 0
                    sudo pacman -S --noconfirm --color=always $argv
                    return
                end

                set -l selected (
                    pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}' | fzf --multi \
                        $FZF_COLORS \
                        --query="$query" \
                        --height=75% \
                        --layout=reverse \
                        --border=rounded \
                        --border-label=" 󰮯 Search " \
                        --border-label-pos=2 \
                        --prompt="󰮯  " \
                        --header="󰘳 Tab 󰌑 Enter 󰍉 Ctrl-/" \
                        --pointer="❯" \
                        --marker="✔" \
                        --separator="─" \
                        --scrollbar="│" \
                        --highlight-line \
                        --info=inline-right \
                        --bind="ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all" \
                        (__pkg_preview packages) \
                        --preview-label=" 󰋼 Info " \
                        --preview-label-pos=2
                )

                set -l real_pkgs (printf "%s\n" $selected | awk '{print $NF}')
                if test -n "$real_pkgs"
                    __pkg_selected "PACKAGES" 89b4fa 89b4fa $real_pkgs
                    sudo pacman -S --noconfirm --color=always $real_pkgs
                end
                return
        end
    end

    set -l pkgs (
        begin
            printf "%s\n" "󰏗 All" "󰇚 Update" "󰅙 Uninstall" "󰃢 Clean"
            pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}'
        end | fzf --multi \
            $FZF_COLORS \
            --height=75% \
            --layout=reverse \
            --border=rounded \
            --border-label=" 󰮯 Packages " \
            --border-label-pos=2 \
            --prompt="󰮯  " \
            --header="󰘳 Tab 󰌑 Enter 󰍉 Ctrl-/" \
            --pointer="❯" \
            --marker="✔" \
            --separator="─" \
            --scrollbar="│" \
            --highlight-line \
            --info=inline-right \
            --bind="ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all" \
            (__pkg_preview packages) \
            --preview-label=" 󰋼 Info " \
            --preview-label-pos=2
    )

    test -z "$pkgs"; and return

    switch $pkgs[1]
        case "*Update*"
            __pkg_update

        case "*Uninstall*"
            __pkg_uninstall $UNINSTALL_COLORS

        case "*Clean*"
            __pkg_clean

        case "*All*"
            __pkg_need_yay; or return 1
            __pkg_aur_cache "$cache_file"

            set -l pkgs (
                begin
                    pacman -Sl | awk '!/\[installed\]$/ {print "󰮯 " $2}'
                    awk '{print "󰣇 " $1}' "$cache_file"
                end | fzf --multi \
                    $FZF_COLORS \
                    --height=75% \
                    --layout=reverse \
                    --border=rounded \
                    --border-label=" 󰏗 Repos " \
                    --border-label-pos=2 \
                    --prompt="󰏗  " \
                    --header="󰘳 Tab 󰌑 Enter 󰍉 Ctrl-/" \
                    --pointer="❯" \
                    --marker="✔" \
                    --separator="─" \
                    --scrollbar="│" \
                    --highlight-line \
                    --info=inline-right \
                    --bind="ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all" \
                    (__pkg_preview packages) \
                    --preview-label=" 󰋼 Details " \
                    --preview-label-pos=2
            )

            set -l real_pkgs (printf "%s\n" $pkgs | awk '{print $NF}')
            if test -n "$real_pkgs"
                __pkg_selected "PACKAGES" cba6f7 cba6f7 $real_pkgs
                __pkg_yay_install $real_pkgs
            end

        case "*"
            set -l real_pkgs (printf "%s\n" $pkgs | grep -v -E "󰏗|󰇚|󰅙|󰃢" | awk '{print $NF}')
            if test -n "$real_pkgs"
                __pkg_selected "PACKAGES" 89b4fa 89b4fa $real_pkgs
                sudo pacman -S --noconfirm --color=always $real_pkgs
            end
    end
end
