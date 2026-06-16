#!/bin/bash

# ----- manga functions -----
MANGA_DIR="${MANGA_DIR:-$HOME}"
MANGA_CACHE_DIR="$HOME/.cache/scripts/manga"
MANGA_CACHE_FILE="$MANGA_CACHE_DIR/cache.txt"
MANGA_CACHE_MTIME="$MANGA_CACHE_DIR/cache-mtime.txt"
MANGA_HISTORY="$MANGA_CACHE_DIR/history.txt"

_manga_rofi_menu() {
    rofi -dmenu -i -no-custom -selected-row 0 -format i \
        -theme-str '* { font: "JetBrainsMono Nerd Font Medium 10.5"; bg: rgba(12,4,8,0.75); bg-alt: rgba(255,255,255,0.05); bg-hover: rgba(200,90,120,0.25); fg: #ffe0ec; muted: #b898a8; accent: #f8b4c8; glow: rgba(248,180,200,0.5); }' \
        -theme-str 'window { width: 54%; background-color: @bg; transparency: "real"; border: 2px; border-color: @glow; border-radius: 18px; }' \
        -theme-str 'mainbox { background-color: transparent; padding: 8px; spacing: 4px; }' \
        -theme-str 'inputbar { background-color: rgba(255,255,255,0.07); padding: 6px 10px; border: 1px; border-color: rgba(248,180,200,0.2); border-radius: 10px; children: [ entry ]; }' \
        -theme-str 'entry { background-color: transparent; text-color: @fg; placeholder-color: @muted; cursor-color: @accent; cursor-width: 2px; }' \
        -theme-str 'listview { columns: 1; lines: 12; fixed-height: false; dynamic: true; spacing: 2px; scrollbar: true; scrollbar-width: 4px; }' \
        -theme-str 'scrollbar { background-color: transparent; handle-color: @accent; handle-width: 4px; border-radius: 2px; }' \
        -theme-str 'element { background-color: @bg-alt; text-color: @fg; padding: 4px 8px; height: 28px; border: 1px; border-color: rgba(255,255,255,0.03); border-radius: 8px; }' \
        -theme-str 'element normal.normal { background-color: @bg-alt; text-color: @fg; }' \
        -theme-str 'element alternate.normal { background-color: @bg-alt; text-color: @fg; }' \
        -theme-str 'element selected.normal { background-color: @bg-hover; text-color: @accent; border: 2px; border-color: @accent; }' \
        -theme-str 'element-text { background-color: transparent; text-color: @fg; vertical-align: 0.5; highlight: bold #ffffff; }' \
        -theme-str 'element normal.normal element-text { background-color: transparent; text-color: @fg; }' \
        -theme-str 'element alternate.normal element-text { background-color: transparent; text-color: @fg; }' \
        -theme-str 'element selected.normal element-text { background-color: transparent; text-color: @accent; }' \
        -p "$1"
}

_manga_find() {
    find "$MANGA_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f -iname "*.cbz" -print 2>/dev/null | sed "s|^$HOME/||"
}

_manga_size() {
    du -h "$1" 2>/dev/null | awk '{print $1}'
}

_manga_pages() {
    zipinfo -1 "$1" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|webp|gif|bmp)$' | wc -l
}

_manga_get_mtime() {
    find "$MANGA_DIR" -type d \( -path "*/\.*" -o -path "*/node_modules" -o -path "*/.cache" -o -path "*/.local" -o -path "*/.config" \) -prune -o -type f -iname "*.cbz" -printf '%T@ %s %p\n' 2>/dev/null | sort | md5sum
}

_manga_build_cache() {
    local tmp
    tmp=$(mktemp)
    mkdir -p "$MANGA_CACHE_DIR"
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local size pages
        size=$(_manga_size "$HOME/$path")
        pages=$(_manga_pages "$HOME/$path")
        printf '%s\t%s\t%s\n' "$path" "$size" "$pages" >> "$tmp"
    done < <(_manga_find)
    mv "$tmp" "$MANGA_CACHE_FILE"
    _manga_get_mtime > "$MANGA_CACHE_MTIME"
}

