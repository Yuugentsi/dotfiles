# ─────────── art ───────────
function art -d "tag all albums via metadata"
    set reset (printf '%b' '\033[0m')
    set bold (printf '%b' '\033[1m')
    set green (printf '%b' '\033[32m')
    set yellow (printf '%b' '\033[33m')
    set cyan (printf '%b' '\033[36m')
    set red (printf '%b' '\033[31m')
    set magenta (printf '%b' '\033[35m')
    set dim (printf '%b' '\033[2m')

    set has_subdirs 0
    for dir in */
        if test -d "$dir"
            set has_subdirs 1
            break
        end
    end

    if test $has_subdirs -eq 0
        set artist (basename (dirname (pwd)))
        set album (basename (pwd))

        if test (count $argv) -gt 0
            set genre "$argv[1]"
            printf "$green✓$reset Genre: $bold%s$reset (via argument)\n" $genre
        else
            read -P "Genre? (leave empty to keep original): " genre
            if test -z "$genre"
                printf "$yellow⚠$reset Genre: keep original\n"
            else
                printf "$green✓$reset Genre: $bold%s$reset\n" $genre
            end
        end

        printf "$cyan♪$reset Artist: $bold%s$reset\n" $artist
        printf "$cyan♪$reset Album: $bold%s$reset\n" $album
        printf "$dim──────────────────────────────────────────────────────────────────────────────$reset\n"

        set ok 0
        set fail 0
        set skip 0

        for file in *.mp3 *.flac *.m4a *.wav
            test -f "$file"; or continue

            set ext (string split -r -m 1 . "$file" | tail -1)

            set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
            if test -z "$title"
                set title (string replace -r '\.[^.]+$' '' "$file")
            end

            set title (string replace -a '/' '-' "$title")
            set title (string replace -a '\\' '-' "$title")
            set title (string replace -a ':' '-' "$title")
            set title (string trim "$title")

            set newname "$title.$ext"

            if test -n "$genre"
                set genre_meta -metadata "genre=$genre"
            end

            ffmpeg -loglevel quiet -y -i "file:$file" \
                -map 0:a \
                -c:a copy \
                -metadata artist="$artist" \
                -metadata album_artist="$artist" \
                -metadata ARTISTS="$artist" \
                -metadata album="$album" \
                $genre_meta \
                ".__tmp.$file"

            if test $status -ne 0
                ffmpeg -loglevel quiet -y -i "file:$file" \
                    -map 0:a \
                    -c:a libmp3lame -q:a 0 \
                    -metadata artist="$artist" \
                    -metadata album_artist="$artist" \
                    -metadata ARTISTS="$artist" \
                    -metadata album="$album" \
                    $genre_meta \
                    ".__tmp.$file"
            end

            if test $status -eq 0
                mv -f ".__tmp.$file" "$newname"
                and rm -f "$file"
                set ok (math $ok + 1)
                printf "$green✓$reset %s\n" $newname
            else
                rm -f ".__tmp.$file"
                set fail (math $fail + 1)
                printf "$red✗$reset %s\n" $file
            end
        end

        echo ""
        printf "$green✓ Done! $ok tagged$reset\n"
        if test $fail -gt 0
            printf "$red✗ $fail failed$reset\n"
        end
        read -l -P "Create zip? [y/N] " create_zip
        if test "$create_zip" = y
            set zip_name (basename (pwd)).zip
            zip -r "$zip_name" . > /dev/null
            printf "$green✓$reset Zip created: $bold%s$reset\n" $zip_name
        end
        return
    end

    set artist (basename (pwd))

    if test (count $argv) -gt 0
        set genre "$argv[1]"
        printf "$green✓$reset Genre: $bold%s$reset (via argument)\n" $genre
    else
        read -P "Genre? (leave empty to keep original): " genre
        if test -z "$genre"
            printf "$yellow⚠$reset Genre: keep original\n"
        else
            printf "$green✓$reset Genre: $bold%s$reset\n" $genre
        end
    end

    printf "$cyan♪$reset Artist: $bold%s$reset\n" $artist
    printf "$dim──────────────────────────────────────────────────────────────────────────────$reset\n"
    echo "Processing albums..."
    echo ""

    set skip_dirs Singles EP Compilations

    for dir in */
        set dir_name (basename "$dir")

        if string match -q '*[:/]*' "$dir_name"
            set safe_name (string replace -a ':' '-' "$dir_name")
            set safe_name (string replace -a '/' '-' "$safe_name")
            set safe_name (string trim "$safe_name")
            if test "$dir_name" != "$safe_name"
                mv -v "$dir" "$safe_name"
                set dir "$safe_name/"
                set dir_name "$safe_name"
            end
        end

        set first_file (find "$dir" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | head -1)

        set skip 0
        for skip_name in $skip_dirs
            if string match -qi "$skip_name" "$dir_name"
                set skip 1
                break
            end
        end

        if test $skip -eq 1
            printf "$yellow→$reset Skipping special folder: $bold'%s'$reset\n" $dir_name
            continue
        end

        if test -n "$first_file"
            set album_name (ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$first_file" 2>/dev/null)

            if test -n "$album_name"
                set album_name (string replace -a ':' '-' "$album_name")
                set album_name (string replace -a '/' '-' "$album_name")
                set album_name (string trim "$album_name")

                if test "$dir_name" != "$album_name"
                    mv -v "$dir" "$album_name" 2>/dev/null
                    set dir "$album_name/"
                end
            end
        end
    end

    set total_files 0
    for dir in */
        for file in "$dir"*.mp3 "$dir"*.flac "$dir"*.m4a "$dir"*.wav
            if test -f "$file"
                set total_files (math $total_files + 1)
            end
        end
    end

    if test $total_files -eq 0
        printf "$red✗$reset No audio files found.\n"
        return
    end

    printf "$dim Processing $bold%d$reset$dim tracks...$reset\n" $total_files
    echo ""

    set tmpdir (mktemp -d /tmp/tagfix.XXXXXX)
    set counter 0
    set total_count 0
    set stats_list
    set global_singles_count 0
    set global_singles_duration 0

    for dir in */
        set album_name (basename "$dir")
        set album_counter 0
        set album_errors 0
        set album_duration 0
        set album_year ""

        set is_special 0
        for skip_name in $skip_dirs
            if string match -qi "$skip_name" "$album_name"
                set is_special 1
                break
            end
        end

        if test $is_special -eq 0
            set first_file (find "$dir" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | head -1)
            if test -n "$first_file"
                set raw_date (ffprobe -v quiet -show_entries format_tags=date -of default=noprint_wrappers=1:nokey=1 "$first_file" 2>/dev/null)
                if test -z "$raw_date"
                    set raw_date (ffprobe -v quiet -show_entries format_tags=year -of default=noprint_wrappers=1:nokey=1 "$first_file" 2>/dev/null)
                end
                if test -n "$raw_date"
                    set album_year (string sub -l 4 "$raw_date")
                end
            end
        end

        for file in "$dir"*.mp3 "$dir"*.flac "$dir"*.m4a "$dir"*.wav
            if test -f "$file"
                set counter (math $counter + 1)
                set album_counter (math $album_counter + 1)
                set ext (string split -r -m 1 . "$file" | tail -1)
                set tmpfile "$tmpdir/tmp.$counter.$ext"
                set oldname (basename "$file")

                set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
                if test -z "$title"
                    set title "Untitled"
                end

                set title (string replace -a '/' '-' "$title")
                set title (string replace -a '\\' '-' "$title")
                set title (string replace -a ':' '-' "$title")

                set newname "$title.$ext"
                set newpath "$dir$newname"
                set dup_counter 1
                while test -f "$newpath" -a "$newpath" != "$file"
                    set newname "$title ($dup_counter).$ext"
                    set newpath "$dir$newname"
                    set dup_counter (math $dup_counter + 1)
                end

                set pct (math "round($counter / $total_files * 100)")
                if test $pct -lt 30
                    set pct_color "$red"
                else if test $pct -lt 70
                    set pct_color "$yellow"
                else
                    set pct_color "$green"
                end
                printf "\r\033[K $pct_color%3d%%$reset $dim|$reset $cyan%-25s$reset $dim|$reset %-38s" $pct $album_name $newname

                if test -n "$genre"
                    set genre_meta -metadata "genre=$genre"
                end

                if test $is_special -eq 1
                    set album_meta
                else
                    set album_meta -metadata "album=$album_name"
                end

                ffmpeg -loglevel quiet -i "file:$file" \
                    -metadata artist="$artist" \
                    -metadata album_artist="$artist" \
                    -metadata ARTISTS="$artist" \
                    $album_meta \
                    $genre_meta \
                    -codec copy -y "$tmpfile" 2>/dev/null

                if test $status -eq 0
                    mv -f "$tmpfile" "$newpath"
                    set mv_status $status
                    if test $mv_status -eq 0
                        if test "$newpath" != "$file"
                            rm -f "$file"
                        end
                        set dur (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$newpath" 2>/dev/null)
                        if test -n "$dur"
                            set album_duration (math "$album_duration + $dur")
                            if test $is_special -eq 1
                                set global_singles_duration (math "$global_singles_duration + $dur")
                            end
                        end
                    else
                        printf "\n"
                        printf "$red✗$reset ERROR moving temp: $bold%s$reset\n" $newname
                        set album_errors (math $album_errors + 1)
                    end
                else
                    printf "\n"
                    printf "$red✗$reset ERROR processing: $bold%s$reset\n" $file
                    set album_errors (math $album_errors + 1)
                end
            end
        end

        set success_count (math $album_counter - $album_errors)
        if test $success_count -gt 0
            if test $album_errors -gt 0
                printf "\r\033[K%-70s\n" " $red✗$reset $magenta$album_name$reset $dim($success_count tracks, $album_errors errors)$reset"
            else
                printf "\r\033[K%-70s\n" " $green✓$reset $bold$cyan$album_name$reset $dim($success_count tracks)$reset"
            end

            set total_count (math $total_count + $success_count)
            set mins (math "floor($album_duration / 60)")

            if test $is_special -eq 1
                set global_singles_count $success_count
            else
                set stats_list $stats_list "$album_name|$mins|$success_count|$album_year"
            end
        end
    end

    rm -rf "$tmpdir"

    set singles_dir ""
    for d in */
        if string match -qi "singles" (basename "$d")
            set singles_dir (basename "$d")
            break
        end
    end

    if test -n "$singles_dir"
        echo ""
        printf "$dim──────────────────────$reset\n"
        printf "$yellow♻$reset Checking duplicates in Singles folder...\n"
        set albums_titles_file (mktemp)
        find . -maxdepth 2 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) ! -path "*/$singles_dir/*" | while read f
            set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
            if test -n "$title"
                echo "$title"
            end
        end | sort -u > "$albums_titles_file"

        set deleted_count 0
        for single in "$singles_dir"/*.mp3 "$singles_dir"/*.flac "$singles_dir"/*.m4a "$singles_dir"/*.wav
            if test -f "$single"
                set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$single" 2>/dev/null)
                if test -n "$title"
                    if grep -qx "$title" "$albums_titles_file"
                        printf " $red✗$reset $dim%s$reset $red-> already exists in album$reset\n" (basename $single)
                        set dur (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$single" 2>/dev/null)
                        if test -n "$dur"
                            set global_singles_duration (math "$global_singles_duration - $dur")
                        end
                        set global_singles_count (math $global_singles_count - 1)

                        rm -f "$single"
                        set deleted_count (math $deleted_count + 1)
                    end
                end
            end
        end
        rm -f "$albums_titles_file"
        if test $deleted_count -gt 0
            printf "$green✓$reset $bold%d$reset singles removed.\n" $deleted_count
        else
            printf "$dim  No duplicates found.$reset\n"
        end

        echo ""
        printf "$yellow♻$reset Checking internal duplicates in Singles folder...\n"
        set internal_deleted 0
        for single in "$singles_dir"/*.mp3 "$singles_dir"/*.flac "$singles_dir"/*.m4a "$singles_dir"/*.wav
            if test -f "$single"
                set basename_single (basename "$single")
                set base_no_num (string match -r '^(.*) \([0-9]+\)\.[a-zA-Z0-9]+$' "$basename_single" | head -2 | tail -1)
                if test -n "$base_no_num"
                    set ext (string split -r -m 1 . "$basename_single" | tail -1)
                    set original_file "$singles_dir/$base_no_num.$ext"
                    if test -f "$original_file"
                        printf " $red✗$reset $dim%s$reset $red-> internal duplicate$reset\n" $basename_single
                        set dur (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$single" 2>/dev/null)
                        if test -n "$dur"
                            set global_singles_duration (math "$global_singles_duration - $dur")
                        end
                        set global_singles_count (math $global_singles_count - 1)

                        rm -f "$single"
                        set internal_deleted (math $internal_deleted + 1)
                    end
                end
            end
        end
        if test $internal_deleted -gt 0
            printf "$green✓$reset $bold%d$reset internal duplicates removed.\n" $internal_deleted
        else
            printf "$dim  No internal duplicates found.$reset\n"
        end
    end

    set cache_dir "$HOME/.cache/art"
    mkdir -p "$cache_dir"
    set playlist "$cache_dir/$artist.m3u8"
    set cwd (pwd)

    echo "#EXTM3U" > "$playlist"
    for file in *.mp3 *.flac *.m4a *.wav
        if test -f "$file"
            echo "$cwd/$file" >> "$playlist"
        end
    end
    for dir in */
        for file in "$dir"*.mp3 "$dir"*.flac "$dir"*.m4a "$dir"*.wav
            if test -f "$file"
                echo "$cwd/$file" >> "$playlist"
            end
        end
    end
    printf "$dim  ♫$reset Playlist saved: $bold%s$reset\n" (basename "$playlist")

    echo ""
    printf "$dim──────────────────────$reset\n"

    set sorted_stats (printf '%s\n' $stats_list | LC_ALL=C sort -t'|' -k4,4n)

    set final_total $global_singles_count
    for entry in $sorted_stats
        set parts (string split '|' $entry)
        set final_total (math $final_total + $parts[3])
    end

    printf "$bold%s$reset $dim(%d)$reset\n" $artist $final_total
    printf "$dim──────────────────────$reset\n"

    set clipboard_text ""

    for entry in $sorted_stats
        set parts (string split '|' $entry)
        set name $parts[1]
        set mins $parts[2]
        set count $parts[3]
        set year ""
        if test (count $parts) -ge 4
            set year $parts[4]
        end

        printf "$bold%s$reset\n" $name
        if test -n "$year"
            printf "$dim%d min • %d • %s$reset\n" $mins $count $year
            set clipboard_text "$clipboard_text$name\n$mins min • $count • $year\n───────\n"
        else
            printf "$dim%d min • %d$reset\n" $mins $count
            set clipboard_text "$clipboard_text$name\n$mins min • $count\n───────\n"
        end
        printf "$dim───────$reset\n"
    end

    if test $global_singles_count -gt 0
        set singles_mins (math "floor($global_singles_duration / 60)")
        printf "$bold$singles_dir$reset\n"
        printf "$dim%d min • %d$reset\n" $singles_mins $global_singles_count
        printf "$dim───────$reset\n"
        set clipboard_text "$clipboard_text$singles_dir\n$singles_mins min • $global_singles_count\n───────\n"
    end

    printf "$artist ($final_total)\n──────────────────────\n$clipboard_text" | wl-copy

    echo ""
    read -l -P "Create zip? [y/N] " create_zip
    if test "$create_zip" = y
        set zip_name (basename (pwd)).zip
        zip -r "$zip_name" . > /dev/null
        printf "$green✓$reset Zip created: $bold%s$reset\n" $zip_name
    end

    printf "$dim──────────────────────$reset\n"
    printf "$green$bold✓ Done!$reset\n"
end


# ─────────── art mp3───────────
function artmp3 -d "tag current album with artist & album"
    set artist (basename (dirname (pwd)))
    set album (basename (pwd))

    set ok 0
    set fail 0
    set skip 0

    set green (printf '\033[32m')
    set red (printf '\033[31m')
    set yellow (printf '\033[33m')
    set cyan (printf '\033[36m')
    set reset (printf '\033[0m')

    set ok_list
    set fail_list
    set skip_list

    for file in *.mp3 *.flac *.m4a *.wav
        test -f "$file"; or continue

        set ext (string split -r -m 1 . "$file" | tail -1)

        set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
        if test -z "$title"
            set title (string replace -r '\.[^.]+$' '' "$file")
        end

        set title (string replace -a '/' '-' "$title")
        set title (string replace -a ':' '-' "$title")
        set title (string trim "$title")

        set newname "$title.$ext"

        if test "$file" = "$newname"
            set skip (math $skip + 1)
            set skip_list $skip_list "$title"
            continue
        end

        ffmpeg -loglevel quiet -y -i "file:$file" \
            -map 0:a \
            -c:a copy \
            -metadata artist="$artist" \
            -metadata album="$album" \
            -metadata album_artist="$artist" \
            ".__tmp.$file"

        if test $status -ne 0
            ffmpeg -loglevel quiet -y -i "file:$file" \
                -map 0:a \
                -c:a libmp3lame -q:a 0 \
                -metadata artist="$artist" \
                -metadata album="$album" \
                -metadata album_artist="$artist" \
                ".__tmp.$file"
        end

        if test $status -eq 0
            mv -f ".__tmp.$file" "$newname"
            and rm -f "$file"
            set ok (math $ok + 1)
            set ok_list $ok_list "$title"
        else
            rm -f ".__tmp.$file"
            set fail (math $fail + 1)
            set fail_list $fail_list "$title"
        end
    end

    echo ""
    echo "$green✓ OK ($ok)$reset"
    for t in $ok_list
        echo "$green$t$reset"
    end

    echo ""
    echo "$red✗ FAIL ($fail)$reset"
    for t in $fail_list
        echo "$red$t$reset"
    end

    echo ""
    echo "$yellow➟ SKIP ($skip)$reset"
    for t in $skip_list
        echo "$yellow$t$reset"
    end
end
# ─────────── tracks ───────────
function tracks -d "tag tracks with artist/album/year"
    set reset (printf '%b' '\033[0m')
    set bold (printf '%b' '\033[1m')
    set green (printf '%b' '\033[32m')
    set yellow (printf '%b' '\033[33m')
    set cyan (printf '%b' '\033[36m')
    set red (printf '%b' '\033[31m')
    set dim (printf '%b' '\033[2m')

    set ok 0
    set fail 0

    set ok_list
    set fail_list

    for file in *.mp3 *.flac *.m4a *.wav
        test -f "$file"; or continue

        set artist (ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
        set album (ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)

        if test -z "$artist"
            set artist "Unknown Artist"
        else
            set artist (string replace -r '[/,].*' '' "$artist" | string trim)
        end
        if test -z "$album"
            set album "Unknown Album"
        end

        set raw_date (ffprobe -v quiet -show_entries format_tags=date -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
        if test -z "$raw_date"
            set raw_date (ffprobe -v quiet -show_entries format_tags=year -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
        end
        set year ""
        if test -n "$raw_date"
            set year (string sub -l 4 "$raw_date")
        end

        set title (ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "file:$file" 2>/dev/null)
        if test -z "$title"
            set title (string replace -r '\.[^.]+$' '' "$file")
        end

        set title (string replace -a '/' '-' "$title")
        set title (string replace -a ':' '-' "$title")
        set title (string trim "$title")

        set ext (string split -r -m 1 . "$file" | tail -1)
        set newname "$title.$ext"

        ffmpeg -loglevel quiet -y -i "file:$file" \
            -map 0:a \
            -c:a copy \
            -metadata artist="$artist" \
            -metadata album_artist="$artist" \
            -metadata album="$album" \
            -metadata date="$year" \
            ".__tmp.$file"

        if test $status -ne 0
            ffmpeg -loglevel quiet -y -i "file:$file" \
                -map 0:a \
                -c:a libmp3lame -q:a 0 \
                -metadata artist="$artist" \
                -metadata album_artist="$artist" \
                -metadata album="$album" \
                -metadata date="$year" \
                ".__tmp.$file"
        end

        if test $status -eq 0
            mv -f ".__tmp.$file" "$newname"
            if test "$newname" != "$file"
                rm -f "$file"
            end
            set ok (math $ok + 1)
            set ok_list $ok_list "$title"
        else
            rm -f ".__tmp.$file"
            set fail (math $fail + 1)
            set fail_list $fail_list "$title"
        end
    end

    echo ""
    echo "$green✓ OK ($ok)$reset"
    for t in $ok_list
        echo "$green$t$reset"
    end

    if test $fail -gt 0
        echo ""
        echo "$red✗ FAIL ($fail)$reset"
        for t in $fail_list
            echo "$red$t$reset"
        end
    end
end
