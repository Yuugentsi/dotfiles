import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

CONFIG = Path.home() / '.config/hypr/lua/monitors.lua'
RULE = re.compile(r'^(?!\s*--)[ \t]*hl\.monitor\s*\(\s*\{([^{}]*?)\}\s*\)', re.MULTILINE)
VALUE = r'("[^"\\\n]*"|\x27[^\x27\\\n]*\x27|[0-9]+(?:\.[0-9]+)?)'


def command(arguments, source=None):
    result = subprocess.run(arguments, input=source, capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise RuntimeError('Could not communicate with Hyprland or validate the configuration.')
    return result.stdout.strip()


def field_pattern(name):
    return re.compile(r'\b' + name + r'\s*=\s*' + VALUE)


def rules(source):
    result = []
    for match in RULE.finditer(source):
        values = {}
        for name in ('output', 'mode', 'position', 'scale'):
            fields = list(field_pattern(name).finditer(match.group(1)))
            if len(fields) != 1:
                break
            raw = fields[0].group(1)
            values[name] = raw[1:-1] if raw[0] in ('"', "'") else float(raw)
        else:
            result.append((match, values))
    return result


def compatible_scales(mode, monitor=None):
    dimensions = re.match(r'^(\d+)x(\d+)', mode)
    if dimensions:
        width, height = map(int, dimensions.groups())
    else:
        monitor = monitor or {}
        width, height = monitor.get('width', 0), monitor.get('height', 0)
    if not width or not height:
        return [1.0]
    return [step / 120 for step in range(120, 241)
            if width * 120 % step == 0 and height * 120 % step == 0
            and (width / (step / 120)).is_integer()
            and (height / (step / 120)).is_integer()]


def selected_monitor(monitors, output):
    return next((monitor for monitor in monitors if not output or monitor.get('name') == output), {})


def preset_path():
    return Path.home() / '.local/state/quickshell/hypr-monitor-presets.json'


def presets(source, output):
    commented = '\n'.join(re.sub(r'^[ \t]*--[ \t]*', '', line) for line in source.splitlines()
                          if re.match(r'^[ \t]*--[ \t]*hl\.monitor', line))
    candidates = [value for match, value in rules(commented)]
    try:
        saved = json.loads(preset_path().read_text())
        if isinstance(saved, list):
            candidates.extend(saved)
    except (OSError, ValueError):
        pass
    candidates.extend(value for match, value in rules(source))
    result = {}
    for candidate in candidates:
        try:
            value = dict(validated_values(candidate), output=candidate.get('output', ''))
        except (ValueError, TypeError, AttributeError):
            continue
        if value['output'] != output:
            continue
        resolution = value['mode'].split('@')[0]
        if resolution not in result:
            result[resolution] = value
        else:
            existing = result[resolution]
            if existing['scale'] != round(existing['scale'], 2) and value['scale'] == round(value['scale'], 2) and abs(existing['scale'] - value['scale']) < 0.005:
                result[resolution] = value
    def order(value):
        resolution = value['mode'].split('@')[0]
        automatic = {'preferred': 0, 'highres': 1, 'highrr': 2}
        if resolution in automatic:
            return automatic[resolution], 0, 0
        width, height = map(int, resolution.split('x'))
        return 3, width * height, width
    return sorted(result.values(), key=order)


def remember_presets(source, output):
    path = preset_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(presets(source, output), indent=2) + '\n')


def config_errors():
    response = command(['hyprctl', '-j', 'configerrors'])
    try:
        errors = json.loads(response or '[]')
    except ValueError:
        raise RuntimeError('Hyprland returned an invalid configuration error list.') from None
    if not isinstance(errors, list):
        raise RuntimeError('Hyprland returned an invalid configuration error list.')
    return [error for error in errors if str(error).strip()]


def runtime_rule(monitor, value):
    output = monitor.get('name', '')
    if not re.fullmatch(r'[A-Za-z0-9_.:-]+', output):
        raise RuntimeError('No active monitor is available.')
    return dict(value, output=output, transform=int(monitor.get('transform', 0)))


def apply_runtime(rule):
    fields = ', '.join(f'{key} = {json.dumps(value)}' for key, value in rule.items())
    if command(['hyprctl', 'eval', 'hl.monitor({ ' + fields + ' })']).lower() != 'ok':
        raise RuntimeError('Hyprland rejected the display change.')


def active_mode(monitor):
    return f"{monitor['width']}x{monitor['height']}@{monitor['refreshRate']}"


def wait_for_monitor(rule):
    dimensions = re.match(r'^(\d+)x(\d+)', rule['mode'])
    expected_size = tuple(map(int, dimensions.groups())) if dimensions else None
    rate = re.search(r'@([0-9.]+)$', rule['mode'])
    expected_rate = float(rate[1]) if rate else None
    for attempt in range(15):
        monitor = selected_monitor(json.loads(command(['hyprctl', '-j', 'monitors'])), rule['output'])
        if monitor and abs(float(monitor.get('scale', 0)) - rule['scale']) < 0.001:
            size_matches = expected_size is None or (monitor.get('width'), monitor.get('height')) == expected_size
            rate_matches = expected_rate is None or abs(float(monitor.get('refreshRate', 0)) - expected_rate) < 0.5
            if size_matches and rate_matches:
                return monitor
        time.sleep(0.1)
    raise RuntimeError('Hyprland did not activate the requested display settings.')


