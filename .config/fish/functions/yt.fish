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

# ─────────── mp3 ───────────
if not set -q YT_MP3_THUMBNAIL
    set -g YT_MP3_THUMBNAIL true
end

function __yt_mp3_thumbnail_flags --description 'thumbnail'
    if not set -q YT_MP3_THUMBNAIL
        set -g YT_MP3_THUMBNAIL true
    end
    if test "$YT_MP3_THUMBNAIL" = true
        echo --embed-thumbnail
        echo --add-metadata
    end
end

function __yt_mp3_cookie_flags --description 'firefoxx cookies'
    if test -d "$HOME/.config/mozilla/firefox"; or test -d "$HOME/.mozilla/firefox"
        echo --cookies-from-browser
        echo firefox
    end
end

# ─── mp3 / mp3l ───
function __mp3_run --no-scope-shadowing
    set -l verbose "$argv[1]"
    set -l out_dir "$HOME/0/music/yt"
    set -l green (set_color green)
    set -l red (set_color red)
    set -l yellow (set_color yellow)
    set -l reset (set_color normal)

    if not command -v yt-dlp >/dev/null 2>&1
        echo -s $red "yt-dlp not found" $reset
        return 1
    end

    mkdir -p "$out_dir"

    function __mp3_notify --no-scope-shadowing
        if command -v hyprctl >/dev/null 2>&1
            hyprctl notify -1 2200 "rgb(cba6f7)" "$argv[1]" >/dev/null 2>&1
        end
    end

    function __mp3_download --no-scope-shadowing
        set -l url $argv[1]
        set -l folder $argv[2]
        set -l out "$out_dir"
        set -l queue "$queue_file"

        # .yt.txt
        set -l vid (string match -rg 'v=([A-Za-z0-9_-]{11})' -- "$url")
        test -z "$vid"; and set vid (string match -rg 'youtu\.be/([A-Za-z0-9_-]{11})' -- "$url")
        test -z "$vid"; and set vid (string match -rg 'shorts/([A-Za-z0-9_-]{11})' -- "$url")
        if test -n "$vid"; and test -f "$out/.yt.txt"; and grep -q -- "$vid" "$out/.yt.txt" 2>/dev/null
            set -l title (grep -B1 -- "$vid" "$out/.yt.txt" 2>/dev/null | head -n 1)
            echo -s $yellow "↻ $title" $reset
            if command -v hyprctl >/dev/null 2>&1
                hyprctl notify 0 3000 "rgb(ff0000)" "↻ $title" >/dev/null 2>&1
            end
            return 0
        end

        command fish -c '
            set -l url $argv[1]
            set -l folder $argv[2]
            set -l out $argv[3]
            set -l queue $argv[4]
            set -l verbose $argv[5]
            set -l green (set_color green)
            set -l red (set_color red)
            set -l yellow (set_color yellow)
            set -l reset (set_color normal)
            set -l title "..."
            set -l count 0

            set -l out_tmpl "$out/%(title)s.%(ext)s"
            if test -n "$folder"
                set out_tmpl "$out/$folder/%(title)s.%(ext)s"
            end

            set -l code 0
            if test "$verbose" = 1
                yt-dlp -x \
                    (__yt_mp3_cookie_flags) \
                    --audio-format mp3 \
                    --audio-quality 0 \
                    -f "ba/b" \
                    --concurrent-fragments 5 \
                    --no-playlist \
                    --no-download-archive \
                    --socket-timeout 15 \
                    --retries 3 \
                    --fragment-retries 3 \
                    --extractor-args "youtube:player_client=mweb,web,ios" \
                    (__yt_mp3_thumbnail_flags) \
                    --replace-in-metadata "uploader" " - Topic\$" "" \
                    --parse-metadata "uploader:%(artist)s" \
                    --parse-metadata "uploader:%(album_artist)s" \
                    --replace-in-metadata "title" "(?i)\\s*[\\(\\[]?(?:feat|ft)\\.?\\s*[\\)\\]]?.*\$" "" \
                    --print "after_move:DONE:%(title)s|%(webpage_url)s|%(id)s" \
                    -o "$out_tmpl" \
                    "$url"
                set code $status
            else
                set -l waiting 0
                if test -f "$queue"
                    set waiting (string match -rv "^\s*\$" < "$queue" | count)
                end
                yt-dlp -x \
                    (__yt_mp3_cookie_flags) \
                    --audio-format mp3 \
                    --audio-quality 0 \
                    -f "ba/b" \
                    --concurrent-fragments 5 \
                    --no-playlist \
                    --no-download-archive \
                    --socket-timeout 15 \
                    --retries 3 \
                    --fragment-retries 3 \
                    --extractor-args "youtube:player_client=mweb,web,ios" \
                    (__yt_mp3_thumbnail_flags) \
                    --replace-in-metadata "uploader" " - Topic\$" "" \
                    --parse-metadata "uploader:%(artist)s" \
                    --parse-metadata "uploader:%(album_artist)s" \
                    --replace-in-metadata "title" "(?i)\\s*[\\(\\[]?(?:feat|ft)\\.?\\s*[\\)\\]]?.*\$" "" \
                    --no-warnings \
                    --newline \
                    --progress \
                    --progress-template "PROG:%(info.title)s|%(progress._percent_str)s" \
                    --print "after_move:DONE:%(title)s|%(webpage_url)s|%(id)s" \
                    -o "$out_tmpl" \
                    "$url" 2>/dev/null | while read -l line
                        if string match -q "DONE:*" -- "$line"
                            set -l payload (string sub -s 6 -- "$line")
                            set -l parts (string split "|" "$payload")
                            set -l done_title $parts[1]
                            set -l done_url $parts[2]
                            set -l done_id $parts[3]

                            set -l waiting 0
                            if test -f "$queue"
                                set waiting (string match -rv "^\s*\$" < "$queue" | count)
                            end

                            printf "\r\033[K"
                            echo -s $green "$done_title" $reset

                            if command -v hyprctl >/dev/null 2>&1
                                if test $waiting -gt 0
                                    hyprctl notify 5 3000 "rgb(00ff00)" "$done_title | $waiting" >/dev/null 2>&1
                                else
                                    hyprctl notify 5 3000 "rgb(00ff00)" "$done_title" >/dev/null 2>&1
                                end
                            end

                            echo "$done_title" >> "$out/.yt.txt"
                            if test -n "$done_url"
                                echo "$done_url" >> "$out/.yt.txt"
                            else if test -n "$done_id"
                                echo "https://www.youtube.com/watch?v=$done_id" >> "$out/.yt.txt"
                            end
                            echo "----------" >> "$out/.yt.txt"
                            set count (math $count + 1)

                        else if string match -q "PROG:*" -- "$line"
                            set -l payload (string sub -s 6 -- "$line")
                            set -l parts (string split "|" "$payload")
                            set -l cur_title $parts[1]
                            set -l percent (string trim -- "$parts[2]")
                            if test -n "$cur_title"
                                set title "$cur_title"
                            end
                            if test -n "$percent"
                                set -l waiting 0
                                if test -f "$queue"
                                    set waiting (string match -rv "^\s*\$" < "$queue" | count)
                                end
                                if test $waiting -gt 0
                                    printf "\r\033[K󱎫 %s %s 󱐋 %s" "$title" "$percent" "$waiting"
                                else
                                    printf "\r\033[K󱎫 %s %s" "$title" "$percent"
                                end
                            end
                        end
                    end
                set code $status
            end

            if test $code -ne 0 -a $count -eq 0
                if test "$verbose" != 1
                    printf "\033[1A\033[J"
                end
                echo -s $red "󰅙" $reset
                if command -v hyprctl >/dev/null 2>&1
                    hyprctl notify -1 2200 "rgb(cba6f7)" "󰅙" >/dev/null 2>&1
                end
                exit 1
            end
        ' "$url" "$folder" "$out" "$queue" "$verbose"
    end

    function __mp3_queue_count --no-scope-shadowing
        set -l active 0
        if test -f "$active_file"
            set active (command cat "$active_file")
        end
        set -l waiting 0
        if test -f "$queue_file"
            set waiting (string match -rv '^\s*$' < "$queue_file" | count)
        end
        math $active + $waiting
    end

    function __mp3_show_queue --no-scope-shadowing
        set -l total (__mp3_queue_count)
        echo -s $yellow "queue: $total" $reset
    end

    if test -n "$argv[2]"
        set -l input_url "$argv[2]"
        if string match -qr "(/playlist\?list=|/playlist\?)" -- "$input_url"; and not string match -qr "([?&]v=|\.be/|shorts/)" -- "$input_url"
            set -l max_workers 1
            set -l state_dir "/tmp/mp3_direct_$fish_pid"
            set -l queue_file "$state_dir/queue"
            set -l active_file "$state_dir/active"
            rm -rf "$state_dir"
            mkdir -p "$state_dir"
            touch "$queue_file"

            echo -s $yellow "󱎫 Lendo faixas da playlist..." $reset
            yt-dlp (__yt_mp3_cookie_flags) --flat-playlist --no-warnings --print "%(url)s	%(playlist_title)s" "$input_url" 2>/dev/null >> "$queue_file"

            set -l total_items (wc -l < "$queue_file" | string trim)
            echo -s $green "󱐋 Baixando $total_items músicas..." $reset

            while test -s "$queue_file" -o (count (jobs -p)) -gt 0
                set -l active_count (count (jobs -p))
                while test $active_count -lt $max_workers -a -s "$queue_file"
                    set -l next_line (head -n 1 "$queue_file")
                    tail -n +2 "$queue_file" > "$queue_file.tmp"
                    mv "$queue_file.tmp" "$queue_file"

                    if test -n "$next_line"
                        set -l parts (string split "\t" "$next_line")
                        set -l next_url $parts[1]
                        set -l next_folder ""
                        if test (count $parts) -ge 2
                            set next_folder $parts[2]
                        end
                        __mp3_download "$next_url" "$next_folder" &
                        set active_count (math $active_count + 1)
                    end
                end
                sleep 0.15
            end
            rm -rf "$state_dir"
            functions -e __mp3_notify
            functions -e __mp3_download
            return 0
        else
            __mp3_download "$input_url" ""
            functions -e __mp3_notify
            functions -e __mp3_download
            return $status
        end
    end

    if not command -v wl-paste >/dev/null 2>&1
        echo -s $red "wl-paste not found" $reset
        return 1
    end

    command -v pkill >/dev/null 2>&1
    and command pkill -f "/tmp/mp3_queue_" 2>/dev/null

    set -l max_workers 1
    set -l state_dir "/tmp/mp3_queue_$fish_pid"
    set -l queue_file "$state_dir/queue"
    set -l seen_file "$state_dir/seen"
    set -l active_file "$state_dir/active"
    set -l current_clip_file "$state_dir/current"
    rm -rf "$state_dir"
    mkdir -p "$state_dir"
    touch "$queue_file" "$seen_file"
    wl-paste -n 2>/dev/null | string trim > "$current_clip_file"

    clear
    echo "󱎫"

    wl-paste --watch fish -c '
        set -l clip (command cat | string trim)
        set -l queue_file $argv[1]
        set -l seen_file $argv[2]
        set -l active_file $argv[3]
        set -l current_clip_file $argv[4]

        if not string match -qr "^https?://(www\.|music\.)?(youtube\.com|youtu\.be)/" -- "$clip"
            exit 0
        end

        if test -f "$current_clip_file"
            set -l current_clip (command cat "$current_clip_file")
            if test -n "$current_clip"; and test "$clip" = "$current_clip"
                rm -f "$current_clip_file"
                exit 0
            end
        end

        if grep -Fxq -- "$clip" "$seen_file" 2>/dev/null
            exit 0
        end

        echo "$clip" >> "$seen_file"

        # Expand playlist into queue ONLY if pure playlist URL (no video ID)
        if string match -qr "(/playlist\?list=|/playlist\?)" -- "$clip"; and not string match -qr "([?&]v=|\.be/|shorts/)" -- "$clip"
            set -l items_found 0
            yt-dlp (__yt_mp3_cookie_flags) --flat-playlist --no-warnings --print "%(url)s\t%(playlist_title)s" "$clip" 2>/dev/null | while read -l pl_item
                if test -n "$pl_item"
                    echo "$pl_item" >> "$queue_file"
                    set items_found (math $items_found + 1)
                end
            end
            if test $items_found -eq 0
                echo "$clip" >> "$queue_file"
            end
        else
            echo "$clip" >> "$queue_file"
        end

        set -l waiting (wc -l < "$queue_file" | string trim)
        set -l total $waiting

        if command -v hyprctl >/dev/null 2>&1
            hyprctl notify -1 2200 "rgb(cba6f7)" "󱐋 $total" >/dev/null 2>&1
        end
    ' "$queue_file" "$seen_file" "$active_file" "$current_clip_file" &
    set -l watch_pid $last_pid

    while true
        if not kill -0 $watch_pid >/dev/null 2>&1
            functions -e __mp3_notify
            functions -e __mp3_download
            functions -e __mp3_queue_count
            functions -e __mp3_show_queue
            return 0
        end

        set -l active_pids (jobs -p)
        set -l download_pids
        for p in $active_pids
            if test "$p" != "$watch_pid"
                set -a download_pids $p
            end
        end
        set -l active_count (count $download_pids)
        echo $active_count > "$active_file"

        while test $active_count -lt $max_workers -a -s "$queue_file"
            set -l next_line (head -n 1 "$queue_file")
            tail -n +2 "$queue_file" > "$queue_file.tmp"
            mv "$queue_file.tmp" "$queue_file"

            if test -n "$next_line"
                set -l parts (string split "\t" "$next_line")
                set -l next_url $parts[1]
                set -l next_folder ""
                if test (count $parts) -ge 2
                    set next_folder $parts[2]
                end
                __mp3_download "$next_url" "$next_folder" &
                set active_count (math $active_count + 1)
            end
        end

        sleep 0.15
    end
end

# ─── mp3
function mp3
    __mp3_run 0 $argv
end

# ─── mp3l
function mp3l
    __mp3_run 1 $argv
end
