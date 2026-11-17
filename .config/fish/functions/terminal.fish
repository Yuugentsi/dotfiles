alias d="cd ~/Downloads"
alias f="rg -l . | fzf"
alias pwd="command pwd | wl-copy; and command pwd"

# ━━━━━━━━━━━━━ mkcd ━━━━━━━━━━━━━
function mkcd -d "mkdir + cd"
    mkdir -p $argv[1]; and cd $argv[1]
end

# ━━━━━━━━━━━━━ empty ━━━━━━━━━━━━━
function empty -d "delete empty dirs"
    set -l n (find (pwd) -type d -empty 2>/dev/null | wc -l)
    find (pwd) -type d -empty -delete 2>/dev/null
    echo "$n folders deleted"
end

# ━━━━━━━━━━━━━ copy ━━━━━━━━━━━━━
function copy -d "copy file"
    if test (count $argv) -ne 1
        printf 'Usage: copy <file>\n' >&2
        return 1
    end
    if not test -f "$argv[1]"; or not test -r "$argv[1]"
        printf 'File does not exist or is not readable: %s\n' "$argv[1]" >&2
        return 1
    end
    command wl-copy --type text/plain <"$argv[1]"; or return $status
    set -l line_count (awk 'END { print NR }' < "$argv[1]")
    printf '✓ %s\n' "$line_count"
end

# ━━━━━━━━━━━━━ s ━━━━━━━━━━━━━
function s -d "dir size"
    if test (count $argv) -gt 1
        printf 'Usage: s [directory]\n' >&2
        return 1
    end
    set -l directory .
    if test (count $argv) -eq 1
        set directory "$argv[1]"
    end
    if not test -d "$directory"
        printf 'Directory does not exist: %s\n' "$directory" >&2
        return 1
    end
    command du -sh -- "$directory"
end

# ━━━━━━━━━━━━━ c ━━━━━━━━━━━━━━
function c -d "move from HOME"
    set -l args (string replace -a '"' '' -- $argv | string replace -a "'" '')
    if test (count $args) -eq 1; and string match -rq '^.+\..+$' -- $args[1]
        set args (string split -r -m1 . -- $args[1])
    end
    if not set -q args[2]
        echo 'c <name> <ext...>' >&2
        return 2
    end
    set -l n $args[1]
    if not string match -rq '^[[:alnum:]_ -]+$' -- "$n"
        set_color ff6b8a; echo "✗ invalid: $n" >&2; set_color normal
        return 2
    end
    set -l a
    set -l l
    for e in $args[2..-1]
        set e (string trim -- $e | string replace -r '^\.' '')
        if not string match -rq '^[[:alnum:]_-]+$' -- "$e"
            set_color ff6b8a; echo "✗ invalid: $e" >&2; set_color normal
            return 2
        end
        set -q a[1]; and set -a a -o
        set -a a -iname "*$n*.$e"
        set -a l .$e
    end
    set -l x (string join ' ' -- $l)
    set -l f (find $HOME -type f \( $a \) 2>/dev/null)
    set -l c 0
    set -l k 0
    for i in $f
        test (dirname -- $i) = $PWD; and continue
        set c (math $c + 1)
        if test -e (basename -- $i)
            set_color ff6b8a; echo "✗ exists: "(basename -- $i) >&2; set_color normal
            continue
        end
        printf "\r\033[K"; set_color 89b4fa; printf "→ %s" (basename -- $i); set_color normal
        command mv -- $i .; and set k (math $k + 1)
    end
    if test $c -eq 0
        printf "\r\033[K"; set_color 6c7086; echo "∅ no $n $x files"; set_color normal
        return 0
    end
    clear
    if test $k -eq $c
        set_color a6e3a1; echo "✓ $k moved"
    else
        set_color ff6b8a; echo "✗ $k/$c moved"
    end
    set_color normal
    test $k -eq $c
end

# ━━━━━━━━━━━━━ cc ━━━━━━━━━━━━━
function cc -d "move to ./name/"
    set -l p $argv
    if test (count $argv) -eq 1
        set p (string split -r -m1 . -- $argv[1])
    end
    if not set -q p[2]
        echo 'cc <name> <ext...>' >&2
        return 2
    end
    set -l d (string replace -a '"' '' -- $p[1])
    command mkdir -p -- "$d"; or return 1
    set -l here $PWD
    cd -- "$d"
    c $argv
    set -l s $status
    cd -- $here
    return $s
