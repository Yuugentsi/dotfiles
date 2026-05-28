#!/bin/bash
# bind_exec("ALT + G", "$HOME/.config/hypr/scripts/video.sh")
VIDEO_DIR="${VIDEO_DIR:-$HOME/media/videos}"
VIDEO_LAST="$HOME/.cache/scripts/video/last_video"
SHOW_LAST_VIDEO="${SHOW_LAST_VIDEO:-TRUE}"
YT_LIST="${YT_LIST:-$HOME/media/documents/txt/yt.txt}"

cleanup_empty_video_dirs() {
    find "$VIDEO_DIR" -depth -type d ! -path "$VIDEO_DIR" -print0 2>/dev/null \
        | while IFS= read -r -d '' dir; do
            rmdir "$dir" 2>/dev/null || true
        done
}

run_mpv() {
    pgrep -x mpv | grep -v $$ | xargs -r kill -9 2>/dev/null
    sleep 0.1
    local args=()
    for f in "$@"; do
        if [[ "$f" =~ \.(opus|flac|mp3)$ ]]; then
            args+=(--no-resume-playback)
            break
        fi
    done
    /usr/bin/mpv "${args[@]}" "$@"
    cleanup_empty_video_dirs
}

_video_rofi_menu() {
    rofi -dmenu -i -no-custom \
        -theme-str 'window { width: 520px; }' \
        -theme-str 'mainbox { padding: 0px; spacing: 0px; }' \
        -theme-str 'inputbar { padding: 8px; }' \
        -theme-str 'listview { columns: 1; lines: 8; fixed-height: false; dynamic: true; spacing: 0px; }' \
        -theme-str 'element { padding: 4px 8px; }' \
        -p "$1"
}

_video_rofi_custom_menu() {
    rofi -dmenu -i -no-custom -kb-custom-1 "Control+t" -kb-custom-2 "Control+r" \
        -theme-str 'window { width: 520px; }' \
        -theme-str 'mainbox { padding: 0px; spacing: 0px; }' \
        -theme-str 'inputbar { padding: 8px; }' \
        -theme-str 'listview { columns: 1; lines: 8; fixed-height: false; dynamic: true; spacing: 0px; }' \
        -theme-str 'element { padding: 4px 8px; }' \
        -p "$1"
}

_video_files_find() {
    find "$1" -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \
        -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" \
    \) 2>/dev/null
}

_video_files_count() {
    _video_files_find "$1" | wc -l
}

_video_play_file() {
    mkdir -p "$HOME/.cache/scripts/video"
    printf '%s\n' "$1" > "$VIDEO_LAST"
    run_mpv "$1" >/dev/null 2>&1 &
}

_video_play_all() {
    local dir="$1"
    local tmp_playlist

    tmp_playlist=$(mktemp /tmp/video-playlist-XXXX.m3u)
    _video_files_find "$dir" | sort > "$tmp_playlist"

    [[ ! -s "$tmp_playlist" ]] && rm -f "$tmp_playlist" && exit 0

    : > /tmp/video-picker-random-played.txt
    run_mpv --playlist="$tmp_playlist" >/dev/null 2>&1 &
    exit 0
}

_video_random_no_repeat() {
    local RANDOM_PLAYED="/tmp/video-picker-random-played.txt"
    local tmp_all tmp_unplayed random_video

    tmp_all=$(mktemp /tmp/video-picker-all-XXXX.txt)
    tmp_unplayed=$(mktemp /tmp/video-picker-unplayed-XXXX.txt)

    _video_files_find "$VIDEO_DIR" | sort > "$tmp_all"
    touch "$RANDOM_PLAYED"

    grep -Fxv -f "$RANDOM_PLAYED" "$tmp_all" > "$tmp_unplayed"

    if [[ ! -s "$tmp_unplayed" ]]; then
        : > "$RANDOM_PLAYED"
        cp "$tmp_all" "$tmp_unplayed"
    fi

    random_video=$(shuf -n1 "$tmp_unplayed")

    rm -f "$tmp_all" "$tmp_unplayed"

    [[ -z "$random_video" ]] && exit 0

    printf '%s\n' "$random_video" >> "$RANDOM_PLAYED"
    _video_play_file "$random_video"
    exit 0
}

