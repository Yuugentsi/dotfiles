import os
import re
import json
import math
import queue
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import shlex
from html import escape
from urllib.parse import urlsplit, parse_qs, urlencode

def notify(title, message, notification_id=0, persistent=False, glyph=None):
    result = subprocess.run(
        ["notify-send", "--app-name", "yt-dlp", "-p", "-r", str(notification_id),
         "-t", "0" if persistent else "6000", title, message],
        capture_output=True, text=True, check=False,
    )
    value = result.stdout.strip()
    return int(value) if value.isdigit() else notification_id

def close_notification_after(notification_id, seconds=1.5):
    if notification_id <= 0:
        return

    subprocess.Popen(
        [sys.executable, "-c",
         "import subprocess,sys,time; time.sleep(float(sys.argv[2])); "
         "subprocess.run(['busctl','--user','call','org.freedesktop.Notifications',"
         "'/org/freedesktop/Notifications','org.freedesktop.Notifications',"
         "'CloseNotification','u',sys.argv[1]],check=False)",
         str(notification_id), str(seconds)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

def progress_layout(percent, details):
    details = "   ·   ".join(escape(value) for value in details if value)
    if percent is None:
        return details or "…"
    percent = max(0, min(100, percent))
    filled = int(percent * 16 / 100)
    bar = "━" * filled + "─" * (16 - filled)
    return f"<b>{percent:.0f}%</b>  {bar}" + (f"\n{details}" if details else "")

def progress_message(line):
    if not line.startswith("YTDLP_PROGRESS:"):
        return None
    try:
        data = json.loads(line.removeprefix("YTDLP_PROGRESS:"))
    except (ValueError, TypeError):
        return None
    if not isinstance(data, dict):
        return None
    if data.get("status") == "finished":
        return "…"
    try:
        percent = float(str(data.get("_percent_str", "")).strip().removesuffix("%"))
        if not math.isfinite(percent):
            percent = None
    except ValueError:
        percent = None
    speed = str(data.get("_speed_str", "")).strip()
    eta = str(data.get("_eta_str", "")).strip()
    return progress_layout(percent, [speed if "Unknown" not in speed else "",
                                   f"◷ {eta}" if eta and "Unknown" not in eta else ""])

def conversion_message(text, duration):

    record = {}
    latest = None
    for line in text.splitlines():
        key, separator, value = line.partition("=")
        if not separator:
            continue
        record[key] = value.strip()
        if key == "progress":
            latest = record
            record = {}
    if not latest:
        return None
    try:
        seconds = max(0, float(latest["out_time_us"]) / 1_000_000)
    except (KeyError, ValueError):
        return None
    speed = latest.get("speed", "N/A")
    parts = []
    percent = None
    if duration and duration > 0:
        percent = 100 if latest.get("progress") == "end" else min(99, math.floor(seconds / duration * 100))
    else:
        parts.append(f"◷ {int(seconds)}s")
    if speed != "N/A":
        parts.append(speed)
    try:
        rate = float(speed.removesuffix("x"))
        if duration and duration > 0 and rate > 0:
            eta = math.ceil(max(0, duration - seconds) / rate)
            parts.append(f"◷ {eta // 60:02d}:{eta % 60:02d}")
    except ValueError:
        pass
    return progress_layout(percent, parts)

class Status:
    def __init__(self, path, **fields):
        self.path = Path(path)
        self.data = {"pid": os.getpid(), "started": time.time(), "status": "starting", "percent": None,
                     "speed": "", "eta": "", "title": ""}
        self.update(**fields)

    def update(self, **fields):
        self.data.update(fields)
        self.data["updated"] = time.time()
        temp = self.path.with_suffix(".tmp")
        try:
            temp.write_text(json.dumps(self.data))
            temp.replace(self.path)
        except OSError:
            pass

def progress_fields(line):
    try:
        data = json.loads(line.removeprefix("YTDLP_PROGRESS:"))
    except (ValueError, TypeError):
        return {}
    if not isinstance(data, dict):
        return {}
    fields = {}
    filename = data.get("filename") or data.get("tmpfilename")
    if filename:
        name = Path(filename).name
        match = re.match(r"^(.*) \[[^\]]+\]", name)
        fields["title"] = match.group(1) if match else name.rsplit(".", 1)[0]
    if data.get("status") == "finished":
        fields.update(status="processing", phase="Processing", percent=100, speed="", eta="")
        return fields
    try:
        percent = float(str(data.get("_percent_str", "")).strip().removesuffix("%"))
        fields["percent"] = percent if math.isfinite(percent) else None
    except ValueError:
        pass
    speed = str(data.get("_speed_str", "")).strip()
    eta = str(data.get("_eta_str", "")).strip()
    fields.update(status="downloading", phase="Downloading", speed="" if "Unknown" in speed else speed, eta="" if "Unknown" in eta else eta)
    return fields

def conversion_fields(text, duration):
    record = {}
    latest = None
    for line in text.splitlines():
        key, separator, value = line.partition("=")
        if not separator:
            continue
        record[key] = value.strip()
        if key == "progress":
            latest = record
            record = {}
    if not latest:
        return None
    try:
        seconds = max(0, float(latest["out_time_us"]) / 1_000_000)
    except (KeyError, ValueError):
        return None
    fields = {"status": "converting", "phase": "Converting", "percent": None, "speed": "", "eta": ""}
    speed = latest.get("speed", "N/A")
    if speed != "N/A":
        fields["speed"] = speed.strip()
    if duration and duration > 0:
        fields["percent"] = 100.0 if latest.get("progress") == "end" else min(99.9, seconds / duration * 100)
        try:
            rate = float(speed.removesuffix("x"))
            if rate > 0:
                eta = math.ceil(max(0, duration - seconds) / rate)
                fields["eta"] = f"{eta // 60:02d}:{eta % 60:02d}"
        except ValueError:
            pass
    else:
        fields["eta"] = f"{int(seconds)}s"
    return fields

STAGES = {
    "[ExtractAudio]": ("converting", "Converting"),
    "[Merger]": ("converting", "Merging"),
    "[VideoRemuxer]": ("converting", "Remuxing"),
    "[EmbedThumbnail]": ("processing", "Adding cover"),
    "[ThumbnailsConvertor]": ("processing", "Preparing cover"),
    "[Metadata]": ("processing", "Adding metadata"),
    "[MetadataParser]": ("processing", "Adding metadata"),
}

def output_lines(stream, lines):
    try:
        for line in stream:
            lines.put(line)
    finally:
        lines.put(None)

def monitor_download(process, progress_path, log, mode, notification_id, status, history_path=None):
    lines = queue.Queue()
    reader = threading.Thread(target=output_lines, args=(process.stdout, lines), daemon=True)
    reader.start()
    duration = None
    previous = None
    last_conversion_update = 0
    last_status_update = 0
    finished = False
    while not finished:
        try:
            line = lines.get(timeout=0.25)
        except queue.Empty:
            line = ""
        if line is None:
            finished = True
        elif line:
            log.write(line)
            log.flush()
            if line.startswith("YTDLP_DURATION:"):
                try:
                    value = float(line.removeprefix("YTDLP_DURATION:").strip())
                    duration = value if math.isfinite(value) and value > 0 else None
                except ValueError:
                    duration = None
            if line.startswith("YTDLP_DONE:"):
                title, _, rest = line.removeprefix("YTDLP_DONE:").rstrip("\n").rpartition("|")
                title, _, page = title.rpartition("|")
                if history_path:
                    record_history(history_path, title, page, rest)
                status.update(done=status.data.get("done", 0) + 1, title=title)
            elif line.startswith("YTDLP_PROGRESS:"):
                fields = progress_fields(line)
                if fields:
                    status.update(**fields)
            else:
                stage = STAGES.get(line.split(" ", 1)[0])
                if stage and status.data.get("phase") != stage[1]:
                    status.update(status=stage[0], phase=stage[1], percent=None, speed="", eta="")
            message = progress_message(line)
            if duration is None and line.startswith("YTDLP_PROGRESS:"):
                try:
                    data = json.loads(line.removeprefix("YTDLP_PROGRESS:"))
                    filename = data.get("filename")
                    if data.get("status") == "finished" and filename and shutil.which("ffprobe"):
                        probe = subprocess.run(
                            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                             "-of", "default=noprint_wrappers=1:nokey=1", filename],
                            capture_output=True, text=True, timeout=10, check=False,
                        )
                        value = float(probe.stdout.strip())
                        if math.isfinite(value) and value > 0:
                            duration = value
                except (ValueError, TypeError, AttributeError, subprocess.TimeoutExpired):
                    pass
            if message and message != previous:
                notification_id = notify("yt-dlp", message, notification_id, persistent=True, glyph="◌" if message == "…" else "↓")
                previous = message

        now = time.monotonic()
        if status.data.get("status") == "converting" and now - last_status_update >= 0.4:
            last_status_update = now
            try:
                fields = conversion_fields(progress_path.read_text(errors="replace"), duration)
            except FileNotFoundError:
                fields = None
            if fields:
                fields["phase"] = status.data.get("phase") or "Converting"
                status.update(**fields)
        if finished or now - last_conversion_update >= 1:
            try:
                message = conversion_message(progress_path.read_text(errors="replace"), duration)
            except FileNotFoundError:
                message = None
            if message and message != previous:
                notification_id = notify("yt-dlp", message, notification_id, persistent=True, glyph="◌")
                previous = message
                last_conversion_update = now
    reader.join()
    return process.wait(), notification_id

VIDEO_ID = re.compile(r"(?:v=|youtu\.be/|shorts/)([A-Za-z0-9_-]{11})")


def cookie_flags():
    home = Path.home()
    if (home / ".config/mozilla/firefox").is_dir() or (home / ".mozilla/firefox").is_dir():
        return ["--cookies-from-browser", "firefox"]
    return []


def read_history(path):
    history = {}
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return history
    for index, line in enumerate(lines):
        match = VIDEO_ID.search(line)
        if match and line.startswith("http"):
            history[match.group(1)] = lines[index - 1] if index > 0 else match.group(1)
    return history


def record_history(path, title, url, identifier):
    if not url and identifier:
        url = "https://www.youtube.com/watch?v=" + identifier
    try:
        with path.open("a") as handle:
            handle.write(f"{title}\n{url}\n----------\n")
    except OSError:
        pass


UNAVAILABLE_TITLES = {"[Private video]", "[Deleted video]", "[Unavailable video]"}
ERROR_ID = re.compile(r"^ERROR: \[youtube\] ([A-Za-z0-9_-]{11}): (.*)$")


def item_ranges(indices):
    ranges = []
    for index in sorted(indices):
        if ranges and index == ranges[-1][1] + 1:
            ranges[-1][1] = index
        else:
            ranges.append([index, index])
    return ",".join(f"{a}-{b}" if a != b else str(a) for a, b in ranges)


def precheck_playlist(url, status, log, workers=6, history=None):
    def write(line):
        with lock:
            log.write(line + "\n")
            log.flush()

    lock = threading.Lock()
    write("[precheck] Listing playlist entries…")
    status.update(status="checking", phase="Listing playlist", percent=None)
    listing = subprocess.run(
        ["yt-dlp", "--ignore-config", *cookie_flags(), "--flat-playlist", "--dump-single-json", "--no-warnings",
         "--socket-timeout", "15", "--", url],
        capture_output=True, text=True, check=False,
    )
    try:
        data = json.loads(listing.stdout)
    except ValueError:
        data = None
    if not isinstance(data, dict):
        errors = [line for line in listing.stderr.splitlines() if line.startswith("ERROR:")]
        if errors:
            write(errors[-1])
        write("[precheck] Could not list playlist, trying the download directly")
        return None
    entries = data.get("entries") or []
    title = data.get("title") or ""
    status.update(playlistTitle=title, checkTotal=len(entries), checked=0, skipped=0)
    write(f"[precheck] {title} · {len(entries)} items")

    candidates = {}
    skipped = 0
    known = 0
    history = history or {}
    for index, entry in enumerate(entries, 1):
        identifier = (entry or {}).get("id") or ""
        name = (entry or {}).get("title") or identifier
        if not re.fullmatch(r"[A-Za-z0-9_-]{11}", identifier) or name in UNAVAILABLE_TITLES \
                or (entry or {}).get("availability") in ("private", "needs_auth", "unavailable"):
            skipped += 1
            write(f"[precheck] skip #{index} {name} · listed as unavailable")
            continue
        if identifier in history:
            known += 1
            write(f"[precheck] skip #{index} {name} · already downloaded")
            continue
        candidates[identifier] = (index, name)

    progress = {"checked": len(entries) - len(candidates), "skipped": skipped}
    status.update(alreadyDownloaded=known)
    errored = set()
    status.update(phase="Checking availability", checked=progress["checked"], skipped=skipped,
                  percent=progress["checked"] / max(1, len(entries)) * 100)

    def check(chunk):
        process = subprocess.Popen(
            ["yt-dlp", "--ignore-config", *cookie_flags(), "--ignore-errors", "--no-warnings", "--socket-timeout", "15",
             "--retries", "1", "--extractor-args", "youtube:player_client=mweb,web,ios",
             "--print", "OK:%(id)s", "--"]
            + ["https://www.youtube.com/watch?v=" + identifier for identifier in chunk],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
        )
        for line in process.stdout:
            line = line.rstrip("\n")
            if not line.startswith("OK:"):
                match = ERROR_ID.match(line)
                if not match:
                    continue
                identifier, reason = match.groups()
                index, name = candidates.get(identifier, (0, identifier))
                reason = reason.split(". ")[0].strip().rstrip(".")
                label = name if name != identifier else "video " + identifier
                write(f"[precheck] skip #{index} {label} · {reason[:90]}")
                with lock:
                    errored.add(identifier)
                    progress["skipped"] += 1
            with lock:
                progress["checked"] += 1
                status.update(checked=progress["checked"], skipped=progress["skipped"],
                              percent=progress["checked"] / max(1, len(entries)) * 100)
        process.wait()

    identifiers = list(candidates)
    chunks = [identifiers[i::workers] for i in range(workers) if identifiers[i::workers]]
    threads = [threading.Thread(target=check, args=(chunk,), daemon=True) for chunk in chunks]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    keep = [candidates[identifier][0] for identifier in identifiers if identifier not in errored]
    blocked = progress["skipped"]
    write(f"[precheck] {len(keep)} to download · {blocked} unavailable" + (f" · {known} already downloaded" if known else ""))
    status.update(skipped=blocked, checked=len(entries), percent=100)
    return {"items": item_ranges(keep), "count": len(keep), "skipped": blocked, "known": known, "title": title}


def main():
    if len(sys.argv) != 3:
        return 2
    mode, url = sys.argv[1:]
    playlist = mode in ('playlist-audio', 'playlist-video')
    if playlist:
        mode = mode.removeprefix('playlist-')
    parsed = urlsplit(url)
    if mode not in ("audio", "video") or parsed.scheme not in ("http", "https") or not parsed.netloc:
        notify("Invalid download", "Choose audio or video and enter a valid URL")
        return 2
    if playlist:
        playlist_id = parse_qs(parsed.query).get('list', [''])[0]
        if parsed.hostname not in ('youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'youtu.be') or not playlist_id:
            notify('Invalid playlist', 'Enter a YouTube playlist URL')
            return 2
        if re.fullmatch(r'UC[A-Za-z0-9_-]{22}', playlist_id):
            playlist_id = 'UU' + playlist_id[2:]
        url = 'https://www.youtube.com/playlist?' + urlencode({'list': playlist_id})
    if not shutil.which("yt-dlp") or not shutil.which("ffmpeg"):
        notify("Download unavailable", "yt-dlp and FFmpeg must be installed")
        return 1

    folder = Path.home() / "0" / ("music" if mode == "audio" else "videos") / "yt"
    folder.mkdir(parents=True, exist_ok=True)
    logs = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/hub/ytdlp"
    logs.mkdir(parents=True, exist_ok=True)
    fd, log_path = tempfile.mkstemp(prefix="download-", suffix=".log", dir=logs)
    history_path = folder / ".yt.txt" if mode == "audio" else None
    history = read_history(history_path) if history_path else {}
    if mode == "audio" and not playlist:
        match = VIDEO_ID.search(url)
        if match and match.group(1) in history:
            title = history[match.group(1)]
            Status(Path(log_path).with_suffix(".json"), url=url, mode=mode, log=log_path, playlist=False,
                   title=title, status="done", phase="Already downloaded", percent=100,
                   folder="~/" + str(folder.relative_to(Path.home())))
            os.close(fd)
            notify("yt-dlp · ↻", f"Already downloaded: {title}")
            return 0
    args = ["yt-dlp", "--ignore-config", *cookie_flags(), "--no-playlist", "--newline", "--progress",
            "--progress-delta", "1", "--no-color", "--socket-timeout", "15", "--retries", "3",
            "--fragment-retries", "3", "--concurrent-fragments", "5",
            "--extractor-args", "youtube:player_client=mweb,web,ios",
            "--no-simulate", "--no-quiet", "--print", "before_dl:YTDLP_DURATION:%(duration)s",
            "--print", "after_move:YTDLP_DONE:%(title)s|%(webpage_url)s|%(id)s",
            "--progress-template", "download:YTDLP_PROGRESS:%(progress)j", "-P", str(folder),
            "-o", "%(title)s.%(ext)s" if mode == "audio" else "%(title).180B [%(id)s].%(ext)s"]
    if mode == "audio":
        args += ["-f", "ba/b", "-x", "--audio-format", "mp3", "--audio-quality", "0",
                 "--embed-thumbnail", "--convert-thumbnails", "jpg", "--add-metadata",
                 "--replace-in-metadata", "uploader", " - Topic$", "",
                 "--parse-metadata", "uploader:%(artist)s",
                 "--parse-metadata", "uploader:%(album_artist)s",
                 "--replace-in-metadata", "title", r"(?i)\s*[\(\[]?\b(?:feat|ft)\b\.?\s*[\)\]]?.*$", ""]
    else:
        args += ["-f", "bv[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]",
                 "--merge-output-format", "mp4", "--remux-video", "mp4"]
    args += ["--", url]
    if playlist:
        args.remove('--no-playlist')
        args[1:1] = ['--yes-playlist', '--continue', '--no-abort-on-error',
                     '--replace-in-metadata', 'playlist_title', r'(?i)^album\s*-\s*', '',
                     '--parse-metadata', 'playlist_title:%(album)s',
                     '--parse-metadata', 'playlist_index:%(track_number)s']
        if mode == "video":
            args[1:1] = ['--embed-thumbnail', '--convert-thumbnails', 'jpg', '--embed-metadata']
        args[args.index('-o') + 1] = '%(playlist_title)s/%(title)s.%(ext)s'
    notification_id = notify("yt-dlp", "…", persistent=True)
    status = Status(Path(log_path).with_suffix(".json"), url=url, mode=mode, log=log_path, playlist=playlist)
    with tempfile.TemporaryDirectory(prefix="ffmpeg-", dir=logs) as progress_dir, os.fdopen(fd, "w") as log:
        progress_path = Path(progress_dir) / "progress"
        if playlist:
            notification_id = notify("yt-dlp", "Checking playlist availability…", notification_id, persistent=True)
            check = precheck_playlist(url, status, log, history=history)
            if check is not None:
                if check["count"] == 0:
                    if check["known"]:
                        status.update(status="done", phase="Already downloaded", percent=100, code=0,
                                      folder="~/" + str(folder.relative_to(Path.home())))
                        notify("yt-dlp · ↻", "Everything in this playlist is already downloaded", notification_id)
                        return 0
                    status.update(status="failed", phase="Nothing available", percent=None, code=1)
                    notify("Download skipped", "No available items in this playlist", notification_id)
                    return 1
                args[len(args) - 2:len(args) - 2] = ["--playlist-items", check["items"]]
                status.update(status="starting", phase="Starting downloads", percent=None)
        postprocessor = "ExtractAudio" if mode == "audio" else "Merger"
        args[1:1] = ["--postprocessor-args",
                     f"{postprocessor}+ffmpeg_o:-progress {shlex.quote(str(progress_path))} -stats_period 0.25 -nostats"]
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace", bufsize=1) as process:
            returncode, notification_id = monitor_download(process, progress_path, log, mode, notification_id, status, history_path)
    saved = status.data.get("done", 0)
    partial = bool(returncode) and saved > 0
    status.update(status="failed" if returncode and not partial else "done", code=returncode, speed="", eta="",
                  phase="Saved with errors" if partial else "Done" if not returncode else status.data.get("phase"),
                  percent=status.data.get("percent") if returncode and not partial else 100,
                  folder="~/" + str(folder.relative_to(Path.home())))
    if partial:
        notification_id = notify("yt-dlp · ⚠", f"Saved {saved} with errors · ~/" + str(folder.relative_to(Path.home())), notification_id)
        close_notification_after(notification_id, 4)
    elif returncode:
        notify("Download failed", f"Details: {log_path}", notification_id)
    else:
        notification_id = notify("yt-dlp · ✓", "~/" + str(folder.relative_to(Path.home())), notification_id, glyph="✓")
        close_notification_after(notification_id)
    return returncode

def run():
    try:
        return main()
    except Exception as error:
        logs = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/hub/ytdlp"
        for path in sorted(logs.glob("download-*.json"), key=lambda p: p.stat().st_mtime, reverse=True):
            try:
                data = json.loads(path.read_text())
            except (OSError, ValueError):
                continue
            if data.get("pid") == os.getpid():
                with open(data.get("log", os.devnull), "a") as log:
                    log.write(f"ERROR: download.py crashed: {type(error).__name__}: {error}\n")
                data.update(status="failed", phase="Crashed", updated=time.time())
                path.write_text(json.dumps(data))
                break
        notify("Download failed", f"{type(error).__name__}: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(run())
