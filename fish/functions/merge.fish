function merge -d "Move files up inside each subfolder"
    set -l target (string trim -r -c '/' -- $argv[1])
    if test -z "$target"
        set target (pwd)
    end
    if not test -d "$target"
        echo "not a directory: $target"
        return 1
    end

    for dir in "$target"/*/
        set dir (string trim -r -c '/' -- "$dir")
        test -d "$dir" || continue

        find "$dir" -mindepth 1 -type f | while read -l f
            set -l base (basename "$f")
            mv -n "$f" "$dir/$base"
        end

        find "$dir" -mindepth 1 -type d -empty -delete
    end

    echo "done: $target"
end