_yt_count() {
    [[ ! -f "$YT_LIST" ]] && echo 0 && return
    awk '
        /^----/ || /^$/ { next }
        {
            title = $0
            if ((getline nxt) <= 0) next
            if (nxt ~ /^[0-9]{4}/) { count++; getline; next }
            if (nxt ~ /^https?:\/\//) { count++; next }
        }
        END { print count+0 }
    ' "$YT_LIST"
}

_yt_list_entries() {
    [[ ! -f "$YT_LIST" ]] && return
    awk '
        /^----/ || /^$/ { next }
        {
            title = $0
            if ((getline nxt) <= 0) next
            if (nxt ~ /^[0-9]{4}/) {
                print nxt " - " title
                getline
                next
            }
            if (nxt ~ /^https?:\/\//) {
                print title
                next
            }
        }
    ' "$YT_LIST"
}

_yt_get_url() {
    local title="$1"
    awk -v t="$title" '$0==t { found=1; next } found && /^https?:\/\// { print; exit }' "$YT_LIST"
}

_yt_delete() {
    local title="$1"
    local tmp
    tmp=$(mktemp)
    awk -v t="$title" '
        $0 == t {
            skip = 1
            next
        }
        skip && /^https?:\/\// {
            skip = 0
            next
        }
        skip && /^[0-9]{4}/ {
            skip = 0
            next
        }
        /^----/ && skip {
            skip = 0
            print
            next
        }
        { skip = 0; print }
    ' "$YT_LIST" > "$tmp"
    mv "$tmp" "$YT_LIST"
}

_yt_list() {
    pkill -x rofi 2>/dev/null
    sleep 0.1

    if [[ ! -f "$YT_LIST" ]]; then
        notify-send -e -t 2000 "󰎁  Video" "yt.txt not found"
        return
    fi

    local list
    list=$(_yt_list_entries)

    [[ -z "$list" ]] && notify-send -e -t 2000 "󰎁  yt.txt" "List is empty" && return

    local yt_count
    yt_count=$(printf '%s\n' "$list" | sed '/^$/d' | wc -l)

    local ALL_OPTION="󰒓  ALL ($yt_count)"
    local DOWNLOAD_ALL_OPTION="⬇  Download ALL ($yt_count)"

    local chosen
    chosen=$(printf '%s\n%s\n%s\n' "$ALL_OPTION" "$DOWNLOAD_ALL_OPTION" "$list" | _video_rofi_menu "▶ Video:")
    [[ -z "$chosen" ]] && return

    if [[ "$chosen" == "$ALL_OPTION" ]]; then
        local urls
        urls=$(grep -E '^https?://' "$YT_LIST")
        [[ -z "$urls" ]] && notify-send -e -t 2000 "󰎁  yt.txt" "No URLs found" && return
        echo "$urls" | run_mpv --playlist=- >/dev/null 2>&1 &
        return
    fi

    if [[ "$chosen" == "$DOWNLOAD_ALL_OPTION" ]]; then
        local urls
        urls=$(grep -E '^https?://' "$YT_LIST")
        [[ -z "$urls" ]] && notify-send -e -t 2000 "󰎁  yt.txt" "No URLs found" && return
        mkdir -p "$HOME/media/videos/yt/"
        kitty --title "yt-dl-all" bash -c "echo '$urls' | yt-dlp -f 'bv*[height<=720]+ba/b[height<=720]' -o '$HOME/media/videos/yt/%(title)s.%(ext)s' -i --batch-file -; echo; read -r -p 'Press Enter to close...'"
        return
    fi

    local title
    title=$(echo "$chosen" | sed 's/^[0-9]\{4\}-[0-9-]* - //')

    local action
    action=$(printf "▶ play\n⬇ download\n󰗨 delete" | _video_rofi_menu "$title")
    [[ -z "$action" ]] && return

    if [[ "$action" == "▶ play" ]]; then
        local url
        url=$(_yt_get_url "$title")
        [[ -z "$url" ]] && return
        run_mpv "$url" >/dev/null 2>&1 &
    elif [[ "$action" == *download* ]]; then
        local url
        url=$(_yt_get_url "$title")
        [[ -z "$url" ]] && return
        mkdir -p "$HOME/media/videos/yt/"
        yt-dlp -f "bv*[height<=720]+ba/b[height<=720]" -o "$HOME/media/videos/yt/%(title)s.%(ext)s" "$url"
        notify-send -e -t 2000 "⬇ Download" "$title downloaded"
    elif [[ "$action" == *delete* ]]; then
        _yt_delete "$title"
        notify-send "󰗨 deleted" "$title"
    fi
}