end

# ━━━━━━━━━━━━━━ x ━━━━━━━━━━━━━━
function x -d "make executable"
    clear
    if test (count $argv) -eq 0
        set -l sh (find (pwd) -maxdepth 1 -name "*.sh" -type f)
        if test (count $sh) -gt 0
            command chmod +x $sh; or return $status
            for f in $sh
                set_color a6e3a1
                printf "  ✓ "
                set_color normal
                printf "%s" (basename $f)
                set_color --dim
                printf "  +x\n"
                set_color normal
            end
        end
    else
        command chmod -R $argv (pwd)
    end
end

# ━━━━━━━━━ cleancopy ━━━━━━━━━━
function cleancopy -d "remove duplicates"
    set -l rows
    for i in *
        test -f "$i"; or continue
        set -l h (command md5sum -- "$i" | string split -f1 " ")
        set -l k 0
        string match -qr '\(\d+\)' -- "$i"; and set k 1
        set -a rows "$h $k $i"
    end
    set -l sorted (printf '%s\n' $rows | sort -k1,1 -k2,2 -k3,3)
    set -l last ""
    set -l n 0
    for r in $sorted
        set -l f (string split -m2 " " -- $r)
        if test "$f[1]" = "$last"
            set_color ff6b8a; echo "− $f[3]"; set_color normal
            command rm -- "$f[3]"; and set n (math $n + 1)
        else
            set last $f[1]
        end
    end
    if test $n -eq 0
        set_color 6c7086; echo "∅ no duplicates"; set_color normal
        return 0
    end
    set_color a6e3a1; echo "✓ $n removed"; set_color normal
end

# ━━━━━━━━━━━━ pass ━━━━━━━━━━━━
function pass -d "toggle sudo"
    if test (count $argv) -ne 0
        printf 'Usage: pass\n' >&2
        return 2
    end
    sudo /usr/bin/bash -c 'set -euo pipefail
