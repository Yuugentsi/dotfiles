import json
import subprocess

result = subprocess.run(['pactl', '-f', 'json', 'info'], capture_output=True, text=True)
if result.returncode == 0:
    print(json.loads(result.stdout).get('default_sink_name', ''))
