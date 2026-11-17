import re
import subprocess
import sys

action, address = sys.argv[1:]
if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', address):
    sys.exit(2)
commands = {'connect': ['connect'], 'disconnect': ['disconnect'],
            'pair': ['pair', 'trust', 'connect'], 'forget': ['disconnect', 'remove']}
if action not in commands:
    sys.exit(2)
for command in commands[action]:
    result = subprocess.run(['bluetoothctl', '--timeout', '30', command, address],
                            capture_output=True, text=True, timeout=35)
    if result.returncode and not (action == 'forget' and command == 'disconnect'):
        subprocess.run(['notify-send', '--app-name', 'Bluetooth', 'Bluetooth action failed',
                        result.stderr.strip() or result.stdout.strip()], check=False)
        sys.exit(1)
