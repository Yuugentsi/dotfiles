import fcntl
import glob
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time

FUNCTIONS = Path.home() / '.config/fish/functions'
STATE = Path.home() / '.local/state/fish-hub'

def expand_path(value):
    return Path(os.path.expandvars(os.path.expanduser(value)))

def discover_scripts(folder):

    scripts = {}
    for source in sorted(folder.glob('*.fish')):
        try:
            lines = source.read_text().splitlines()
        except OSError:
            continue
        for line in lines:
            if not line.startswith('function '):
                continue
            try:
                parts = shlex.split(line, comments=True)
            except ValueError:
                continue
            if len(parts) < 2:
                continue
            function = parts[1]
            if function.startswith('__') or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', function):
                continue
            description = ''
            for index, part in enumerate(parts[2:], 2):
                if part in ('--description', '-d') and index + 1 < len(parts):
                    description = parts[index + 1]
                elif part.startswith('--description='):
                    description = part.split('=', 1)[1]
            marker = re.search(r'\bscript:\s*(.*)', description, re.I)
            if not marker:
                continue
            metadata = {}
            if marker[1].startswith('{'):
                try:
                    metadata = json.loads(marker[1])
                except ValueError:
                    continue
                if not isinstance(metadata, dict):
                    continue
            label = metadata.get('label', function)
            entry = metadata.get('entry', function)
            if (not isinstance(label, str) or not isinstance(entry, str)
                    or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', entry)):
                continue
            metadata.update(function=function, source=source, entry=entry)
            scripts.setdefault(label, metadata)
    return scripts

TOOLS = discover_scripts(FUNCTIONS)

def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=False)

def unit_for(name):
    return 'local-fish-' + TOOLS[name]['function']

def shared_locks(name):
    return [expand_path(path) for path in TOOLS[name].get('locks', [])]

def locked(path):
    try:
        with path.open('r') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return True
    except OSError:
        pass
    return False

def running(name):
    active = run(['systemctl', '--user', 'is-active', '--quiet', unit_for(name)]).returncode == 0
    return active or any(locked(path) for path in shared_locks(name))

def memory_usage(name):
    result = run(['systemctl', '--user', 'show', unit_for(name),
                  '--property=MemoryCurrent', '--value'])
    try:
        value = int(result.stdout.strip())
        if result.returncode or value < 0 or value >= (1 << 64) - 1:
            return None
        return f'{value / (1024 * 1024):.1f} MiB'
    except ValueError:
        return None

def read_text(path):
    try:
        return path.read_text(errors='replace')
    except OSError:
        return ''

def process_alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False

def queue_paths(name):
    config = TOOLS[name]
    queues = []
    if config.get('session'):
        queues.append(expand_path(config['session']) / 'queue')
    for pattern in config.get('queues', []):
        for match in sorted(glob.glob(str(expand_path(pattern)))):
            folder = Path(match)
            pid = folder.name.rsplit('_', 1)[-1]
            if pid.isdecimal() and process_alive(pid):
                queues.append(folder / 'queue')
    return queues

