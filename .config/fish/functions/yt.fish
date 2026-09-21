# ─────────── yt ───────────

function yt --description 'download media'
    function __yt_target_dir -a url
        set -l base "$HOME/0/downloads"
        set -l site ""
        set -l host (string match -rg '^https?://(?:www\.)?([^/:]+)' -- "$url")

        if string match -qr 'pinterest\.|pin\.it' -- "$host"
            set site "pinterest"
        else if string match -qr '(^|\.)(twitter\.com|x\.com|t\.co)$' -- "$host"
            set site "twitter"
        else if string match -qr '(^|\.)(instagram\.com)$' -- "$host"
            set site "instagram"
        else if string match -qr '(^|\.)(tiktok\.com)$' -- "$host"
            set site "tiktok"
        else if string match -qr '(^|\.)(reddit\.com|redd\.it)$' -- "$host"
            set site "reddit"
        else if string match -qr '(^|\.)(youtube\.com|youtu\.be)$' -- "$host"
            set site "youtube"
        else if string match -qr '(^|\.)(threads\.net)$' -- "$host"
            set site "threads"
        else if string match -qr '(^|\.)(bsky\.app)$' -- "$host"
            set site "bluesky"
        else if string match -qr '(^|\.)(tumblr\.com)$' -- "$host"
            set site "tumblr"
        else if test -n "$host"
            set -l parts (string split "." "$host")
            if test (count $parts) -ge 2
                set site $parts[-2]
                if test "$site" = "com" -o "$site" = "co" -o "$site" = "net" -o "$site" = "org" -a (count $parts) -ge 3
                    set site $parts[-3]
                end
            else
                set site $parts[1]
            end
        end

        if test -n "$site"
            echo "$base/$site"
        else
            echo "$base"
        end
    end

    function __yt_download_single
        set -l url "$argv[1]"
        set -l extra_args $argv[2..-1]

        set -l out (__yt_target_dir "$url")
        mkdir -p "$out"
        set -l folder_name (basename "$out")

        echo -s (set_color cyan) "󰇚 Downloading to " (set_color blue) "$out/" (set_color normal) " ($url)"

        set -l code 1

        # pinterest
        if string match -qr 'pinterest\.|pin\.it' -- "$url"; and command -v gallery-dl >/dev/null 2>&1
            gallery-dl -q -D "$out" \
                -o "extractor.pinterest.filename={id}{num:?_//}.{extension}" \
                -o "filename={id}{num:?_//}.{extension}" \
                "$url"
            set code $status

            if test $code -eq 0
                # rename single file
                for f in (path filter -f "$out/"*_1.*)
                    set -l base_id (string replace -r '_1\.[^.]+$' '' -- "$f")
                    set -l second (path filter -f "$base_id"_2.*)
                    if test (count $second) -eq 0
                        set -l ext (path extension "$f")
                        mv "$f" "$base_id$ext"
                    end
                end
            else
                # fallback: yt-dlp
                yt-dlp --paths "$out" $extra_args -o "%(id)s.%(ext)s" "$url"
                set code $status
            end
        else
            # default: yt-dlp
            yt-dlp --paths "$out" $extra_args -o "%(id)s.%(ext)s" "$url"
            set code $status

            # fallback: gallery-dl
            if test $code -ne 0; and command -v gallery-dl >/dev/null 2>&1
                echo -s (set_color yellow) "󰇚 Photo detected, downloading via gallery-dl..." (set_color normal)
                gallery-dl -q -D "$out" \
                    -o "extractor.twitter.filename={tweet_id}{num:?_//}.{extension}" \
                    -o "filename={id}{num:?_//}.{extension}" \
                    "$url"
                set code $status

                if test $code -eq 0
                    for f in (path filter -f "$out/"*_1.*)
                        set -l base_id (string replace -r '_1\.[^.]+$' '' -- "$f")
                        set -l second (path filter -f "$base_id"_2.*)
                        if test (count $second) -eq 0
                            set -l ext (path extension "$f")
                            mv "$f" "$base_id$ext"
                        end
                    end
                end
            end
        end

        if test $code -eq 0
            echo -s (set_color green) "󰄬 Completed in $folder_name/" (set_color normal)
            if command -v hyprctl >/dev/null 2>&1
                hyprctl notify 5 3000 "rgb(00ff00)" "󰄬 Download saved to $folder_name/" >/dev/null 2>&1
            end
        else
            echo -s (set_color red) "󰅙 Error downloading $url" (set_color normal)
            if command -v hyprctl >/dev/null 2>&1
                hyprctl notify -1 2500 "rgb(ff0000)" "󰅙 Error: $url" >/dev/null 2>&1
            end
        end
        return $code
    end

    # cli mode
    if test (count $argv) -gt 0
        set -l urls
        set -l extra_args
        for arg in $argv
            if string match -qr '^https?://' -- "$arg"
                set -a urls "$arg"
            else
                set -a extra_args "$arg"
            end
        end
        if test (count $urls) -eq 0
            set urls $argv
            set extra_args
        end

        for u in $urls
            __yt_download_single "$u" $extra_args
        end
        functions -e __yt_download_single
        functions -e __yt_target_dir
        return 0
    end

    # watcher mode
    if not command -v wl-paste >/dev/null 2>&1
        echo -s (set_color red) "Error: wl-paste not found" (set_color normal)
        functions -e __yt_download_single
        functions -e __yt_target_dir
        return 1
    end

    command -v pkill >/dev/null 2>&1
    and command pkill -f "/tmp/yt_watcher_" 2>/dev/null

    set -l state_dir "/tmp/yt_watcher_$fish_pid"
    set -l queue_file "$state_dir/queue"
    set -l seen_file "$state_dir/seen"
    set -l current_clip_file "$state_dir/current"
    rm -rf "$state_dir"
    mkdir -p "$state_dir"
    touch "$queue_file" "$seen_file"

    # ignore initial clip
    wl-paste -n 2>/dev/null | string trim > "$current_clip_file"

    clear
    echo -s (set_color f5c2e7) "󱎫 yt standby..." (set_color normal) (set_color 888888) " (Copy links of videos or photos to download into ~/0/downloads/<site> | Ctrl+C to exit)" (set_color normal)
    echo

    # clipboard watcher
    wl-paste --watch fish -c '
        set -l clip (command cat | string trim)
        set -l queue_file $argv[1]
        set -l seen_file $argv[2]
        set -l current_clip_file $argv[3]

        set -l url (string match -r "https?://[^\s\"\'<>]+" -- "$clip")
        if test -z "$url"
            exit 0
        end

        if test -f "$current_clip_file"
            set -l current_clip (command cat "$current_clip_file")
            if test -n "$current_clip"; and test "$clip" = "$current_clip"
                rm -f "$current_clip_file"
                exit 0
            end
        end

        if grep -Fxq -- "$url" "$seen_file" 2>/dev/null
            exit 0
        end

        echo "$url" >> "$seen_file"
        echo "$url" >> "$queue_file"

        if command -v hyprctl >/dev/null 2>&1
            hyprctl notify -1 2000 "rgb(f5c2e7)" "📥 Link added to queue" >/dev/null 2>&1
        end
    ' "$queue_file" "$seen_file" "$current_clip_file" &
    set -l watch_pid $last_pid

    # cleanup
    trap "kill $watch_pid 2>/dev/null; rm -rf $state_dir 2>/dev/null; functions -e __yt_download_single 2>/dev/null; functions -e __yt_target_dir 2>/dev/null; return 0" INT TERM EXIT

    # queue loop
    while true
        if not kill -0 $watch_pid >/dev/null 2>&1
            break
        end

        if test -s "$queue_file"
            set -l next_url (head -n 1 "$queue_file")
            tail -n +2 "$queue_file" > "$queue_file.tmp"
            mv "$queue_file.tmp" "$queue_file"

            if test -n "$next_url"
                __yt_download_single "$next_url"
                echo
            end
        end

        sleep 0.2
    end

    kill $watch_pid >/dev/null 2>&1
    rm -rf "$state_dir"
    functions -e __yt_download_single
    functions -e __yt_target_dir
    return 0
end
