#!/usr/bin/env bash

shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
action="${1:-}"
shift || exit 2

call_ipc() {
    timeout 1s quickshell ipc -p "$shell_dir" call -- "$@" >/dev/null 2>&1 \
    || timeout 1s quickshell ipc -p "$shell_dir/shell.qml" call -- "$@" >/dev/null 2>&1
}

case "$action" in
    start)
        exec quickshell --no-duplicate "$@"
        ;;
    ipc)
        timeout 1s quickshell ipc -p "$shell_dir" call -- "$@" \
        || timeout 1s quickshell ipc -p "$shell_dir/shell.qml" call -- "$@"
        ;;
    notify)
        if command -v quickshell >/dev/null 2>&1; then
            if call_ipc hypr notify "${1:--1}" "${2:-2000}" "${3:-0}" "${4:-}"; then
                exit 0
            fi
        fi
        exec hyprctl notify "$@" >/dev/null 2>&1
        ;;
    dismiss)
        if command -v quickshell >/dev/null 2>&1; then
            if call_ipc hypr dismiss; then
                exit 0
            fi
        fi
        exec hyprctl dismissnotify "${1:--1}" >/dev/null 2>&1
        ;;
    workspace)
        if command -v quickshell >/dev/null 2>&1; then
            if timeout 0.5s quickshell ipc -p "$shell_dir" call -- workspaceNotify show "${1:-}" "${2:-}" "${3:-}" >/dev/null 2>&1 \
               || timeout 0.5s quickshell ipc -p "$shell_dir/shell.qml" call -- workspaceNotify show "${1:-}" "${2:-}" "${3:-}" >/dev/null 2>&1; then
                exit 0
            fi
        fi
        hyprctl dismissnotify -1 >/dev/null 2>&1
        exec hyprctl notify -1 1200 'rgb(cba6f7)' "fontsize:15 ${1:-}" >/dev/null 2>&1
        ;;
    volume)
        case "${1:-}" in
            up|down|mute) ;;
            *) exit 2 ;;
        esac
        if command -v quickshell >/dev/null 2>&1; then
            if call_ipc hypr volume "$1"; then
                exit 0
            fi
        fi
        exec "$script_dir/utils.sh" volume "$1"
        ;;
    *)
        printf 'Usage: %s {start|ipc|notify|dismiss|workspace|volume} [arguments...]\n' "$0" >&2
        exit 2
        ;;
esac