def snapshot():
    source = CONFIG.read_text()
    entries = rules(source)
    if not entries:
        raise ValueError('No simple rule with output, mode, position and scale was found in monitors.lua.')
    monitors = []
    try:
        monitors = json.loads(command(['hyprctl', '-j', 'monitors']))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        pass
    first_rule = entries[0][1]
    monitor = selected_monitor(monitors, first_rule['output'])
    return {'revision': hashlib.sha256(source.encode()).hexdigest(),
            'rules': [value for match, value in entries], 'monitors': monitors,
            'presets': presets(source, first_rule['output']),
            'validScales': compatible_scales(first_rule['mode'], monitor)}


def validated_values(value):
    mode = str(value.get('mode', '')).strip()
    position = str(value.get('position', '')).strip()
    if not re.fullmatch(r'(preferred|highres|highrr|[1-9]\d{2,4}x[1-9]\d{2,4}(?:@[1-9]\d{0,3}(?:\.\d{1,3})?)?)', mode):
        raise ValueError('Use a resolution such as 1920x1080@60 or preferred.')
    if not re.fullmatch(r'(auto(?:-(?:left|right|up|down))?|[+-]?\d{1,6}x[+-]?\d{1,6})', position):
        raise ValueError('Use a position such as auto or 0x0.')
    scale = value.get('scale')
    if isinstance(scale, bool):
        raise ValueError('Invalid scale.')
    scale = float(scale)
    if not math.isfinite(scale) or not 1 <= scale <= 2:
        raise ValueError('Scale must be between 1 and 2.')
    return {'mode': mode, 'position': position, 'scale': scale}


def replace_rule(source, index, value):
    entries = rules(source)
    if type(index) is not int or not 0 <= index < len(entries):
        raise ValueError('Select a valid monitor rule.')
    match, previous = entries[index]
    body = match.group(1)
    for name, item in validated_values(value).items():
        field = field_pattern(name).search(body)
        literal = json.dumps(item, ensure_ascii=False)
        body = body[:field.start(1)] + literal + body[field.end(1):]
    return source[:match.start(1)] + body + source[match.end(1):]


def write_config(source):
    descriptor, temporary = tempfile.mkstemp(prefix='.monitors-', dir=CONFIG.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(source)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, CONFIG.stat().st_mode & 0o777)
        os.replace(temporary, CONFIG)
    finally:
        Path(temporary).unlink(missing_ok=True)


def perform(request):
    action = request.get('action', 'monitors.state')
    if action == 'monitors.apply':
        source = CONFIG.read_text()
        if request.get('revision') != hashlib.sha256(source.encode()).hexdigest():
            raise ValueError('monitors.lua changed. Click Reload before applying.')
        index = request.get('index')
        entries = rules(source)
        if type(index) is not int or not 0 <= index < len(entries):
            raise ValueError('Select a valid monitor rule.')
        previous = entries[index][1]
        value = validated_values(request.get('value', {}))
        monitors = json.loads(command(['hyprctl', '-j', 'monitors']))
        monitor = selected_monitor(monitors, previous['output'])
        live_value = dict(value)
        if request.get('preserveMode', True) and value['mode'] == previous['mode'] and monitor:
            live_value['mode'] = active_mode(monitor)
            value['mode'] = live_value['mode']
        scales = compatible_scales(live_value['mode'])
        value['scale'] = min(scales, key=lambda scale: abs(scale - value['scale']))
        live_value['scale'] = value['scale']
        live_rule = runtime_rule(monitor, live_value)
        original_rule = runtime_rule(monitor, dict(mode=active_mode(monitor), scale=monitor['scale'],
                                                  position=f"{monitor.get('x', 0)}x{monitor.get('y', 0)}"))
        updated = replace_rule(source, index, value)
        command(['lua', '-e', "local fn, err = load(io.read('*a')); if not fn then io.stderr:write(err); os.exit(1) end"], updated)
        backup_dir = Path.home() / '.local/state/quickshell/monitor-backups'
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / (hashlib.sha256(source.encode()).hexdigest() + '.lua')
        if not backup.exists():
            backup.write_text(source)
        if CONFIG.read_text() != source:
            raise ValueError('monitors.lua changed. Click Reload before applying.')
        remember_presets(source, previous['output'])
        written = False
        try:
            apply_runtime(live_rule)
            wait_for_monitor(live_rule)
            if CONFIG.read_text() != source:
                raise RuntimeError('monitors.lua changed while applying. Reload display settings.')
            write_config(updated)
            written = True
            if config_errors():
                raise RuntimeError('Hyprland reported configuration errors. The change was reverted.')
            wait_for_monitor(live_rule)
        except (OSError, ValueError, TypeError, RuntimeError, subprocess.TimeoutExpired):
            if written and CONFIG.read_text() == updated:
                write_config(source)
            try:
                apply_runtime(original_rule)
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                pass
            raise
    elif action != 'monitors.state':
        raise ValueError('Unknown action.')
    return {'ok': True, 'state': snapshot()}


if __name__ == '__main__':
    try:
        print(json.dumps(perform(json.loads(sys.stdin.readline())), ensure_ascii=False))
    except (OSError, ValueError, TypeError, RuntimeError, subprocess.TimeoutExpired) as error:
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else 'Could not update monitors.'
        print(json.dumps({'ok': False, 'error': message}, ensure_ascii=False))
