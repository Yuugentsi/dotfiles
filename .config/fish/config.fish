if status is-interactive
end

set -g fish_greeting

# ── functions
for f in ~/.config/fish/functions/*.fish
    source $f
end

alias pwd="command pwd | wl-copy; and command pwd"
alias myip="echo -n 'IP:  '; ip -4 -o a show | awk '/inet / && !/127.0.0.1/{print \$4}' | cut -d/ -f1 | head -1; echo -n 'DNS: '; awk '/^nameserver/{print \$2}' /etc/resolv.conf | head -1"
alias f="rg -l . | fzf"
alias d="cd ~/Downloads"
alias c="clear"

# ─────────── zoxide ───────────
if command -q zoxide
    zoxide init fish | source
end

# ─────────── fzf ───────────
if command -q fzf
    fzf --fish | source
end

# ── prompt
set -g fish_transient_prompt 1

function fish_prompt
    if set -q argv[1]
        echo -n "❯ "
        return
    end

    set -l last_status $status

    set -l status_color f5c2e7
    if test $last_status -ne 0
        set status_color ff6b8a
    end

    set -l pwd (string replace -r "^$HOME/" "" "$PWD")
    string match -q "$HOME" "$PWD"; and set pwd "~"

    set -l DIM (set_color 7c5cbf)
    set -l DIR (set_color c8b8de --bold)
    set -l N (set_color normal)

    echo -s "$DIM●$N $DIR$pwd$N"
    echo -n -s "$DIM╰─$N " (set_color $status_color --bold) "❯ " (set_color normal)
end