_video_browse() {
    local current_dir="$1"
    local prompt="$2"
    local is_root="$3"

    pkill -x rofi 2>/dev/null
    sleep 0.1

    local all_count
    all_count=$(_video_files_count "$current_dir")

    local ALL_OPTION="󰒓  ALL ($all_count)"

    local last_entry=""
    if [[ "$is_root" == "1" && "$SHOW_LAST_VIDEO" == "TRUE" && -f "$VIDEO_LAST" ]]; then
        local last_path
        last_path=$(cat "$VIDEO_LAST")
        if [[ -f "$last_path" ]]; then
            local last_name
            last_name=$(basename "$last_path" | sed 's/\.[^.]*$//')
            last_entry="󰎁  $last_name"
        fi
    fi

    local subdirs
    subdirs=$(find "$current_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed "s|$current_dir/||" | sort)

    local files
    files=$(find "$current_dir" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \
        -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" \
    \) 2>/dev/null | sed "s|$current_dir/||" | sort)

    local entries="$ALL_OPTION"

    if [[ "$is_root" == "1" && -f "$YT_LIST" ]]; then
        local yt_count
        yt_count=$(_yt_count)
        [[ "$yt_count" -gt 0 ]] && entries+="\n󰉋  txt ($yt_count)"
    fi

    if [[ -n "$subdirs" ]]; then
        while IFS= read -r subdir; do
            local count
            count=$(_video_files_count "$current_dir/$subdir")
            [[ "$count" -gt 0 ]] && entries+="\n󰉋  $subdir ($count)"
        done <<< "$subdirs"
    fi

    [[ -n "$files" ]] && entries+="\n$(echo "$files" | sed 's/\.[^.]*$//' | sed 's/^/󰎁  /')"

    local full_list=""
    if [[ -n "$last_entry" ]]; then
        full_list="$last_entry\n$entries"
    else
        full_list="$entries"
    fi

    local chosen
    chosen=$(echo -e "$full_list" | _video_rofi_custom_menu "󰎁  $prompt:")
    local chosen_status=$?

    if [[ "$chosen_status" -eq 11 ]]; then
        _video_random_no_repeat
    fi

    [[ -z "$chosen" ]] && exit 0

    if [[ -n "$last_entry" && "$chosen" == "$last_entry" ]]; then
        local last_path
        last_path=$(cat "$VIDEO_LAST")
        _video_play_file "$last_path"
        exit 0
    fi

    if [[ "$chosen" == "$ALL_OPTION" ]]; then
        _video_play_all "$current_dir"
    fi

    if [[ "$is_root" == "1" && "$chosen" == 󰉋*"txt"* ]]; then
        _yt_list
        exit 0
    fi

    if [[ "$chosen" == 󰉋* ]]; then
        local folder
        folder=$(echo "$chosen" | sed 's/^󰉋  //' | sed 's/ ([0-9]\+)$//')

        [[ ! -d "$current_dir/$folder" ]] && exit 0

        if [[ "$chosen_status" -eq 10 ]]; then
            _video_play_all "$current_dir/$folder"
        fi

        _video_browse "$current_dir/$folder" "$folder" "0"
        exit 0
    fi

    local display
    display=$(echo "$chosen" | sed 's/^󰎁  //')

    local file
    file=$(echo "$files" | awk -v name="$display" '
        {
            file = $0
            base = file
            sub(/\.[^.]*$/, "", base)
            if (base == name) {
                print file
                exit
            }
        }
    ')

    [[ -z "$file" ]] && exit 0

    _video_play_file "$current_dir/$file"
    exit 0
}

run_video_picker() {
    if [[ ! -d "$VIDEO_DIR" ]]; then
        notify-send -e -t 2000 "󰎁  Video" "Directory not found: $VIDEO_DIR"
        exit 1
    fi

    mkdir -p "$HOME/.cache/scripts/video"
    _video_browse "$VIDEO_DIR" "Video" "1"
}

run_video_picker
