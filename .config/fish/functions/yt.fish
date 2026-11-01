# ─────────── yt ───────────
# yt
# mp3
# mp3l
# ytp

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
                set code $pipestatus[1]
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
    wl-paste -n 2>/dev/null > "$current_clip_file"

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

function __yt_mp3_playlist_entries -a url
    command yt-dlp (__yt_mp3_cookie_flags) --flat-playlist --lazy-playlist --no-warnings \
        --print (string join \t -- "%(availability)s" "%(title)s" "%(url)s" "%(playlist_title)s") -- "$url" | while read -l entry
        set -l fields (string split -m 3 \t -- "$entry")
        if test (count $fields) -lt 4
            continue
        end
        if string match -qri '^(private|deleted|unavailable)$' -- "$fields[1]"
            continue
        end
        if string match -qri '^\[?(deleted video|private video|unavailable video|video unavailable)\]?$' -- "$fields[2]"
            continue
        end
        printf '%s\t%s\n' "$fields[3]" "$fields[4]"
    end
    return $pipestatus[1]
end

function __yt_mp3_fetch_metadata -a url target
    set -l temporary "$target.tmp.$fish_pid"
    command yt-dlp (__yt_mp3_cookie_flags) --simulate --dump-single-json --no-playlist \
        --no-warnings --socket-timeout 15 --retries 1 -f "ba/b" \
        --extractor-args "youtube:player_client=mweb,web,ios" \
        "$url" > "$temporary" 2> "$target.log"
    set -l code $status
    if test $code -eq 0; and test -s "$temporary"
        command mv "$temporary" "$target"
        command rm -f "$target.log"
    else
        command touch "$target.failed"
    end
    command rm -f "$temporary" "$target.pending"
end

function __yt_mp3_ffmpeg_script
    printf %s 'log_dir=$1
