# ─────────── config ───────────
set -g _config_dirs aria2 gallery-dl kitty rofi swayimg mpv swaync fish \
                     yt-dlp zathura hypr waybar niri wofi quickshell

function _config_backup
    set -l c "$HOME/.config"
    set -l stamp (date +"%H-%M-%S_%m-%d-%Y")
    set -l out "$HOME/$stamp.zip"
    set -l paths
    for d in $_config_dirs
        test -d "$c/$d" && set -a paths "$c/$d"
    end
    zip -r "$out" $paths >/dev/null 2>&1
    echo "→ $out"
end

function config -d "open config dirs"
    set -l c "$HOME/.config"
    rm -f /tmp/config_action

    set -l result (printf '%s\n' $_config_dirs | fzf \
        --prompt=" config > " \
        --border=rounded \
        --margin=1 \
        --padding=1 \
        --info=inline \
        --select-1 \
        --ignore-case \
        --bind='ctrl-a:execute(echo ALL > /tmp/config_action)+abort' \
        --bind='ctrl-b:execute(echo BACKUP > /tmp/config_action)+abort' \
        --header="ctrl-a: all  |  ctrl-b: backup  |  esc: cancel" \
        --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7,hl+:#cba6f7,fg+:#f5f5f7,bg+:#313244,pointer:#f38ba8,prompt:#89dceb,spinner:#f9e2af,info:#a6adc8,border:#45475a,header:#a6e3a1)

    if test -f /tmp/config_action
        set -l action (cat /tmp/config_action)
        rm -f /tmp/config_action

        if test "$action" = "ALL"
            set -l paths
            for d in $_config_dirs
                test -d "$c/$d" && set -a paths "$c/$d"
            end
            zeditor $paths &
            disown
            exit
        else if test "$action" = "BACKUP"
            _config_backup
            return 0
        end
    end

    if test -z "$result"
        return 0
    end

    test -d "$c/$result" && zeditor "$c/$result" &
    disown
    exit
end

# ─────────── b-config ───────────
# b       → text → clipboard
#         → ✿ b file.txt
# ───────────────────────────
# ba      → file → path clipboard
#         → ✿ ba file.txt
# ───────────────────────────
# bzip    → zip files
#         → ✿ bzip mpv hypr aria2
# ───────────────────────────
# bconfig → dotfiles zip
#         → ✿ bconfig
# ───────────────────────────
function bconfig -d "zip dotfiles backup"
    set -l base "$HOME"
    set -l config "$HOME/.config"
    set -l dir "$HOME/.cache/bzip"
    set -l zipname "dotfiles_"(date "+%m-%d-%y_%H-%M-%S")".zip"
    set -l zipfile "$dir/$zipname"

    set -l items aria2 fish fuzzel gallery-dl hypr kitty mpv nano nvim qt6ct river rofi swayimg swaync waybar wofi yt-dlp zathura zed
    set -l valid_items

    mkdir -p "$dir"
    rm -f "$zipfile"

    for item in $items
        if test -e "$config/$item"
            set -a valid_items ".config/$item"
        else
            hyprctl notify 5 3000 "rgb(ff0000)" "󰈔 $item"
        end
    end

    if test (count $valid_items) -eq 0
        return 1
    end

    pushd "$base" >/dev/null
    command zip -qr "$zipfile" $valid_items
    popd >/dev/null

    set -l folders 0
    set -l files_count 0

    for item in $valid_items
        if test -d "$base/$item"
            set folders (math $folders + (find "$base/$item" -type d | wc -l | string trim))
            set files_count (math $files_count + (find "$base/$item" -type f | wc -l | string trim))
        else
            set files_count (math $files_count + 1)
        end
    end

    printf 'file://%s\r\n' "$zipfile" | wl-copy --type text/uri-list

    hyprctl notify 5 5000 "rgb(00ff00)" "󰡨 $zipname"
    hyprctl notify 5 7000 "rgb(00ff00)" "󰉋 $folders  󰈔 $files_count → .config"
end


function b -d "copy file content to clipboard"
    clear
    if test -z "$argv[1]"
        set -l P (set_color cba6f7)
        set -l W (set_color white)
        set -l N (set_color normal)

        echo "$P󰆍$N"
        echo "$P  ────────────────────────────$N"
        echo "$W  b$N       $P text → clipboard$N"
        echo "           $P b file.conf$N"
        echo "$P  ────────────────────────────$N"
        echo "$W  ba$N      $P file path → clipboard$N"
        echo "           $P ba file.txt$N"
        echo "$P  ────────────────────────────$N"
        echo "$W  bzip$N    $P zip files$N"
        echo "           $P bzip mpv hypr aria2$N"
        echo "$P  ────────────────────────────$N"
        echo "$W  bconfig$N $P zip dotfiles$N"
        echo "           $P bconfig$N"
        echo "$P  ────────────────────────────$N"
        return 0
    end

    if not test -f "$argv[1]"
        hyprctl notify 5 3000 "rgb(ff0000)" "󰈔 $argv[1]"
        return 1
    end

    set -l lines (wc -l < "$argv[1]" | string trim)
    wl-copy < "$argv[1]"

    hyprctl notify 5 3000 "rgb(00ff00)" "$(basename "$argv[1]") → clipboard ($lines lines)"
end


function ba -d "copy file path to clipboard"
    if test -z "$argv[1]"
        hyprctl notify 5 3000 "rgb(ff0000)" "󰈔"
        return 1
    end

    if not test -f "$argv[1]"
        hyprctl notify 5 3000 "rgb(ff0000)" "󰈔 $argv[1]"
        return 1
    end

    set -l file_path (realpath "$argv[1]")
    set -l file_name (basename "$file_path")
    set -l lines (wc -l < "$file_path" | string trim)

    printf 'file://%s\r\n' "$file_path" | wl-copy --type text/uri-list
    hyprctl notify 5 3000 "rgb(00ff00)" "$file_name → file ($lines lines)"
end


function bzip -d "zip files & copy path"
    if test (count $argv) -eq 0
        hyprctl notify 5 3000 "rgb(ff0000)" "󰈔"
        return 1
    end

    if not type -q zip
        hyprctl notify 5 3000 "rgb(ff0000)" "󰢦 zip"
        return 1
    end

    set -l dir "$HOME/.cache/bzip"
    set -l zipname "bzip_"(date "+%m-%d-%y_%H-%M-%S")".zip"
    set -l zipfile "$dir/$zipname"

    mkdir -p "$dir"
    rm -f "$zipfile"

    set -l valid_items

    for item in $argv
        if test -e "$item"
            set -a valid_items "$item"
        else
            hyprctl notify 5 3000 "rgb(ff0000)" "󰈔 $item"
        end
    end

    if test (count $valid_items) -eq 0
        return 1
    end

    command zip -qr "$zipfile" $valid_items

    set -l folders 0
    set -l files_count 0
    set -l names

    for item in $valid_items
        set -a names (basename "$item")

        if test -d "$item"
            set folders (math $folders + (find "$item" -type d | wc -l | string trim))
            set files_count (math $files_count + (find "$item" -type f | wc -l | string trim))
        else
            set files_count (math $files_count + 1)
        end
    end

    printf 'file://%s\r\n' "$zipfile" | wl-copy --type text/uri-list

    hyprctl notify 5 5000 "rgb(00ff00)" "$zipname"
    hyprctl notify 5 7000 "rgb(00ff00)" "$folders dirs • $files_count files → "(string join ", " $names)
end
