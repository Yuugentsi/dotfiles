import json
import os
import re
import sys
import time
from pathlib import Path

LOGS = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/hub/ytdlp"
NOISE = ("YTDLP_PROGRESS:", "YTDLP_DURATION:", "YTDLP_DONE:")
ITEM = re.compile(r"^\[download\] Downloading item (\d+) of (\d+)")
PLAYLIST = re.compile(r"^\[download\] Downloading playlist: (.+)$")


def alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, TypeError, ValueError):
        return False


def read_lines(path):
    try:
        return Path(path).read_text(errors="replace").splitlines()
    except OSError:
        return []


def tail(lines, count=40):
    lines = [line for line in lines if line.strip() and not line.startswith(NOISE)]
    return lines[-count:]


def playlist_info(lines):
    info = {}
    failed = 0
    for line in lines:
        match = ITEM.match(line)
        if match:
            info["item"] = int(match.group(1))
            info["total"] = int(match.group(2))
            continue
        match = PLAYLIST.match(line)
        if match:
            info["playlistTitle"] = match.group(1).strip()
            continue
        if line.startswith("ERROR:"):
            failed += 1
    info["failedItems"] = failed
    return info


def collect(limit):
    items = []
    for path in sorted(LOGS.glob("download-*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]:
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        if data.get("status") not in ("done", "failed") and not alive(data.get("pid")):
            data["status"] = "failed"
        data["id"] = path.stem
        data["running"] = data.get("status") not in ("done", "failed")
        lines = read_lines(data.get("log", ""))
        data["lines"] = tail(lines)
        if data.get("playlist"):
            data.update(playlist_info(lines))
        items.append(data)
    return items


def clear():
    for path in LOGS.glob("download-*.json"):
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        if data.get("status") in ("done", "failed") or not alive(data.get("pid")):
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "clear":
        clear()
    else:
        print(json.dumps({"now": time.time(), "items": collect(12)}))
