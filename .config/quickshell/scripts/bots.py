from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

BASE = Path.home() / "0/bots"
VENV = Path.home() / ".venv"


def unit_for(name):
    return "local-bot-" + hashlib.sha256(name.encode()).hexdigest()[:16]


def entry_for(folder):
    return next((name for name in ("main.py", "bot.py") if (folder / name).is_file()), None)


def running(name):
    return subprocess.run(["systemctl", "--user", "is-active", "--quiet", unit_for(name)],
                          check=False).returncode == 0


def memory_usage(name):
    result = subprocess.run(
        ["systemctl", "--user", "show", unit_for(name), "--property=MemoryCurrent", "--value"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        return None
    try:
        value = int(result.stdout.strip())
    except ValueError:
        return None
    if value < 0 or value >= (1 << 64) - 1:
        return None
    if value < 1024 * 1024:
        return f"{value / 1024:.0f} KiB"
    return f"{value / (1024 * 1024):.1f} MiB"


def list_bots():
    result = []
    if BASE.is_dir():
        for folder in sorted(BASE.iterdir(), key=lambda p: p.name.casefold()):
            if not folder.is_dir() or folder.name.startswith(".") or folder.resolve().parent != BASE.resolve():
                continue
            entry = entry_for(folder)
            if entry:
                active = running(folder.name)
                result.append({
                    "name": folder.name,
                    "entry": entry,
                    "running": active,
                    "memory": memory_usage(folder.name) if active else None,
                    "last_log": latest_log(folder.name),
                })
    return result


def latest_log(name):
    try:
        result = subprocess.run(
            ["journalctl", "--user", "--unit", unit_for(name), "_TRANSPORT=stdout",
             "--lines", "1", "--no-pager", "--output", "json"],
            capture_output=True, text=True, check=False, timeout=3,
        )
        if result.returncode or not result.stdout.strip():
            return ""
        message = json.loads(result.stdout.splitlines()[-1]).get("MESSAGE", "")
        return message[-2000:] if isinstance(message, str) else ""
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return ""


def activity(name):
    if not name or Path(name).name != name or name in (".", ".."):
        raise ValueError("Invalid bot name")
    folder = BASE / name
    if not folder.is_dir() or folder.resolve().parent != BASE.resolve():
        raise ValueError("Bot not found")
    result = subprocess.run(
        ["journalctl", "--user", "--unit", unit_for(name), "_TRANSPORT=stdout",
         "--lines", "100", "--no-pager", "--output", "json"],
        capture_output=True, text=True, check=False, timeout=3,
    )
    if result.returncode:
        raise RuntimeError("Could not read bot logs")
    entries = []
    counts = {"info": 0, "warning": 0, "error": 0}
    for line in result.stdout.splitlines():
        try:
            row = json.loads(line)
            if not isinstance(row, dict):
                continue
            message = row.get("MESSAGE", "")
            if not isinstance(message, str) or not message.strip():
                continue
            priority = int(row.get("PRIORITY", 6))
            kind = "error" if priority <= 3 else "warning" if priority == 4 else "info"
            timestamp = datetime.fromtimestamp(int(row.get("__REALTIME_TIMESTAMP", 0)) / 1000000).strftime("%H:%M:%S")
        except (ValueError, TypeError, OverflowError, OSError):
            continue
        counts[kind] += 1
        entries.append({"kind": kind, "title": message[-4000:], "detail": "", "label": timestamp})
    return {"name": name, "entries": entries[::-1], "counts": counts}


def notify(title, body):
    subprocess.run(["notify-send", "--app-name", "Hub", "-t", "3000", title, body],
                   check=False, capture_output=True)


def prepare_environment(folder):
    lock = Path.home() / ".local/state/fish-hub/python-environment.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        python = VENV / "bin/python"
        if not python.is_file():
            notify("Preparing Python environment", "Creating ~/.venv")
            subprocess.run([sys.executable, "-m", "venv", str(VENV)],
                           cwd=folder, capture_output=True, text=True, check=True)
        requirements = folder / "requirements.txt"
        if requirements.is_file():
            notify("Preparing Python environment", f"Installing dependencies for {folder.name}")
            pip = subprocess.run([str(python), "-m", "pip", "--version"],
                                 capture_output=True, text=True, check=False)
            if pip.returncode:
                subprocess.run([str(python), "-m", "ensurepip", "--upgrade"],
                               cwd=folder, capture_output=True, text=True, check=True)
            subprocess.run([str(python), "-m", "pip", "install", "-r", str(requirements)],
                           cwd=folder, capture_output=True, text=True, check=True)


def start(name):
    if not name or Path(name).name != name or name in (".", ".."):
        return 2
    folder = BASE / name
    if not folder.is_dir() or folder.resolve().parent != BASE.resolve():
        return 2
    entry = entry_for(folder)
    python = VENV / "bin/python"
    if not entry:
        notify("Bot unavailable", "Missing main.py or bot.py")
        return 1
    if running(name):
        notify("Bot already running", name)
        return 0
    try:
        prepare_environment(folder)
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or str(error)).strip()
        print(detail, file=sys.stderr)
        notify("Python environment setup failed", detail[-1500:])
        return 1
    except OSError as error:
        notify("Python environment setup failed", str(error))
        return 1
    unit = unit_for(name)
    subprocess.run(["systemctl", "--user", "reset-failed", unit],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    result = subprocess.run(
        ["systemd-run", "--user", "--collect", "--quiet", "--unit", unit,
         "--description", f"Local bot: {name}", "--working-directory", str(folder),
         "--setenv", f"VIRTUAL_ENV={VENV}",
         "--setenv", f"PATH={VENV / 'bin'}:{os.environ.get('PATH', '/usr/bin')}",
         "--setenv", "PYTHONUNBUFFERED=1", str(python), entry],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        notify("Bot failed to start", result.stderr.strip() or name)
    else:
        notify("Bot launched", f"{name} · {entry}")
    return result.returncode


def stop(name):
    if not name or Path(name).name != name or name in (".", ".."):
        return 2
    result = subprocess.run(
        ["systemctl", "--user", "stop", unit_for(name)],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        notify("Bot failed to stop", result.stderr.strip() or name)
    else:
        notify("Bot stopped", name)
    return result.returncode


def logs(name):
    if not name or Path(name).name != name or name in (".", ".."):
        return 2
    folder = BASE / name
    if not folder.is_dir() or folder.resolve().parent != BASE.resolve():
        return 2
    subprocess.Popen(
        ["kitty", "--title", f"Bot logs · {name}", "--hold",
         "journalctl", "--user", "--unit", unit_for(name),
         "--follow", "--lines", "100", "--no-pager", "--output", "cat"],
        start_new_session=True,
    )
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["list"]:
        print(json.dumps(list_bots()))
    elif len(sys.argv) == 3 and sys.argv[1] == "start":
        sys.exit(start(sys.argv[2]))
    elif len(sys.argv) == 3 and sys.argv[1] == "stop":
        sys.exit(stop(sys.argv[2]))
    elif len(sys.argv) == 3 and sys.argv[1] == "activity":
        try:
            print(json.dumps(activity(sys.argv[2])))
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            print(json.dumps({"name": sys.argv[2], "entries": [{"kind": "error", "title": "Could not read bot logs", "detail": "", "label": "Error"}], "counts": {"error": 1}}))
    elif len(sys.argv) == 3 and sys.argv[1] == "logs":
        sys.exit(logs(sys.argv[2]))
    else:
        sys.exit(2)