def download_progress(name):
    config = TOOLS[name]
    queues = queue_paths(name)
    downloads = []
    waiting = 0
    for queue in queues:
        pending = sum(bool(line.strip()) for line in read_text(queue).splitlines())
        consumed = read_text(Path(str(queue) + '.consumed')).strip()
        waiting += max(0, pending - (int(consumed) if consumed.isdecimal() else 0))
        if config.get('queue_format') == 'slots':
            for slot in sorted((queue.parent / 'slots').glob('*')):
                parts = read_text(slot).splitlines()
                title = parts[0] if slot.name.isdecimal() and parts else slot.name
                detail = parts[1] if slot.name.isdecimal() and len(parts) > 1 else '\n'.join(parts)
                percent = re.fullmatch(r'\s*(\d+(?:\.\d+)?)%?\s*', detail)
                downloads.append({'title': title, 'phase': 'Downloading' if percent else 'Preparing',
                                  'percent': max(0, min(100, float(percent[1]))) if percent else None,
                                  'details': '' if percent else detail})
        for status in sorted(queue.parent.glob(queue.name + '.status.*')):
            pid = status.name.removeprefix(queue.name + '.status.')
            if not pid.isdecimal() or not process_alive(pid):
                continue
            line = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', read_text(status))
            line = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', line).strip()
            if not line or line[0] in '✓✗↻⚠':
                continue
            entry = {'title': '', 'phase': 'Preparing', 'percent': None, 'details': ''}
            match = re.match(r'([↓♫])\s*([0-9.]+)% · (.*?) · [━─·]+(?: · (.*))?$', line)
            if match:
                symbol, percent, title, details = match.groups()
                entry.update(title=title, phase='Converting' if symbol == '♫' else 'Downloading',
                             percent=max(0, min(100, float(percent))), details=details or '')
                entry['details'] = re.sub(r' · \d+ queued$', '', entry['details'])
            else:
                stages = {'◈': 'Adding cover', '◇': 'Adding metadata', '♫': 'Converting'}
                entry['phase'] = stages.get(line[0], 'Preparing')
                entry['title'] = line.split(' · ', 1)[-1].lstrip('◌ ')
            downloads.append(entry)
    return {'downloads': downloads, 'queued': waiting}

def notify(title, body):
    subprocess.run(["notify-send", "--app-name", "Hub", "-t", "3000", title, body],
                   check=False, capture_output=True)

def launch_command(name):
    config = TOOLS[name]
    values = [str(config['source']), config['entry']]
    code = ['source "$argv[1]"; or exit $status']
    for variable, value in config.get('variables', {}).items():
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', variable):
            raise ValueError('Invalid variable name')
        values.append(os.path.expandvars(os.path.expanduser(str(value))))
        code.append(f'set -g {variable} "$argv[{len(values)}]"')
    arguments = []
    for value in config.get('args', []):
        values.append(str(value))
        arguments.append(f'"$argv[{len(values)}]"')
    code.append('"$argv[2]"' + (' ' + ' '.join(arguments) if arguments else ''))
    command = ['fish', '--no-config', '-c', '; '.join(code)] + values
    if config.get('lock'):
        lock = expand_path(config['lock'])
        lock.parent.mkdir(parents=True, exist_ok=True)
        command = ['flock', '-n', str(lock)] + command
    return command

def start(name):
    if running(name):
        return 0
    source = TOOLS[name]['source']
    if not source.is_file():
        notify('Fish unavailable', str(source))
        return 1
    run(['systemctl', '--user', 'reset-failed', unit_for(name)])
    args = ['systemd-run', '--user', '--collect', '--quiet', '--unit', unit_for(name),
            '--description', f'Fish: {name}', '--property=KillMode=control-group',
            '--property=TimeoutStopSec=5', '--working-directory', str(Path.home())]
    for key in ('PATH', 'WAYLAND_DISPLAY', 'DISPLAY', 'XDG_RUNTIME_DIR',
                'DBUS_SESSION_BUS_ADDRESS', 'HYPRLAND_INSTANCE_SIGNATURE'):
        if key in os.environ:
            args += ['--setenv', f'{key}={os.environ[key]}']
    result = run(args + launch_command(name))
    notify('Fish started' if result.returncode == 0 else 'Failed to start Fish',
           name if result.returncode == 0 else result.stderr.strip())
    return result.returncode

def stop_tree(pid):

    if pid <= 1 or pid == os.getpid():
        return
    try:
        if Path(f'/proc/{pid}').stat().st_uid != os.getuid():
            return
        os.kill(pid, signal.SIGSTOP)
    except (ProcessLookupError, FileNotFoundError):
        return
    try:
        children = run(['pgrep', '-P', str(pid)]).stdout.split()
        for child in children:
            stop_tree(int(child))
        os.kill(pid, signal.SIGTERM)
    finally:
        try:
            os.kill(pid, signal.SIGCONT)
        except ProcessLookupError:
            pass