export PATH=/usr/bin:/usr/sbin
export LC_ALL=C
user_id="$1"
[[ "$user_id" =~ ^[0-9]+$ ]]
shopt -s nullglob
rule_files=(/etc/sudoers.d/zz-pass-${user_id}-*)
if ((${#rule_files[@]})); then
    rm -f -- "${rule_files[@]}"
    visudo -c >/dev/null
    printf "Passwordless sudo disabled.\n"
    exit 0
fi
rule_file=$(mktemp "/etc/sudoers.d/zz-pass-${user_id}-XXXXXXXX")
trap "rm -f -- \"$rule_file\"" EXIT
chmod 0440 "$rule_file"
printf "#%s ALL=(ALL:ALL) NOPASSWD: ALL\n" "$user_id" > "$rule_file"
visudo -cf "$rule_file" >/dev/null
visudo -c >/dev/null
trap - EXIT
printf "Passwordless sudo enabled until you run pass again.\n"' -- (id -u)
    or return $status
    command sudo -k
end

# ━━━━━━━━━━━━━ re ━━━━━━━━━━━━━
function re -d "random rename"
    set -l files
    for i in *
        test -f "$i"; or continue
        set -a files $i
    end
    if test (count $files) -eq 0
        set_color 6c7086; echo "∅ no files"; set_color normal
        return 0
    end
    set -l planned
    set -l k 0
    for i in $files
        set -l ext ""
        if string match -q '*.*' -- $i
            set ext (string match -r '\.[^.]+$' -- $i)
        end
        set -l new ""
        while true
            set new (random 10000000 99999999)$ext
            if test -e "$new"; or contains -- "$new" $planned
                continue
            end
            break
        end
        set -a planned $new
        printf "\r\033[K"; set_color 89b4fa; printf "→ %s" "$new"; set_color normal
        command mv -- "$i" "$new"; and set k (math $k + 1)
    end
    clear
    set_color a6e3a1; echo "✓ $k renamed"; set_color normal
end

# ━━━━━━━━━━━━━ r ━━━━━━━━━━━━━
function r -d rm
    if not set -q argv[1]
        echo 'r <ext...>' >&2
        return 2
    end
    set -l a
    set -l l
    for e in $argv
        set e (string trim -- $e | string replace -r '^\.' '')
        if not string match -rq '^[[:alnum:]_-]+$' -- "$e"
            set_color ff6b8a
            echo "✗ invalid: $e" >&2
            set_color normal
            return 2
        end
        set -q a[1]; and set -a a -o
        set -a a -iname "*.$e"
        set -a l .$e
    end
    set -l x (string join ' ' -- $l)
    set -l f (find $HOME -type f \( $a \) 2>/dev/null)
    set -l n (count $f)
    if test $n -eq 0
        set_color 6c7086
        echo "∅ no $x files"
        set_color normal
        return 0
    end
    set_color 6c7086
    string replace -- $HOME '~' $f
    set_color normal
    read -P (set_color ff6b8a)"󰆴 delete $n $x? "(set_color 6c7086)"[y/N] "(set_color normal) -l q
    if not contains -- (string lower -- "$q") y yes s sim
        set_color 6c7086
        echo '· cancelled'
        set_color normal
        return 0
    end
    set -l k 0
    for i in $f
        command rm -f -- $i; and set k (math $k + 1)
    end
    if test $k -eq $n
        set_color a6e3a1
        echo "✓ $k deleted"
    else
        set_color ff6b8a
        echo "✗ $k/$n deleted"
    end
    set_color normal
    test $k -eq $n
end

# ━━━━━━━━━━━━━ sd ━━━━━━━━━━━━━
function sd -d "push"
    set -l jobs 12
    if test (count $argv) -gt 1; or begin
            test (count $argv) -eq 1; and not string match -qr '^[1-9][0-9]{0,2}$' -- $argv[1]
        end
        printf 'Usage: sd [parallel]\n' >&2
        return 2
    end
    set -q argv[1]; and set jobs $argv[1]
    if not command adb get-state >/dev/null 2>&1
        printf 'Phone not connected over adb\n' >&2
        return 1
    end
    set -l base /sdcard/Download/(basename -- $PWD)
    set -l files (command find . -type f -printf '%P\n')
    if test (count $files) -eq 0
        printf 'No files\n' >&2
        return 1
    end
    printf '%s\0' $files | command xargs -0 -P $jobs -I{} sh -c 'adb push "$1" "$2/$1" || exit 255' _ {} $base
    set -l status_code $status
    test $status_code -eq 0
end

# ━━━━━━━━━━━━ sshtoggle ━━━━━━━━━━━━
function sshtoggle -d "toggle the ssh server"
    clear

    set -l red (set_color ff6b8a)
    set -l green (set_color a6e3a1)
    set -l gray (set_color 6c7086)
    set -l normal (set_color normal)

    if not command -q sshd
        printf '%s✗ openssh missing%s %s· sudo pacman -S openssh%s\n' $red $normal $gray $normal
        return 1
    end

    if systemctl is-active --quiet sshd
        sudo systemctl stop sshd; or return $status
        printf '%s○ ssh off%s\n' $red $normal
        return 0
    end

    sudo systemctl start sshd; or return $status

    set -l addresses (ip -4 -o addr show up scope global | awk '{ split($4, a, "/"); print a[1] }')
    if test (count $addresses) -eq 0
        printf '%s●%s %sno ip%s\n' $green $normal $gray $normal
        return 0
    end

    set -l targets
    for address in $addresses
        set -a targets (whoami)"@$address"
    end
    printf '%s●%s %s%s%s\n' $green $normal $green (string join ' · ' $targets) $normal
end

# ━━━━━━━━━━━━ security ━━━━━━━━━━━━
function security -d "toggle security app"
    command -q adb; or begin
        echo 'ADB not found.' >&2
        return 1
    end
    command adb get-state >/dev/null; or return
    set -l p com.miui.securitycenter
    set -l r (command adb shell pm list packages --user 0 "$p"); or return
    if contains -- "package:$p" (string trim -- $r)
        set r (command adb shell pm uninstall -k --user 0 "$p"); or return
        if not contains -- Success (string trim -- $r)
            printf '%s\n' $r >&2
            return 1
        end
        set_color ff6b8a
        printf '✓ Security · removed (data preserved)\n'
        set_color normal
    else
        set r (command adb shell cmd package install-existing --user 0 "$p"); or begin
            set -l s $status
            printf '%s\n' $r >&2
            return $s
        end
        set r (command adb shell pm enable --user 0 "$p"); or begin
            set -l s $status
            printf '%s\n' $r >&2
            return $s
        end
        set_color a6e3a1
        printf '✓ Security · restored and enabled\n'
        set_color normal
    end
end