_manga_refresh_cache() {
    if [[ ! -f "$MANGA_CACHE_FILE" ]] || [[ ! -f "$MANGA_CACHE_MTIME" ]]; then
        _manga_build_cache
        return
    fi
    local current cached
    current=$(_manga_get_mtime)
    cached=$(cat "$MANGA_CACHE_MTIME")
    [[ "$current" != "$cached" ]] && _manga_build_cache
}

_manga_sort() {
    local all hist
    all=$(mktemp)
    hist=$(mktemp)
    cut -f1 "$MANGA_CACHE_FILE" | sort > "$all"
    if [[ -f "$MANGA_HISTORY" ]]; then
        cat "$MANGA_HISTORY" > "$hist"
        grep -Fxv -f "$hist" "$all" | sort
        grep -Fx -f "$all" "$hist"
    else
        cat "$all"
    fi
    rm -f "$all" "$hist"
}

_manga_add_history() {
    mkdir -p "$(dirname "$MANGA_HISTORY")"
    local tmp
    tmp=$(mktemp)
    grep -Fxv "$1" "$MANGA_HISTORY" 2>/dev/null > "$tmp"
    printf '%s\n' "$1" >> "$tmp"
    mv "$tmp" "$MANGA_HISTORY"
}

case "${1:-}" in
    # ----- spotify (ALT + F1) -----
    # bind_exec("ALT + F1", "$HOME/.config/hypr/scripts/utils.sh spotify")
    spotify)
        if pgrep -x spotify >/dev/null 2>&1; then
            status=$(playerctl -p spotify status 2>/dev/null)
            [ "$status" = "Paused" ] && playerctl -p spotify play-pause
        else
            spotify &
        fi
        ;;

    # ----- random music (F1) -----
    # bind_exec("F1", "$HOME/.config/hypr/scripts/utils.sh play")
    play)
        if pgrep -x spotify >/dev/null 2>&1; then
            playerctl -p spotify next 2>/dev/null
            exit 0
        fi

        SOCKET="$HOME/.config/mpv-socket"
        MUSIC_DIR="$HOME/0/music"
        PLAYED_FILE="$HOME/.cache/scripts/music/play.txt"

        tmp_all=$(mktemp /tmp/play-all-XXXX.txt)
        tmp_unplayed=$(mktemp /tmp/play-unplayed-XXXX.txt)

        find "$MUSIC_DIR" -type f \( -name "*.mp3" -o -name "*.flac" \) 2>/dev/null | sort > "$tmp_all"
        touch "$PLAYED_FILE"
        grep -Fxv -f "$PLAYED_FILE" "$tmp_all" > "$tmp_unplayed"

        if [ ! -s "$tmp_unplayed" ]; then
            : > "$PLAYED_FILE"
            cp "$tmp_all" "$tmp_unplayed"
        fi

        file=$(shuf -n1 "$tmp_unplayed")
        printf '%s\n' "$file" >> "$PLAYED_FILE"
        rm -f "$tmp_all" "$tmp_unplayed"
        [ -z "$file" ] && exit 0

        if pgrep -x mpv >/dev/null; then
            { echo "loadfile \"$file\" insert-at"; echo "playlist-next"; echo "playlist-move 0 999"; } | socat - "$SOCKET" 2>/dev/null
        else
            mpv --no-video --no-resume-playback "$file" >/dev/null 2>&1 &
        fi
        ;;

    # ----- zeditor (SUPER + Z) -----
    # bind_exec("SUPER + Z", "$HOME/.config/hypr/scripts/utils.sh z")
    z)
        CLASS="dev.zed.Zed"
        EXEC="zeditor"
        PGEXEC="zed-editor"
        SPECIAL="zed"

        if ! pgrep -x "$PGEXEC" > /dev/null 2>&1; then
            "$EXEC" &
            exit 0
        fi

        DATA=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | \"\\(.address) \\(.workspace.name)\"" | head -1)

        if [ -z "$DATA" ]; then
            "$EXEC" &
            exit 0
        fi

        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [[ "$WS" == special* ]]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
        else
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
        fi
        ;;
    # ----- notes (ALT + N) -----
    # bind_exec("ALT + N", "$HOME/.config/hypr/scripts/utils.sh note")
    note)
        notes="$HOME/0/documents/txt/notes.txt"
        mkdir -p "$(dirname "$notes")"

        content=$(wl-paste 2>/dev/null)
        if [ -z "$content" ]; then
            hyprctl notify -1 2000 "rgb(cba6f7)" "󰅙 clipboard empty"
            exit 1
        fi

        last=$(tail -n 2 "$notes" 2>/dev/null | head -1)
        if [ "$last" = "$content" ]; then
            hyprctl notify -1 2000 "rgb(fab387)" "󰅜 duplicate"
            exit 0
        fi

        printf "%s\n-------------\n" "$content" >> "$notes"
        hyprctl notify -1 2000 "rgb(a6e3a1)" "󰄬 note saved"
        ;;
    # ----- mpv (ALT + M) -----
    # bind_exec("ALT + M", "$HOME/.config/hypr/scripts/utils.sh mpv")
    mpv)
        SPECIAL="mpv"
        CLASS="mpv"

        EXISTING_SPECIAL=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$SPECIAL\") | .address" | head -1)

        if [ -n "$EXISTING_SPECIAL" ]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
            exit 0
        fi

        DATA=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | \"\\(.address) \\(.workspace.name)\"" | head -1)

        if [ -n "$DATA" ]; then
            ADDR="${DATA%% *}"
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
            exit 0
        fi

        exit 0
        ;;

    # ----- kitty (ALT + Q) -----
    # bind_exec("ALT + Q", "$HOME/.config/hypr/scripts/utils.sh kitty")
    kitty)
        SPECIAL="kitty"
        CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.name')

        MPV_SPECIAL=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:mpv") | .address' | head -1)
        [ -n "$MPV_SPECIAL" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = '${CURRENT_WS}', window = 'address:${MPV_SPECIAL}' })"

        EXISTING=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty-float") | .address' | head -1)
        if [ -n "$EXISTING" ]; then
            IN_SPECIAL=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$EXISTING\" and .workspace.name == \"special:$SPECIAL\") | .address")
            if [ -n "$IN_SPECIAL" ]; then
                hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
            else
                hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${EXISTING}' })"
            fi
            exit 0
        fi
        kitty --class kitty-float &
        PID=$!
        for i in $(seq 1 20); do
            ADDR=$(hyprctl clients -j | jq -r ".[] | select(.pid == $PID) | .address" | head -1)
            [ -n "$ADDR" ] && break
            sleep 0.1
        done
        [ -n "$ADDR" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
        ;;

    # ----- telegram (ALT + T) -----
    # bind_exec("ALT + T", "$HOME/.config/hypr/scripts/utils.sh toggle")
    toggle)
        CLASS="org.telegram.desktop"
        EXEC="Telegram"
        SPECIAL="telegram"

        if ! pgrep -x "$EXEC" > /dev/null 2>&1; then
            "$EXEC" &
            exit 0
        fi

        DATA=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$CLASS\") | \"\\(.address) \\(.workspace.name)\"" | head -1)

        if [ -z "$DATA" ]; then
            "$EXEC" &
            exit 0
        fi

        ADDR="${DATA%% *}"
        WS="${DATA#* }"

        if [[ "$WS" == special* ]]; then
            hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SPECIAL\")"
        else
            hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:$SPECIAL', window = 'address:${ADDR}' })"
        fi
        ;;

    # ----- manga (ALT + M) -----
    # bind_exec("ALT + M", "$HOME/.config/hypr/scripts/utils.sh manga")
    manga)
        pkill -x rofi 2>/dev/null
        sleep 0.1
        _manga_refresh_cache
        [[ ! -f "$MANGA_CACHE_FILE" ]] && exit 0

        declare -a MANGA_PATHS MANGA_LABELS

        LAST_READ=$(tail -n 1 "$MANGA_HISTORY" 2>/dev/null)
        [[ -n "$LAST_READ" ]] && MANGA_PATHS+=("$LAST_READ") && MANGA_LABELS+=("➜ last")

        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            local info size pages
            info=$(grep -F "$path" "$MANGA_CACHE_FILE" | head -1)
            [[ -z "$info" ]] && continue
            size=$(printf '%s' "$info" | cut -f2)
            pages=$(printf '%s' "$info" | cut -f3)
            MANGA_PATHS+=("$path")
            MANGA_LABELS+=("$(printf '%-7s %-4s %s' "$size" "$pages" "$path")")
        done < <(_manga_sort)

        [[ ${#MANGA_PATHS[@]} -eq 0 ]] && exit 0

        idx=$(printf '%s\n' "${MANGA_LABELS[@]}" | _manga_rofi_menu "manga")
        [[ -z "$idx" ]] && exit 0

        choice="${MANGA_PATHS[$idx]}"
        [[ -z "$choice" ]] && exit 0

        file="$HOME/$choice"
        [[ -f "$file" ]] || exit 0

        if [[ "${MANGA_LABELS[$idx]}" == "➜ last" ]]; then
            zathura "$file" >/dev/null 2>&1 &
        else
            _manga_add_history "$choice"
            zathura "$file" >/dev/null 2>&1 &
        fi
        ;;
    # ----- workspace notify -----
    # exec("bash $HOME/.config/hypr/scripts/utils.sh workspace")
    workspace)
        STATE=true
        SHOW_CLASS=true
        ICONS=("" ➀ ➁ ➂ ➃ ➄ ➅ ➆ ➇ ➈ ➉)
        socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
            case "$line" in
                workspace\>\>*)
                    $STATE || continue
                    ws="${line#workspace>>}"
                    icon="●"
                    [[ "$ws" =~ ^[0-9]+$ ]] && icon="${ICONS[$ws]}"
                    msg="$icon"
                    if [ "$SHOW_CLASS" = "true" ]; then
                        sleep 0.1
                        class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
                        class=${class,,}
                        case "$class" in
                            org.telegram.desktop) class="telegram" ;;
                            dev.zed.zed) class="zed" ;;
                            org.pwmt.zathura|zathura) class="zathura" ;;
                            brave-browser) class="brave" ;;
                            code-oss) class="code" ;;
                        esac
                        [ -n "$class" ] && msg="$icon  $class"
                    fi
                    hyprctl dismissnotify 1 2>/dev/null
                    hyprctl notify 1 2000 "rgb(a6e3a1)" "fontsize:18 $msg" 2>/dev/null
                    ;;
            esac
        done
        ;;
    # ----- files (SUPER + I) -----
    # bind_exec("SUPER + I", "$HOME/.config/hypr/scripts/utils.sh files")
    files)
        CACHE_DIR="${HOME}/.cache/scripts/files"
        CACHE_FILE="${CACHE_DIR}/cache.txt"
        CACHE_MTIME_FILE="${CACHE_DIR}/cache-mtime.txt"
        HISTORY_FILE="${CACHE_DIR}/history.txt"
        LIMIT=5000

        ROFI_THEME=(
            -theme-str '* { font: "JetBrainsMono Nerd Font Medium 10.5"; bg: rgba(12,4,8,0.75); bg-alt: rgba(255,255,255,0.05); bg-hover: rgba(200,90,120,0.25); fg: #ffe0ec; muted: #b898a8; accent: #f8b4c8; glow: rgba(248,180,200,0.5); }'
            -theme-str 'window { width: 54%; background-color: @bg; transparency: "real"; border: 2px; border-color: @glow; border-radius: 18px; }'
            -theme-str 'mainbox { background-color: transparent; padding: 8px; spacing: 4px; }'
            -theme-str 'inputbar { background-color: rgba(255,255,255,0.07); padding: 6px 10px; border: 1px; border-color: rgba(248,180,200,0.2); border-radius: 10px; children: [ entry ]; }'
            -theme-str 'entry { background-color: transparent; text-color: @fg; placeholder-color: @muted; cursor-color: @accent; cursor-width: 2px; }'
            -theme-str 'listview { columns: 1; lines: 12; fixed-height: false; dynamic: true; spacing: 2px; scrollbar: true; scrollbar-width: 4px; }'
            -theme-str 'scrollbar { background-color: transparent; handle-color: @accent; handle-width: 4px; border-radius: 2px; }'
            -theme-str 'element { background-color: @bg-alt; text-color: @fg; padding: 4px 8px; height: 28px; border: 1px; border-color: rgba(255,255,255,0.03); border-radius: 8px; }'
            -theme-str 'element normal.normal { background-color: @bg-alt; text-color: @fg; }'
            -theme-str 'element alternate.normal { background-color: @bg-alt; text-color: @fg; }'
            -theme-str 'element selected.normal { background-color: @bg-hover; text-color: @accent; border: 2px; border-color: @accent; }'
            -theme-str 'element-text { background-color: transparent; text-color: @fg; vertical-align: 0.5; highlight: bold #ffffff; }'
            -theme-str 'element normal.normal element-text { background-color: transparent; text-color: @fg; }'
            -theme-str 'element alternate.normal element-text { background-color: transparent; text-color: @fg; }'
            -theme-str 'element selected.normal element-text { background-color: transparent; text-color: @accent; }'
        )

        _files_rofi_menu() {
            local lines="${2:-12}"
            rofi -dmenu -i -no-custom \
                "${ROFI_THEME[@]}" \
                -theme-str "listview { columns: 1; lines: ${lines}; }" \
                -p "$1"
        }

        _files_get_mtime() {
            find "$HOME" -maxdepth 2 -type d ! -path "*/.local" ! -path "*/.cache" | xargs stat --format="%Y %n" 2>/dev/null | sort | md5sum
        }

        _files_build_cache() {
            local tmp
            tmp=$(mktemp)
            mkdir -p "$CACHE_DIR"

            local fd_args=(
                --type f --hidden --absolute-path
                --exclude .git --exclude node_modules --exclude .cache --exclude __pycache__
                --exclude .venv --exclude venv --exclude target --exclude build --exclude dist
                --exclude .npm --exclude .cargo --exclude .rustup
                --exclude .local --exclude .var --exclude .flatpak --exclude .fonts --exclude .icons
            )

            local dir_args=(
                --type d --hidden --absolute-path
                --exclude .git --exclude node_modules --exclude .cache --exclude __pycache__
                --exclude .venv --exclude venv --exclude target --exclude build --exclude dist
                --exclude .npm --exclude .cargo --exclude .rustup
                --exclude .local --exclude .var --exclude .flatpak --exclude .fonts --exclude .icons
            )

            fd "${dir_args[@]}" . "$HOME" 2>/dev/null | sed "s|$HOME/||" | head -n $LIMIT | \
                while IFS= read -r line; do
                    printf 'dir\t%s\n' "$line"
                done >> "$tmp"

            fd "${fd_args[@]}" . "$HOME" 2>/dev/null | sed "s|$HOME/||" | head -n $LIMIT | \
                while IFS= read -r line; do
                    printf 'file\t%s\n' "$line"
                done >> "$tmp"

            mv "$tmp" "$CACHE_FILE"
            _files_get_mtime > "$CACHE_MTIME_FILE"
        }

        _files_refresh_cache() {
            if [[ ! -f "$CACHE_FILE" ]] || [[ ! -f "$CACHE_MTIME_FILE" ]]; then
                _files_build_cache
                return
            fi
            local current_mtime
            current_mtime=$(_files_get_mtime)
            local cached_mtime
            cached_mtime=$(cat "$CACHE_MTIME_FILE")
            if [[ "$current_mtime" != "$cached_mtime" ]]; then
                _files_build_cache
            fi
        }

        _files_get_count() {
            local type="$1"
            awk -F'\t' '$1 == "'"$type"'" {count++} END {print count+0}' "$CACHE_FILE" 2>/dev/null
        }

        _files_get_text_count() {
            grep -E $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$CACHE_FILE" | wc -l
        }

        _files_get_config_count() {
            local dirs=(aria2 gallery-dl kitty rofi swayimg mpv swaync fish yt-dlp zathura hypr waybar)
            local count=0
            for d in "${dirs[@]}"; do
                [[ -d "$HOME/.config/$d" ]] && ((count++))
                if [[ -d "$HOME/.config/$d" ]]; then
                    count=$((count + $(find "$HOME/.config/$d" -type f 2>/dev/null | wc -l)))
                fi
            done
            echo "$count"
        }

        _files_save_history() {
            mkdir -p "$(dirname "$HISTORY_FILE")"
            local tmp
            tmp=$(mktemp)
            grep -Fxv "$1" "$HISTORY_FILE" 2>/dev/null > "$tmp"
            printf '%s\n' "$1" >> "$tmp"
            mv "$tmp" "$HISTORY_FILE"
        }

        pkill -x rofi 2>/dev/null
        sleep 0.1

        _files_refresh_cache

        file_count=$(_files_get_count file)
        dir_count=$(_files_get_count dir)
        text_count=$(_files_get_text_count)
        config_count=$(_files_get_config_count)

        LAST_READ=$(tail -n 1 "$HISTORY_FILE" 2>/dev/null | grep -v '^$')
        menu_entries=""
        [[ -n "$LAST_READ" ]] && menu_entries+="➜  last\n"
        menu_entries+="󰉋  All Folders ($dir_count)\n󰈙  All Files ($file_count)\n󰈙  Text Files ($text_count)\n󰒓  Config Files ($config_count)\n󰈙  Other Files"

        chosen=$(printf '%b' "$menu_entries" | _files_rofi_menu "❀  Files:" 6)

        [ -z "$chosen" ] && exit 0

        file=""

        if [[ "$chosen" == "➜  last" ]]; then
            file="$LAST_READ"
            fullpath="$HOME/$file"
            if [ -f "$fullpath" ] || [ -d "$fullpath" ]; then
                if command -v zeditor &>/dev/null; then
                    nohup zeditor "$fullpath" >/dev/null 2>&1 &
                else
                    nohup thunar "$fullpath" >/dev/null 2>&1 &
                fi
            else
                hyprctl notify -1 2000 0 "fontsize:16 󰅙 last not found"
            fi
            exit 0
        fi

        file=""

        if [[ "$chosen" == *"All Folders"* ]]; then
            file=$(grep $'^dir\t' "$CACHE_FILE" | cut -f2 | sed 's/^/󰉋  /' | _files_rofi_menu "󰉋  Folders:")
            file="${file#󰉋  }"

        elif [[ "$chosen" == *"All Files"* ]]; then
            file=$(grep $'^file\t' "$CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _files_rofi_menu "󰈙  Files:")
            file="${file#󰈙  }"

        elif [[ "$chosen" == *"Text Files"* ]]; then
            file=$(grep -E $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _files_rofi_menu "󰈙  Text:")
            file="${file#󰈙  }"

        elif [[ "$chosen" == *"Config Files"* ]]; then
            config_dirs=(aria2 gallery-dl kitty rofi swayimg mpv swaync fish yt-dlp zathura hypr waybar)
            config_entries="󰒓  Open All\n"
            for d in "${config_dirs[@]}"; do
                if [[ -d "$HOME/.config/$d" ]]; then
                    config_entries+="󰉋  $d\n"
                    while IFS= read -r f; do
                        rel=$(echo "$f" | sed "s|$HOME/.config/$d/||")
                        config_entries+="󰈙  $d/$rel\n"
                    done < <(find "$HOME/.config/$d" -type f 2>/dev/null | sort)
                fi
            done
            file=$(printf '%b' "$config_entries" | _files_rofi_menu "󰒓  Config:")
            [[ "$file" == "󰒓  Open All" ]] && {
                if command -v zeditor &>/dev/null; then
                    zeditor "$HOME/.config/aria2" "$HOME/.config/gallery-dl" "$HOME/.config/kitty" "$HOME/.config/rofi" "$HOME/.config/swayimg" "$HOME/.config/mpv" "$HOME/.config/swaync" "$HOME/.config/fish" "$HOME/.config/yt-dlp" "$HOME/.config/zathura" "$HOME/.config/hypr" "$HOME/.config/waybar" &>/dev/null &
                else
                    thunar "$HOME/.config/aria2" "$HOME/.config/gallery-dl" "$HOME/.config/kitty" "$HOME/.config/rofi" "$HOME/.config/swayimg" "$HOME/.config/mpv" "$HOME/.config/swaync" "$HOME/.config/fish" "$HOME/.config/yt-dlp" "$HOME/.config/zathura" "$HOME/.config/hypr" "$HOME/.config/waybar" &>/dev/null &
                fi
                exit 0
            }
            file="${file#󰉋  }"
            file="${file#󰈙  }"
            [[ -n "$file" ]] && file=".config/$file"

        else
            file=$(grep -Ev $'^file\t.*\.(sh|txt|py|lua|json|js|ts|css|html|conf|md|rs|toml|xml|yaml|yml|ini|c|cpp|h|hpp|go|java|rb|php|sql|fish|log|desktop|service|bash|zsh|vim|nvim)$' "$CACHE_FILE" | cut -f2 | sed 's/^/󰈙  /' | _files_rofi_menu "󰈙  Other:")
            file="${file#󰈙  }"
        fi

        [ -z "$file" ] && exit 0

        fullpath="$HOME/$file"

        if [ -d "$fullpath" ]; then
            if command -v zeditor &>/dev/null; then
                nohup zeditor "$fullpath" >/dev/null 2>&1 &
            else
                nohup thunar "$fullpath" >/dev/null 2>&1 &
            fi
            _files_save_history "$file"
        elif [ -f "$fullpath" ]; then
            case "$fullpath" in
                *.sh|*.txt|*.py|*.lua|*.json|*.js|*.ts|*.css|*.html|*.conf|*.md|*.rs|*.toml|*.xml|*.yaml|*.yml|*.ini|*.c|*.cpp|*.h|*.hpp|*.go|*.java|*.rb|*.php|*.sql|*.fish|*.desktop|*.service|*.bash|*.zsh|*.vim|*.nvim|*.log)
                    zeditor "$fullpath" &>/dev/null &
                    ;;
                *.cbz|*.cbr|*.pdf)
                    zathura "$fullpath" &>/dev/null &
                    ;;
                *.mp4|*.mp3|*.mkv|*.webm|*.avi|*.mov|*.flv|*.m4a|*.ogg|*.flac|*.wav|*.aac|*.opus|*.wma)
                    mpv "$fullpath" &>/dev/null &
                    ;;
                *)
                    xdg-open "$fullpath" &>/dev/null &
                    ;;
            esac
            _files_save_history "$file"
        else
            hyprctl notify -1 2000 0 "fontsize:16 󰅙 not found"
        fi
        ;;
    *)
        echo "Usage: $0 {toggle|play|z|note|manga|files|workspace}"
        exit 1
        ;;
esac