def stop(name):
    active = run(['systemctl', '--user', 'is-active', '--quiet', unit_for(name)]).returncode == 0
    result = run(['systemctl', '--user', 'stop', unit_for(name)]) if active else None
    if result and result.returncode:
        notify('Failed to stop Fish', result.stderr.strip())
        return result.returncode
    for path in shared_locks(name):
        if locked(path):
            for pid in run(['fuser', str(path)]).stdout.split():
                stop_tree(int(pid))
    notify('Fish stopped', name)
    return 0

def history_path(name):
    value = TOOLS[name].get('history')
    return expand_path(value) if value else None

def cutoff_path(name):
    return STATE / ('log-cleared-' + TOOLS[name]['function'])

def logs(name):
    history = history_path(name)
    if history and history.is_file():
        text = read_text(history)
    else:
        command = ['journalctl', '--user', '--unit', unit_for(name),
                   '--lines', '150', '--no-pager', '--output', 'cat']
        cutoff = read_text(cutoff_path(name)).strip()
        if re.fullmatch(r'\d+(\.\d+)?', cutoff):
            command += ['--since', '@' + cutoff]
        text = run(command).stdout
    if TOOLS[name].get('queue_format') == 'slots':
        cutoff = read_text(cutoff_path(name)).strip()
        since = float(cutoff) if re.fullmatch(r'\d+(\.\d+)?', cutoff) else 0
        records = []
        for queue in queue_paths(name):
            for path in queue.parent.glob('*.log'):
                try:
                    modified = path.stat().st_mtime
                except OSError:
                    continue
                if modified > since:
                    records.append((modified, read_text(path)))
        text += '\n' + '\n'.join(value for _, value in sorted(records))
    data = activity(text)
    data['name'] = name
    print(json.dumps(data))
    return 0

def clear_logs(name):
    STATE.mkdir(parents=True, exist_ok=True)
    cutoff_path(name).write_text(str(time.time()))
    history = history_path(name)
    if history:
        history.parent.mkdir(parents=True, exist_ok=True)
        history.write_text('')
    return 0

def activity(text):
    entries = []
    counts = {'downloaded': 0, 'skipped': 0, 'error': 0, 'warning': 0, 'info': 0}
    labels = {'downloaded': 'Downloaded', 'skipped': 'Already downloaded',
              'error': 'Failed', 'warning': 'Warning', 'info': 'Activity'}
    text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
    for raw in text.splitlines():
        line = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', raw).strip()
        if not line or line.startswith('-- '):
            continue
        kind = {'✓': 'downloaded', '↻': 'skipped', '✗': 'error', '⚠': 'warning'}.get(line[0], 'info')
        title = line[1:].strip() if kind != 'info' else line
        detail = ''
        if kind == 'info' and re.match(r'ERROR:|.*\bfailed\b', line, re.I):
            kind = 'error'
        elif kind == 'info' and line.startswith('WARNING:'):
            kind = 'warning'
        if kind == 'error':
            match = re.match(r'(.*?) · (https?://\S+)$', title)
            if match:
                detail, url = match.groups()
                title = url
            else:
                detail = title
                title = 'Download failed'
        elif kind == 'skipped':
            detail = 'This item is already in your library.'
        counts[kind] += 1
        entries.append({'kind': kind, 'label': labels[kind], 'title': title, 'detail': detail})
    return {'entries': list(reversed(entries[-100:])), 'counts': counts}

def main(args):
    if args == ['list']:
        items = []
        for name, config in TOOLS.items():
            active = running(name)
            item = {'name': name, 'running': active,
                    'memory': memory_usage(name) if active else None}
            if active and (config.get('session') or config.get('queues')):
                item.update(download_progress(name))
            items.append(item)
        print(json.dumps(items))
        return 0
    if len(args) == 2 and args[1] in TOOLS:
        action = {'start': start, 'stop': stop, 'logs': logs, 'clear-logs': clear_logs}.get(args[0])
        if action:
            return action(args[1])
    return 2

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
