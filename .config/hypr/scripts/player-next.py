from pathlib import Path
import runpy
import subprocess
import sys
import time


def read_track(player=None):
    command = ['playerctl']
    if player:
        command.extend(['--player', player])
    command.extend(['metadata', '--format', '{{playerName}}\t{{mpris:trackid}}\t{{xesam:url}}\t{{artist}}\t{{title}}\t{{mpris:artUrl}}\tEND'])
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=1, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    fields = result.stdout.rstrip('\n').split('\t', 6)
    if result.returncode or len(fields) != 7 or fields[-1].strip() != 'END':
        return None
    return fields[:6]


def show_notification(track):
    script = str(Path.home() / '.config/hypr/scripts/quickshell.sh')
    if track and track[4].strip():
        details = f'{track[3]} — {track[4]}' if track[3] else track[4]
    else:
        details = 'Next track'
    try:
        subprocess.run([script, 'notify', '-1', '1000', 'rgb(cba6f7)', f'󰎇 {details}'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3, check=False)
    except (OSError, subprocess.TimeoutExpired):
        print('Could not display the music notification.', file=sys.stderr)


def notify_track(player, previous):
    deadline = time.monotonic() + 2
    latest = previous
    while time.monotonic() < deadline:
        track = read_track(player)
        if track and track[4].strip():
            latest = track
        if track and track[4].strip() and (previous is None or track[:5] != previous[:5]):
            show_notification(track)
            return
        time.sleep(0.1)
    show_notification(latest)


def advance(request, run):
    state = {}
    try:
        state = request('state', start=False)
        if state.get('path') and not state.get('paused', True):
            previous = read_track('y_music')
            request('next', start=False)
            notify_track('y_music', previous)
            return 0
    except (OSError, ConnectionError, RuntimeError):
        pass
    previous = read_track()
    player = previous[0] if previous else None
    command = ['playerctl'] + (['--player', player] if player else []) + ['next']
    result = run(command, check=False)
    if result.returncode and state.get('path'):
        try:
            previous = read_track('y_music')
            request('next', start=False)
            notify_track('y_music', previous)
            return 0
        except (OSError, ConnectionError, RuntimeError):
            pass
    if result.returncode == 0:
        notify_track(player, previous)
    return result.returncode


def main():
    backend = runpy.run_path(str(Path.home() / '.config/quickshell/scripts/player.py'))
    result = advance(backend['audio_request'], subprocess.run)
    return result


if __name__ == '__main__':
    sys.exit(main())
