#!/usr/bin/env bash

shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
action="${1:-}"
shift || exit 2

case "$action" in
    start)
        exec quickshell --no-duplicate "$@"
        ;;
    ipc)
        exec timeout 1s quickshell ipc -p "$shell_config" call -- "$@"
        ;;
    notify)
        if command -v quickshell >/dev/null 2>&1; then
            timeout 1s quickshell ipc -p "$shell_config" call -- hypr notify "${1:--1}" "${2:-2000}" "${3:-0}" "${4:-}" >/dev/null 2>&1
            exit 0
        fi
        exec hyprctl notify "$@" >/dev/null 2>&1
        ;;
    dismiss)
        if command -v quickshell >/dev/null 2>&1; then
            timeout 1s quickshell ipc -p "$shell_config" call -- hypr dismiss >/dev/null 2>&1
            exit 0
        fi
        exec hyprctl dismissnotify "${1:--1}" >/dev/null 2>&1
        ;;
    workspace)
        if command -v quickshell >/dev/null 2>&1; then
            timeout 0.5s quickshell ipc -p "$shell_config" call -- workspaceNotify show "${1:-}" "${2:-}" "${3:-}" >/dev/null 2>&1
            exit 0
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
            timeout 1s quickshell ipc -p "$shell_config" call -- hypr volume "$1" >/dev/null 2>&1
            exit 0
        fi
        exec "$script_dir/utils.sh" volume "$1"
        ;;
    *)
        printf 'Usage: %s {start|ipc|notify|dismiss|workspace|volume} [arguments...]\n' "$0" >&2
        exit 2
        ;;
esac
