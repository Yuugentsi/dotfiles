import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import time

BACKLIGHT = Path('/sys/class/backlight')


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=4, check=False)
    if result.returncode:
        raise RuntimeError('Could not communicate with display controls.')
    return result.stdout.strip()


def backlight():
    if not BACKLIGHT.is_dir():
        return "", 0, 0
    for device in sorted(BACKLIGHT.iterdir()):
        try:
            maximum = int((device / 'max_brightness').read_text())
            actual = int((device / 'actual_brightness').read_text())
            if maximum > 0:
                return device.name, maximum, round(actual / maximum * 100)
        except (OSError, ValueError):
            continue
    return '', 0, 0


def sunset_state():
    temperature = int(run(['hyprctl', 'hyprsunset', 'temperature']))
    gamma = float(run(['hyprctl', 'hyprsunset', 'gamma']))
    identity = run(['hyprctl', 'hyprsunset', 'identity', 'get'])
    if identity not in ('true', 'false') or not math.isfinite(gamma):
        raise ValueError('Invalid display state')
    return temperature, gamma, identity == 'false'


def snapshot():
    device, maximum, brightness = backlight()
    state = {'device': device, 'brightnessAvailable': bool(maximum), 'brightness': brightness,
             'sunsetAvailable': bool(shutil.which('hyprsunset')), 'sunsetRunning': False,
             'temperature': 2700, 'gamma': 100, 'nightEnabled': False}
    try:
        temperature, gamma, enabled = sunset_state()
        state.update(temperature=temperature, gamma=gamma, nightEnabled=enabled, sunsetRunning=True)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        pass
    return state


def ensure_sunset():
    try:
        sunset_state()
        return
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        pass
    if not shutil.which('hyprsunset'):
        raise RuntimeError('Hyprsunset is not installed.')
    subprocess.Popen(['hyprsunset', '--identity', '-t', '2700', '-g', '100'],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    for attempt in range(15):
        time.sleep(0.1)
        try:
            sunset_state()
            return
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            continue
    raise RuntimeError('Hyprsunset did not become available.')


def number(value, minimum, maximum):
    if isinstance(value, bool):
        raise ValueError('Invalid display value.')
    value = float(value)
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError('Display value is outside the supported range.')
    return round(value)


def perform(request):
    action = request.get('action', 'state')
    if action == 'brightness':
        value = number(request.get('value'), 10, 100)
        device, maximum, current = backlight()
        if not device:
            raise RuntimeError('No display backlight is available.')
        if shutil.which('brightnessctl'):
            run(['brightnessctl', '--device', device, 'set', f'{value}%'])
        else:
            run(['busctl', '--system', 'call', 'org.freedesktop.login1',
                 '/org/freedesktop/login1/session/auto', 'org.freedesktop.login1.Session',
                 'SetBrightness', 'ssu', 'backlight', device, str(max(1, round(maximum * value / 100)))])
    elif action in ('temperature', 'gamma', 'night'):
        if action == 'night':
            if not isinstance(request.get('value'), bool):
                raise ValueError('Invalid night light state.')
            arguments = ['identity', 'false' if request['value'] else 'true']
        else:
            value = number(request.get('value'), 1000 if action == 'temperature' else 30,
                           2700 if action == 'temperature' else 100)
            arguments = [action, str(value)]
        ensure_sunset()
        if run(['hyprctl', 'hyprsunset', *arguments]).lower() != 'ok':
            raise RuntimeError('Hyprsunset could not apply the setting.')
    elif action != 'state':
        raise ValueError('Unknown display action.')
    return {'ok': True, 'state': snapshot()}


if __name__ == '__main__':
    try:
        print(json.dumps(perform(json.loads(sys.stdin.readline()))))
    except (OSError, ValueError, TypeError, RuntimeError, subprocess.TimeoutExpired) as error:
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else 'Could not update display controls.'
        print(json.dumps({'ok': False, 'error': message}))