shift
progress_dir=$(mktemp -d "$log_dir/progress.XXXXXXXX") || exit 1
progress="$progress_dir/ffmpeg"
stop="$progress_dir/stop"
watch_progress() {
    local current previous=\'\'
    while :; do
        if [ -s "$progress" ]; then
            current=$(awk -F= \'
                $1 == "out_time_us" { time=$2 }
                $1 == "speed" { speed=$2 }
                $1 == "progress" { print time "|" speed "|" $2 }
            \' "$progress" | tail -n 1)
            if [[ "$current" != "$previous" && "$current" =~ ^[0-9]+\\| ]]; then
                printf \'CONVERT:%s\\n\' "$current"
                previous=$current
            fi
        fi
        [ -e "$stop" ] && break
        sleep 0.25
    done
}
watch_progress &
watch_pid=$!
cleanup() {
    kill "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" 2>/dev/null || true
    rm -f "$progress" "$stop"
    rmdir "$progress_dir"
}
trap cleanup EXIT
trap \'exit 130\' INT
trap \'exit 143\' TERM
printf -v progress_arg \'%q\' "$progress"
yt-dlp --postprocessor-args "ExtractAudio+ffmpeg_o:-progress $progress_arg -stats_period 0.25 -nostats" "$@"
code=$?
touch "$stop"
wait "$watch_pid"
exit "$code"
'
end

function __yt_mp3_prepare_status --no-scope-shadowing -a line title url
    set -l target "$title"
    if test -z "$target"; or test "$target" = '...'
        set target "$url"
    end
    set -l step ''
    if string match -q 'Extracting cookies*' -- "$line"
        set step 'Reading browser cookies'
    else if string match -qr '^Extracted [0-9]+ cookies' -- "$line"
        set step 'Browser cookies loaded'
    else if string match -qr '^\[youtube[^]]*\]' -- "$line"
        if string match -q '*Extracting URL:*' -- "$line"
            set step 'Reading video information'
        else
            set step (string replace -r '^(\[[^]]+\]\s*)+([A-Za-z0-9_-]{11}:\s*)?' '' -- "$line")
        end
    else if string match -q '*Solving JS challenges*' -- "$line"
        set step 'Solving YouTube challenge'
    else if string match -qr '^\[SponsorBlock\]' -- "$line"
        set step 'Checking SponsorBlock'
    else if string match -qr '^\[MetadataParser\]' -- "$line"
        set step 'Reading track metadata'
    else if string match -qr '^\[info\].*(Downloading video thumbnail|Writing video thumbnail)' -- "$line"
        __mp3_status "◈ Downloading cover · $target" magenta
        return
    else if string match -qr '^\[info\].*Downloading [0-9]+ format' -- "$line"
        set step 'Selecting audio format'
    else if string match -qr '^\[download\] Sleeping' -- "$line"
        set step 'Waiting for YouTube'
    else if string match -qr '^\[download\] Destination:' -- "$line"
        __mp3_status "↓ Starting download · $target" cyan
        return
    else
        return
    end
    __mp3_status "◌ $step · $target" yellow
end

function __yt_mp3_conversion_status --no-scope-shadowing -a line duration title
    set -l parts (string split '|' -- (string sub -s 9 -- "$line"))
    if test (count $parts) -ne 3; or not string match -qr '^[0-9]+$' -- "$parts[1]"
        return
    end
    set -l seconds (math "$parts[1] / 1000000")
    set -l speed (string trim -- "$parts[2]")
    set -l detail (printf '%.0fs processed' "$seconds")
    if test "$speed" != N/A; and test -n "$speed"
        set detail "$detail · $speed"
    end
    if test "$duration" -gt 0
        set -l percent (math "min(99, max(0, floor($seconds / $duration * 100)))")
        if test "$parts[3]" = end
            set percent 100
        end
        set -l filled (math "floor($percent / 10)")
        set -l bar (string join '' -- (string repeat -n $filled '━') (string repeat -n (math "10 - $filled") '─'))
        set -l eta '--'
        set -l rate (string replace -r 'x$' '' -- "$speed")
        if string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$rate"; and test "$rate" -gt 0
            set eta (math "ceil(max(0, $duration - $seconds) / $rate)")s
        end
        __mp3_status "♫ $percent% · $title · $bar · $speed · ETA $eta" magenta
        return
    end
    __mp3_status "♫ $detail · $title" magenta
end

# ─── mp3 / mp3l ───
function __mp3_run --no-scope-shadowing
    set -l verbose "$argv[1]"
    set -l metadata_pids
    set -l metadata_urls
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
        set folder (string replace -ri '^album\s*-\s*' '' -- "$folder")
        set -l out "$out_dir"
        set -l queue "$queue_file"

        # .yt.txt
        set -l vid (string match -rg 'v=([A-Za-z0-9_-]{11})' -- "$url")
        test -z "$vid"; and set vid (string match -rg 'youtu\.be/([A-Za-z0-9_-]{11})' -- "$url")
        test -z "$vid"; and set vid (string match -rg 'shorts/([A-Za-z0-9_-]{11})' -- "$url")
        if test -n "$vid"; and test -f "$out/.yt.txt"; and grep -q -- "$vid" "$out/.yt.txt" 2>/dev/null
            set -l title (grep -B1 -- "$vid" "$out/.yt.txt" 2>/dev/null | head -n 1)
            if test -f "$queue.live"
                set -l skipped_file (command mktemp "$queue.status.XXXXXX.done")
                printf "%s↻ %s%s" $yellow "$title" $reset > "$skipped_file"
            else
                echo -s $yellow "↻ $title" $reset
            end
            if command -v hyprctl >/dev/null 2>&1
                hyprctl notify 0 3000 "rgb(ff0000)" "↻ $title" >/dev/null 2>&1
            end
            return 0
        end

        set -l lock_dir "$HOME/.local/state/mp3/locks"
        command mkdir -p "$lock_dir"
        set -l lock_key "$vid"
        if test -z "$lock_key"
            set lock_key (printf "%s" "$url" | command sha256sum | string split " ")[1]
        end
        set -l metadata_file ""
        if test -n "$queue"
            set -l metadata_key (printf "%s" "$url" | command sha256sum | string split " ")[1]
            set metadata_file "$queue.metadata/$metadata_key.json"
        end
        command flock "$lock_dir/$lock_key.lock" fish --no-config -c '
            eval "$argv[6]"
            set -l url $argv[1]
            set -l folder $argv[2]
            set -l out $argv[3]
            set -l queue $argv[4]
            set -l verbose $argv[5]
            set -l metadata_file $argv[7]
            set -l green (set_color green)
            set -l red (set_color red)
            set -l yellow (set_color yellow)
            set -l reset (set_color normal)
            set -l title "..."
            set -l count 0
            set -l failure ""
            set -l duration 0
            set -l phase preparing
            set -l log_dir "$HOME/.local/state/mp3/logs"
            command mkdir -p "$log_dir"
            set -l log_file (command mktemp "$log_dir/download.XXXXXXXX.log")
            printf "%s\n" "$url" > "$log_file"

            set -l out_tmpl "$out/%(title)s.%(ext)s"
            if test -n "$folder"
                set out_tmpl "$out/$folder/%(title)s.%(ext)s"
            end

            set -l status_width 79
            set -l terminal_columns (command tput cols 2>/dev/null)
            if string match -qr "^[0-9]+\$" -- "$terminal_columns"
                set status_width (math "max(1, $terminal_columns - 1)")
            end
            function __mp3_status --no-scope-shadowing
                set -l text (string replace -ar "[\r\n\t]" " " -- "$argv[1]")
                set -l color cyan
                if test (count $argv) -ge 2
                    set color "$argv[2]"
                end
                if test -f "$queue.live"
                    printf "%s%s%s" (set_color $color) "$text" (set_color normal) > "$queue.status.$fish_pid.tmp"
                    command mv "$queue.status.$fish_pid.tmp" "$queue.status.$fish_pid"
                else if test "$verbose" = 1; or not isatty stdout
                    printf "%s\n" "$text"
                else
                    printf "\r\033[K%s%s%s" (set_color $color) (string shorten -m $status_width -- "$text") (set_color normal)
                end
            end
            __mp3_status "◌ Preparing · $url" yellow
            set -l code 0
            set -l download_input "$url"
            set -l using_metadata false
            if test -n "$metadata_file"; and test -s "$metadata_file"
                set -l modified (command stat -c %Y "$metadata_file" 2>/dev/null)
                set -l current_time (command date +%s)
                if test -n "$modified"; and test (math "$current_time - $modified") -lt 300
                    set download_input --load-info-json "$metadata_file"
                    set using_metadata true
                end
            end
            for input_attempt in 1 2
                set duration 0
                set phase preparing
                command bash -c (__yt_mp3_ffmpeg_script | string collect) -- "$log_dir" -x \
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
                    --replace-in-metadata "title" "(?i)\\s*[\\(\\[]?\\b(?:feat|ft)\\b\\.?\\s*[\\)\\]]?.*\$" "" \
                    --no-quiet \
                    --newline \
                    --progress \
                    --progress-template "PROG:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(info.title)s" \
                    --no-simulate \
                    --print "before_dl:TITLE:%(title)s" \
                    --print "before_dl:DURATION:%(duration)s" \
                    --print "after_move:DONE:%(title)s|%(webpage_url)s|%(id)s" \
                    -o "$out_tmpl" \
                    $download_input 2>&1 | while read -l line
                        printf "%s\n" "$line" >> "$log_file"
                        if test -f "$queue.shared"
                            printf "%s\n" "$line" >> "$queue.log"
                        end
                        if test "$verbose" = 1
                            printf "%s\n" "$line"
                        end
                        if string match -q "DONE:*" -- "$line"
                            set -l payload (string sub -s 6 -- "$line")
                            set -l parts (string split "|" "$payload")
                            set -l done_title (string join "|" -- $parts[1..-3])
                            set title "$done_title"
                            set -l done_url $parts[-2]
                            set -l done_id $parts[-1]
    
                            set -l waiting 0
                            if test -f "$queue"
                                set waiting (string match -rv "^\s*\$" < "$queue" | count)
                    if test -f "$queue.consumed"
                        set waiting (math "max(0, $waiting - "(command cat "$queue.consumed")")")
                    end
                            end
    
                            __mp3_status "✓ $done_title" green
                            if not test -f "$queue.live"
                                printf "\n"
                            end
    
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
                            set -l percent (string trim -- "$parts[1]")
                            set -l speed (string trim -- "$parts[2]")
                            set -l eta (string trim -- "$parts[3]")
                            set title (string join "|" -- $parts[4..-1])
                            set -l numeric (string replace -a "%" "" -- "$percent")
                            set -l bar "····················"
                            if string match -qr "^[0-9]+(\.[0-9]+)?\$" -- "$numeric"
                                set -l filled (math "min(20, max(0, floor($numeric / 5)))")
                                set -l empty (math "20 - $filled")
                                set bar (string repeat -n $filled "━") (string repeat -n $empty "─")
                                set bar (string join "" -- $bar)
                            end
                            set -l waiting 0
                            if test -f "$queue"
                                set waiting (string match -rv "^\s*\$" < "$queue" | count)
                    if test -f "$queue.consumed"
                        set waiting (math "max(0, $waiting - "(command cat "$queue.consumed")")")
                    end
                            end
                            __mp3_status "↓ $percent · $title · $bar · $speed · ETA $eta · $waiting queued" cyan
                        else if string match -q "TITLE:*" -- "$line"
                            set title (string sub -s 7 -- "$line")
                        else if string match -q "DURATION:*" -- "$line"
                            set -l value (string sub -s 10 -- "$line")
                            if string match -qr "^[0-9]+(\\.[0-9]+)?\\$" -- "$value"
                                set duration "$value"
                            end
                        else if string match -q "CONVERT:*" -- "$line"
                            if test "$phase" = converting
                                __yt_mp3_conversion_status "$line" "$duration" "$title"
                            end
                        else if string match -q "ERROR:*" -- "$line"
                            set failure (string replace "ERROR: " "" -- "$line")
                        else if string match -qr "^\\[ExtractAudio\\]" -- "$line"
                            set phase converting
                            __mp3_status "♫ $title" magenta
                        else if string match -qr "^\\[(EmbedThumbnail|ThumbnailsConvertor)\\]" -- "$line"
                            set phase cover
                            __mp3_status "◈ Adding cover · $title" magenta
                        else if string match -qr "^\\[Metadata\\]" -- "$line"
                            set phase metadata
                            __mp3_status "◇ Adding metadata · $title" magenta
                        else
                            __yt_mp3_prepare_status "$line" "$title" "$url"
                        end
                    end
                set code $pipestatus[1]
                if test $code -eq 0; or test $count -gt 0; or test "$using_metadata" != true
                    break
                end
                set download_input "$url"
                set using_metadata false
                command rm -f "$metadata_file"
                __mp3_status "↻ Refreshing track information · $url" yellow
            end

            if test $code -ne 0 -a $count -eq 0
                if test "$verbose" != 1; and isatty stdout; and not test -f "$queue.live"
                    printf "\r\033[K"
                end
                if test -z "$failure"
                    set failure "exit code $code"
                end
                set failure (string replace -r "^\[[^]]+\] [A-Za-z0-9_-]{11}: " "" -- "$failure")
                if string match -qi "*private video*" -- "$failure"
                    set failure "Private video"
                else if string match -qi "*video has been removed*" -- "$failure"
                    set failure "Video removed"
                else if string match -qi "*video unavailable*" -- "$failure"
                    set failure "Video unavailable"
                end
                __mp3_status "✗ $failure · $url" red
                if command -v hyprctl >/dev/null 2>&1
                    hyprctl notify -1 2200 "rgb(cba6f7)" "󰅙" >/dev/null 2>&1
                end
                if test -f "$queue.live"
                    command mv "$queue.status.$fish_pid" "$queue.status.$fish_pid.done"
                end
                exit 1
            end
            if test $code -ne 0; and test $count -gt 0
                __mp3_status "⚠ Saved with errors · $title · see $log_file" yellow
            else
                command rm -f "$log_file"
            end
            if test -f "$queue.live"; and test -f "$queue.status.$fish_pid"
                command mv "$queue.status.$fish_pid" "$queue.status.$fish_pid.done"
            end
        ' "$url" "$folder" "$out" "$queue" "$verbose" (functions __yt_mp3_cookie_flags __yt_mp3_thumbnail_flags __yt_mp3_ffmpeg_script __yt_mp3_conversion_status __yt_mp3_prepare_status | string collect) "$metadata_file"
    end

    function __mp3_prepare_workers --no-scope-shadowing
        command mkdir -p "$queue_file.metadata"
        begin
            printf "%s\n" "set -g out_dir \$argv[1]" "set -g queue_file \$argv[2]" "set -g verbose \$argv[3]" "set -g yellow (set_color yellow)" "set -g reset (set_color normal)"
            functions __mp3_download __yt_mp3_cookie_flags __yt_mp3_thumbnail_flags __yt_mp3_ffmpeg_script __yt_mp3_conversion_status __yt_mp3_prepare_status
            printf "%s\n" "__mp3_download \"\$argv[4]\" \"\$argv[5]\""
        end > "$state_dir/worker.fish"
        begin
            functions __yt_mp3_fetch_metadata __yt_mp3_cookie_flags
            printf '%s\n' '__yt_mp3_fetch_metadata "$argv[1]" "$argv[2]"'
        end > "$state_dir/metadata.fish"
        begin
            functions __yt_mp3_cookie_flags __yt_mp3_playlist_entries
            printf '%s\n' '__yt_mp3_playlist_entries "$argv[1]" > "$argv[2]" 2> "$argv[3]"' 'set -l code $status' 'echo $code > "$argv[4]"'
        end > "$state_dir/playlist.fish"
    end

    function __mp3_prefetch --no-scope-shadowing
        if test $max_workers -le 1
            return
        end
        set -l active_pids (jobs -p)
        set -l remaining_pids
        for pid in $metadata_pids
            if contains -- "$pid" $active_pids
                set -a remaining_pids "$pid"
            end
        end
        set metadata_pids $remaining_pids
        for next_line in $argv
            if test (count $metadata_pids) -ge 3
                break
            end
            set -l next_url (string split -m 1 \t -- "$next_line")[1]
            if test -z "$next_url"; or contains -- "$next_url" $metadata_urls
                continue
            end
            set -l key (printf "%s" "$next_url" | command sha256sum | string split " ")[1]
            set -l target "$queue_file.metadata/$key.json"
            if test -f "$target"; or test -f "$target.pending"; or test -f "$target.failed"
                continue
            end
            set -a metadata_urls "$next_url"
            command touch "$target.pending"
            command fish --no-config "$state_dir/metadata.fish" "$next_url" "$target" &
            set -a metadata_pids $last_pid
        end
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
            set -l max_workers 3
            if test "$verbose" = 1
                set max_workers 1
            end
            set -l state_dir "/tmp/mp3_direct_$fish_pid"
            set -l queue_file "$state_dir/queue"
            set -l playlist_file "$state_dir/playlist"
            set -l playlist_status "$state_dir/playlist.status"
            set -l active_file "$state_dir/active"
            rm -rf "$state_dir"
            mkdir -p "$state_dir"
            touch "$queue_file" "$playlist_file"

            __mp3_prepare_workers

            echo -s $yellow "󱎫 Reading playlist; downloads will start as tracks are found..." $reset
            command fish --no-config "$state_dir/playlist.fish" "$input_url" "$playlist_file" "$state_dir/playlist.log" "$playlist_status" &

            set -l download_pids
            set -l painted_lines 0
            set -l source_position 1
            if test "$verbose" != 1; and isatty stdout
                touch "$queue_file.live"
            end
            while true
                set -l source_lines (wc -l < "$playlist_file" | string trim)
                set -l queued_lines (string match -rv '^\s*$' < "$queue_file" | count)
                while test $queued_lines -lt 6 -a $source_position -le $source_lines
                    set -l next_line (sed -n (string join "" -- "$source_position" p) "$playlist_file")
                    set source_position (math $source_position + 1)
                    if test -n "$next_line"
                        echo "$next_line" >> "$queue_file"
                        set queued_lines (math $queued_lines + 1)
                    end
                end
                set -l active_pids (jobs -p)
                set -l remaining_pids
                for pid in $download_pids
                    if contains -- "$pid" $active_pids
                        set -a remaining_pids "$pid"
                    end
                end
                set download_pids $remaining_pids
                set -l active_count (count $download_pids)
                while test $active_count -lt $max_workers -a -s "$queue_file"
                    set -l next_line (head -n 1 "$queue_file")
                    tail -n +2 "$queue_file" > "$queue_file.tmp"
                    mv "$queue_file.tmp" "$queue_file"

                    if test -n "$next_line"
                        set -l parts (string split -m 1 \t -- "$next_line")
                        set -l next_url $parts[1]
                        set -l next_folder ""
                        if test (count $parts) -ge 2
                            set next_folder $parts[2]
                        end
                        command fish --no-config "$state_dir/worker.fish" "$out_dir" "$queue_file" "$verbose" "$next_url" "$next_folder" &
                        set -a download_pids $last_pid
                        set active_count (math $active_count + 1)
                    end
                end

                if test $active_count -eq $max_workers
                    __mp3_prefetch (command head -n 3 "$queue_file")
                end

                if test -f "$queue_file.live"
                    if test $painted_lines -gt 0
                        printf "\033[%sA" $painted_lines
                    end
                    printf "\r\033[J"
                    for completed in "$queue_file".status.*.done
                        command cat "$completed"
                        printf "\n"
                        command rm -f "$completed"
                    end
                    set painted_lines 0
                    for live in "$queue_file".status.*
                        if string match -qr "\.(tmp|done)\$" -- "$live"
                            continue
                        end
                        if test -f "$live"
                            command cat "$live"
                            printf "\n"
                            set painted_lines (math $painted_lines + 1)
                        end
                    end
                    set -l waiting (string match -rv '^\s*$' < "$queue_file" | count)
                    set -l pending (math "max(0, $source_lines - $source_position + 1)")
                    set -l total_waiting (math "$waiting + $pending")
                    if test $total_waiting -gt 0
                        printf '%s≡ %s%s\n' (set_color f9e2af) "$total_waiting" (set_color normal)
                        set painted_lines (math $painted_lines + 1)
                    end
                end

                if test -f "$playlist_status"; and not test -s "$queue_file"; and test $active_count -eq 0
                    break
                end
                sleep 0.15
            end
            set -l playlist_code (command cat "$playlist_status" 2>/dev/null)
            if test -n "$playlist_code" -a "$playlist_code" -ne 0
                echo -s $red "Playlist reading failed; see $state_dir/playlist.log" $reset
            else
                set -l total_items (math $source_position - 1)
                echo -s $green "󱐋 Processed $total_items playlist tracks." $reset
            end
            for pid in $metadata_pids
                wait $pid
            end
            rm -rf "$state_dir"
            functions -e __mp3_prepare_workers __mp3_prefetch
            functions -e __mp3_notify
            functions -e __mp3_download
            return 0
        else
            __mp3_download "$input_url" ""
            set -l download_status $status
            functions -e __mp3_notify
            functions -e __mp3_download
            return $download_status
        end
    end

    if not command -v wl-paste >/dev/null 2>&1
        echo -s $red "wl-paste not found" $reset
        return 1
    end

    set -l max_workers 3
    if test "$verbose" = 1
        set max_workers 1
    end
    set -l state_dir "/tmp/mp3_queue_$fish_pid"
    if set -q __mp3_shared_session
        set state_dir "$__mp3_shared_session"
    end
    set -l queue_file "$state_dir/queue"
    set -l seen_file "$state_dir/seen"
    set -l active_file "$state_dir/active"
    set -l current_clip_file "$state_dir/current"
    rm -rf "$state_dir"
    mkdir -p "$state_dir"
    touch "$queue_file" "$seen_file"
    if set -q __mp3_shared_session
        touch "$queue_file.live" "$queue_file.shared" "$queue_file.log" "$state_dir/history"
    end
    wl-paste -n 2>/dev/null > "$current_clip_file"

    if isatty stdout
        clear
        printf "%s♫ MP3%s\n" (set_color --bold magenta) $reset
        printf "Copy YouTube links to add tracks · Ctrl+C to stop\n"
        printf "Error logs: ~/.local/state/mp3/logs/\n\n"
    end

    __mp3_prepare_workers

    set -l watch_script '
        eval "$argv[5]"
        set -l clip (command cat | string collect)
        set -l queue_file $argv[1]
        set -l seen_file $argv[2]
        set -l active_file $argv[3]
        set -l current_clip_file $argv[4]

        if test -f "$current_clip_file"
            set -l current_clip (command cat "$current_clip_file" | string collect)
            rm -f "$current_clip_file"
            if test "$clip" = "$current_clip"
                exit 0
            end
        end

        set -l links (string match -ra "https?://(?:www\.|music\.)?(?:youtube\.com|youtu\.be)/[^\s<>\"]+" -- "$clip")
        set -l added 0
        for link in $links
            if command grep -Fxq -- "$link" "$seen_file" 2>/dev/null
                continue
            end
            echo "$link" >> "$seen_file"
            set added (math $added + 1)

            if string match -qr "(/playlist\?list=|/playlist\?)" -- "$link"; and not string match -qr "([?&]v=|\.be/|shorts/)" -- "$link"
                set -l items_found 0
                __yt_mp3_playlist_entries "$link" 2>/dev/null | while read -l pl_item
                    if test -n "$pl_item"
                        echo "$pl_item" >> "$queue_file"
                        set items_found (math $items_found + 1)
                    end
                end
                set -l playlist_code $pipestatus[1]
                if test $items_found -eq 0; and test $playlist_code -ne 0
                    echo "$link" >> "$queue_file"
                end
            else
                echo "$link" >> "$queue_file"
            end
        end

        if test $added -eq 0
            exit 0
        end

        set -l waiting (wc -l < "$queue_file" | string trim)
        if test -f "$queue_file.consumed"
            set waiting (math "max(0, $waiting - "(command cat "$queue_file.consumed")")")
        end
        set -l total $waiting

        if command -v hyprctl >/dev/null 2>&1
            hyprctl notify -1 2200 "rgb(cba6f7)" "󱐋 $total" >/dev/null 2>&1
        end
    '
    set -l watch_helpers (functions __yt_mp3_cookie_flags __yt_mp3_playlist_entries | string collect)
    command wl-paste --type text --watch fish --no-config -c "$watch_script" "$queue_file" "$seen_file" "$active_file" "$current_clip_file" "$watch_helpers" &
    set -l watch_pid $last_pid
    set -g __mp3_session_pids $watch_pid
    set -e __mp3_cancelled
    function __mp3_stop_tree
        for child in (command pgrep -P $argv[1] 2>/dev/null)
            __mp3_stop_tree $child
        end
        command kill -TERM $argv[1] 2>/dev/null
    end
    function __mp3_cancel --on-event fish_cancel
        set -g __mp3_cancelled true
        for pid in $__mp3_session_pids
            __mp3_stop_tree $pid
        end
    end
    set -l queue_position 1
    echo 0 > "$queue_file.consumed"
    set -l painted_lines 0
    if test "$verbose" != 1; and isatty stdout
        touch "$queue_file.live"
        printf "\r\033[K"
    end

    while not set -q __mp3_cancelled
        if not kill -0 $watch_pid >/dev/null 2>&1
            if test "$verbose" = 1
                echo -s $yellow "Clipboard monitor stopped; restarting." $reset
            end
            sleep 1
            if set -q __mp3_cancelled
                break
            end
            command wl-paste --type text --watch fish --no-config -c "$watch_script" "$queue_file" "$seen_file" "$active_file" "$current_clip_file" "$watch_helpers" &
            set watch_pid $last_pid
        end

        set -l active_pids (jobs -p)
        set -l download_pids
        for p in $active_pids
            if test "$p" != "$watch_pid"; and not contains -- "$p" $metadata_pids
                set -a download_pids $p
            end
        end
        set -g __mp3_session_pids $watch_pid $download_pids $metadata_pids
        set -l active_count (count $download_pids)
        echo $active_count > "$active_file"

        while test $active_count -lt $max_workers
            set -l next_line (sed -n "$queue_position"p "$queue_file")
            if test -z "$next_line"
                break
            end
            echo $queue_position > "$queue_file.consumed"
            set queue_position (math $queue_position + 1)

            if test -n "$next_line"
                set -l parts (string split -m 1 \t -- "$next_line")
                set -l next_url $parts[1]
                set -l next_folder ""
                if test (count $parts) -ge 2
                    set next_folder $parts[2]
                end
                command fish --no-config "$state_dir/worker.fish" "$out_dir" "$queue_file" "$verbose" "$next_url" "$next_folder" &
                set -ga __mp3_session_pids $last_pid
                set active_count (math $active_count + 1)
            end
        end

        if test $active_count -eq $max_workers
            set -l metadata_end (math "$queue_position + 2")
            __mp3_prefetch (command sed -n "$queue_position,$metadata_end"p "$queue_file")
            set -g __mp3_session_pids $watch_pid $download_pids $metadata_pids
        end

        if set -q __mp3_shared_session
            for completed in "$queue_file".status.*.done
                command cat "$completed" >> "$state_dir/history"
                printf "\n" >> "$state_dir/history"
                command rm -f "$completed"
            end
            set -l waiting (math "max(0, "(count (string match -rv "^\s*\$" < "$queue_file"))" - $queue_position + 1)")
            begin
                command tail -n 10 "$state_dir/history"
                for live in "$queue_file".status.*
                    if string match -qr "\.(tmp|done)\$" -- "$live"
                        continue
                    end
                    if test -f "$live"
                        command cat "$live"
                        printf "\n"
                    end
                end
            end > "$state_dir/screen.tmp"
            command mv "$state_dir/screen.tmp" "$state_dir/screen"
        else if test "$verbose" != 1; and isatty stdout
            if test $painted_lines -gt 0
                printf "\033[%sA" $painted_lines
            end
            printf "\r\033[J"
            for completed in "$queue_file".status.*.done
                command cat "$completed"
                printf "\n"
                command rm -f "$completed"
            end
            set painted_lines 0
            for live in "$queue_file".status.*
                if string match -q "*.tmp" -- "$live"; or string match -q "*.done" -- "$live"
                    continue
                end
                if test -f "$live"
                    set -l live_text (command cat "$live" 2>/dev/null | string collect)
                    if test -n "$live_text"
                        printf "%s\n" "$live_text"
                        set painted_lines (math $painted_lines + 1)
                    end
                end
            end
        end

        if not isatty stdout; and test $active_count -eq 0
            sleep 1
        else
            sleep 0.15
        end
    end
    command rm -rf "$state_dir"
    functions -e __mp3_cancel __mp3_stop_tree __mp3_download __mp3_notify __mp3_queue_count __mp3_show_queue __mp3_prepare_workers __mp3_prefetch
    set -e __mp3_session_pids __mp3_cancelled
    printf "\n"
end

# ─── mp3
function __mp3_restart_shared
    for dependency in flock bash fish fuser pgrep nohup yt-dlp wl-paste
        if not command -q $dependency
            printf 'Missing dependency: %s\n' "$dependency" >&2
            return 1
        end
    end
    set -l session_dir "$HOME/.local/state/mp3/session"
    command mkdir -p (path dirname "$session_dir"); or return $status
    set -l runtime_dir /tmp
    if set -q XDG_RUNTIME_DIR
        set runtime_dir "$XDG_RUNTIME_DIR"
    end
    command flock --close "$session_dir.restart.lock" bash -c 'session_dir=$1
source_file=$2
runtime_dir=$3
pids=()
declare -A stopped=()
stop_tree() {
    local pid=$1 child
    [[ "$pid" =~ ^[0-9]+$ && "$pid" != "$$" ]] || return 0
    [[ -z "${stopped[$pid]+present}" ]] || return 0
    kill -STOP "$pid" 2>/dev/null || return 0
    stopped[$pid]=1
    while read -r child; do
        stop_tree "$child"
    done < <(pgrep -P "$pid")
    pids+=("$pid")
}
for lock in "$session_dir.lock" "$runtime_dir/mp3.lock"; do
    [ -f "$lock" ] || continue
    if flock -n "$lock" true; then
        continue
    fi
    for pid in $(fuser "$lock" 2>/dev/null); do
        stop_tree "$pid"
    done
done
for pid in "${pids[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
for pid in "${pids[@]}"; do kill -CONT "$pid" 2>/dev/null || true; done
for lock in "$session_dir.lock" "$runtime_dir/mp3.lock"; do
    [ -f "$lock" ] || continue
    if ! flock -w 3 "$lock" true; then
        for pid in "${pids[@]}"; do kill -KILL "$pid" 2>/dev/null || true; done
        flock -w 2 "$lock" true || { echo \'Could not stop the previous MP3 session.\' >&2; exit 1; }
    fi
done
rm -rf -- "$session_dir" || exit 1
fish --no-config -c \'source "$argv[1]"; __mp3_start_shared\' "$source_file" || exit "$?"
for ((attempt=0; attempt<50; attempt++)); do
    if [ -s "$session_dir/worker.fish" ] && [ -f "$session_dir/queue.shared" ] && ! flock -n "$session_dir.lock" true; then
        exit 0
    fi
    sleep 0.1
done
echo \'The new MP3 session did not start.\' >&2
exit 1
' -- "$session_dir" "$HOME/.config/fish/functions/yt.fish" "$runtime_dir"
end

function __mp3_start_shared
    for dependency in flock nohup fish yt-dlp wl-paste
        if not command -q $dependency
            printf "Missing dependency: %s\n" "$dependency" >&2
            return 1
        end
    end
    set -l session_dir "$HOME/.local/state/mp3/session"
    command mkdir -p (path dirname "$session_dir")
    command flock -n -E 73 "$session_dir.lock" true
    set -l session_status $status
    if test $session_status -eq 73
        return 0
    else if test $session_status -ne 0
        return $session_status
    end
    set -l runtime_dir /tmp
    if set -q XDG_RUNTIME_DIR
        set runtime_dir "$XDG_RUNTIME_DIR"
    end
    if test -f "$runtime_dir/mp3.lock"
        command flock -n -E 73 "$runtime_dir/mp3.lock" true
        set -l legacy_status $status
        if test $legacy_status -eq 73
            return 2
        else if test $legacy_status -ne 0
            return $legacy_status
        end
    end
    if command flock -n "$session_dir.lock" true
        command nohup flock -n "$session_dir.lock" fish --no-config -c '
            set -g __mp3_shared_session "$argv[1]"
            while true
                source "$HOME/.config/fish/functions/yt.fish"
                __mp3_run 0
                sleep 5
            end
        ' "$session_dir" </dev/null >> "$HOME/.local/state/mp3-autostart.log" 2>&1 &
        disown $last_pid
    end
    return 0
end

function __mp3_find_legacy_queue
    set -l newest 0
    set -l selected
    for state_dir in /tmp/mp3_queue_*
        set -l pid (string replace "/tmp/mp3_queue_" "" -- "$state_dir")
        if not string match -qr "^[0-9]+\$" -- "$pid"
            continue
        end
        if not command kill -0 "$pid" 2>/dev/null; or not test -f "$state_dir/worker.fish"
            continue
        end
        set -l modified (command stat -c %Y "$state_dir/active" 2>/dev/null)
        if test -n "$modified"; and test "$modified" -ge "$newest"
            set newest "$modified"
            set selected "$state_dir/queue"
        end
    end
    if test -n "$selected"
        printf "%s\n" "$selected"
    end
end

function __mp3_legacy_screen -a queue
    if not test -f "$queue.panel-history"
        set -l log_file "$HOME/.local/state/mp3-autostart.log"
        if test -f "$log_file"
            command tail -n 2000 "$log_file" | string replace -a \r \n | string replace -ar "\e\[[0-9;]*[A-Za-z]" "" | string match -r "^[✓✗↻].*" | command tail -n 10 > "$queue.panel-history.tmp.$fish_pid"
        else
            printf "" > "$queue.panel-history.tmp.$fish_pid"
        end
        command mv "$queue.panel-history.tmp.$fish_pid" "$queue.panel-history"
    end
    command touch "$queue.live"
    set -l completed_files
    for completed in "$queue".status.*.done
        set -a completed_files "$completed"
    end
    begin
        command cat "$queue.panel-history"
        if test (count $completed_files) -gt 0
            for completed in (command ls -tr -- $completed_files | command tail -n 10)
                command cat "$completed"
                printf "\n"
            end
        end
    end | command tail -n 10 | while read -l line
        set -l plain (string replace -ar "\e\[[0-9;]*[A-Za-z]" "" -- "$line")
        set -l color green
        if string match -q "✗*" -- "$plain"
            set color red
        else if string match -qr "^[↻⚠]" -- "$plain"
            set color yellow
        end
        printf "%s%s%s\n" (set_color $color) "$plain" (set_color normal)
    end
    for live in "$queue".status.*
        set -l pid (string replace "$queue.status." "" -- "$live")
        if string match -qr "^[0-9]+\$" -- "$pid"; and command kill -0 "$pid" 2>/dev/null
            command cat "$live" 2>/dev/null
            printf "\n"
        end
    end
end

function __mp3_pretty_screen -a screen tick queue
    set -l cyan (set_color 89dceb)
    set -l white (set_color cdd6f4)
    set -l dim (set_color 585b70)
    set -l reset (set_color normal)
    set -l frames ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    set -l width 80
    if set -q COLUMNS; and string match -qr '^[0-9]+$' -- "$COLUMNS"
        set width $COLUMNS
    end
    set -l bar_width (math "min(15, max(3, floor($width / 4)))")
    set -l title_width (math "max(1, $width - $bar_width - 12)")
    set -l lines (string split \n -- "$screen" | string replace -ar '\e\[[0-9;]*[A-Za-z]' '')
    set lines (string match -v 'Clipboard monitor stopped; restarting.' -- $lines)
    set -l longest 1
    for line in $lines
        set -l parts (string match -rg '^[↓♫]\s*([0-9.]+)% · (.*?) · [━─·]+' -- "$line")
        if test (count $parts) -eq 2
            set longest (math "max($longest, "(string length -- "$parts[2]")")")
        end
    end
    set title_width (math "min($title_width, $longest)")
    for line in $lines
        if not string match -qr '^[✓✗↻⚠]' -- "$line"
            continue
        end
        set -l color a6e3a1
        string match -q '✗*' -- "$line"; and set color f38ba8
        string match -qr '^[↻⚠]' -- "$line"; and set color f9e2af
        printf '%s%s%s\n' (set_color $color) (string shorten -m (math "max(1, $width - 1)") -- "$line") "$reset"
    end
    set -l row 0
    for line in $lines
        set -l parts (string match -rg '^[↓♫]\s*([0-9.]+)% · (.*?) · [━─·]+' -- "$line")
        if test (count $parts) -eq 2
            set -l percent (math "min(100, max(0, $parts[1]))")
            set -l filled (math "floor($percent * $bar_width / 100)")
            set -l empty (math "$bar_width - $filled")
            set -l bar (string repeat -n $filled '━')
            if test $empty -gt 0
                set bar "$bar╸"
                set empty (math "$empty - 1")
            end
            set -l metrics (string match -rg ' · [━─·]+ · ([^·]+) · ETA ([^·]+)' -- "$line")
            set -l details ''
            if test (count $metrics) -eq 2
                set details " · "(string trim -- "$metrics[1]")" · ETA "(string trim -- "$metrics[2]")
                if test $width -lt 65
                    set details " · ETA "(string trim -- "$metrics[2]")
                end
            end
            set -l row_title_width (math "max(1, min($title_width, $width - $bar_width - 12 - "(string length -- "$details")"))")
            set -l title (string shorten -m $row_title_width -- "$parts[2]")
            set -l padding (string repeat -n (math "$row_title_width - "(string length -- "$title")) ' ')
            set -l trail (string repeat -n $empty '─')
            set -l frame (math "($tick + $row) % 10 + 1")
            printf '%s%s %s%s%s  %s%s%s%s  %s%3.0f%%%s%s\n' "$cyan" "$frames[$frame]" "$white" "$title" "$padding" "$cyan" "$bar" "$dim" "$trail" "$cyan" "$percent" "$details" "$reset"
            set row (math "$row + 1")
        else if string match -qr '^[✓✗↻⚠]' -- "$line"
            continue
        else if string match -q '◌ *' -- "$line"
            set -l frame (math "($tick + $row) % 10 + 1")
            set -l text (string sub -s 3 -- "$line")
            printf '%s%s %s%s%s\n' "$cyan" "$frames[$frame]" "$white" (string shorten -m (math "max(1, $width - 3)") -- "$text") "$reset"
            set row (math "$row + 1")
        else if test -n "$line"
            set -l stage (string match -rg '^(◈ Adding cover|◇ Adding metadata) · (.*)$' -- "$line")
            if test (count $stage) -eq 2
                set -l symbol (string sub -l 1 -- "$stage[1]")
                set -l frame (math "($tick + $row) % 10 + 1")
                set -l title (string shorten -m (math "max(1, $width - 7)") -- "$stage[2]")
                printf '%s%s %s%s  %s%s%s\n' "$cyan" "$frames[$frame]" "$white" "$title" "$cyan" "$symbol" "$reset"
                set row (math "$row + 1")
            else
                printf '%s%s%s\n' "$dim" (string shorten -m (math "max(1, $width - 1)") -- "$line") "$reset"
            end
        end
    end
    if test -f "$queue"
        set -l waiting (count (string match -rv '^\s*$' < "$queue"))
        if test -f "$queue.consumed"
            set -l consumed (string trim < "$queue.consumed")
            if string match -qr '^[0-9]+$' -- "$consumed"
                set waiting (math "max(0, $waiting - $consumed)")
            end
        end
        if test $waiting -gt 0
            printf '%s≡ %s%s\n' (set_color f9e2af) "$waiting" "$reset"
        end
    end
end

function __mp3_attach -a verbose
    __mp3_restart_shared
    set -l session_status $status
    if not contains -- $session_status 0 2
        return $session_status
    end
    set -l session_dir "$HOME/.local/state/mp3/session"
    set -g __mp3_view_closed false
    function __mp3_close_view --on-event fish_cancel --on-event fish_postexec
        set -g __mp3_view_closed true
        if isatty stdout
            printf "\e[?25h\e[?1049l"
        end
        functions -e __mp3_close_view
    end
    if isatty stdout
        printf "\e[?1049h\e[?25l"
    end
    set -l previous ""
    set -l tick 0
    while test "$__mp3_view_closed" = false
        set -l panel_queue "$session_dir/queue"
        set -l screen "Starting MP3 session…"
        if test $session_status -eq 2
            set -l legacy_queue (__mp3_find_legacy_queue)
            if test -n "$legacy_queue"
                set panel_queue "$legacy_queue"
                set screen (__mp3_legacy_screen "$legacy_queue" | string collect)
            else
                set screen "Waiting for the active download session…"
            end
            __mp3_start_shared
            set session_status $status
        else if test "$verbose" = 1; and test -f "$session_dir/queue.log"
            set screen (begin
                command tail -n 25 "$session_dir/queue.log"
            end | string collect)
        else if test -f "$session_dir/screen"
            set screen (command cat "$session_dir/screen" | string collect)
        end
        if test "$verbose" != 1
            set screen (__mp3_pretty_screen "$screen" $tick "$panel_queue" | string collect)
            set tick (math "($tick + 1) % 10")
        end
        if test "$screen" != "$previous"
            if isatty stdout
                printf "\e[H\e[J"
            end
            printf "%s\n" "$screen"
            set previous "$screen"
        end
        sleep 0.3
    end
    if isatty stdout
        printf "\e[?25h\e[?1049l"
    end
    functions -e __mp3_close_view
    set -e __mp3_view_closed
end

function mp3 --description 'script: {"label":"MP3","entry":"__mp3_run","args":["0"],"variables":{"__mp3_shared_session":"~/.local/state/mp3/session"},"lock":"~/.local/state/mp3/session.lock","locks":["~/.local/state/mp3/session.lock","${XDG_RUNTIME_DIR}/mp3.lock"],"session":"~/.local/state/mp3/session","queues":["/tmp/mp3_queue_*"],"history":"~/.local/state/mp3/session/history"}'
    if test "$argv[1]" = --background
        __mp3_start_shared
    else if test (count $argv) -gt 0
        __mp3_run 0 $argv
    else
        __mp3_attach 0
    end
end

function mp3l
    if test (count $argv) -gt 0
        __mp3_run 1 $argv
    else
        __mp3_attach 1
    end
end

# ─── ytp
function ytp --description 'download youtube playlist in order'
    if not command -v yt-dlp >/dev/null 2>&1
        echo -s (set_color red) "yt-dlp not found" (set_color normal)
        return 1
    end

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
        if command -v wl-paste >/dev/null 2>&1
            set -l clip (wl-paste -n 2>/dev/null | string trim)
            if string match -qr '^https?://' -- "$clip"
                set urls "$clip"
            end
        end
    end

    if test (count $urls) -eq 0
        echo -s (set_color yellow) "Usage: ytp <playlist_url>" (set_color normal)
        return 1
    end

    for u in $urls
        yt-dlp \
            --yes-playlist \
            -o "%(playlist_uploader,playlist_channel,uploader,channel)s - %(playlist_title)s/%(playlist_index)02d. %(title)s.%(ext)s" \
            $extra_args \
            "$u"
    end
end
