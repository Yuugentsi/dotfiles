import os
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

def output_lines(stream, lines):
    try:
        for line in stream:
            lines.put(line)
    finally:
        lines.put(None)

def monitor_download(process, progress_path, log, mode, notification_id):
    lines = queue.Queue()
    reader = threading.Thread(target=output_lines, args=(process.stdout, lines), daemon=True)
    reader.start()
    duration = None
    previous = None
    last_conversion_update = 0
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
        url = 'https://www.youtube.com/playlist?' + urlencode({'list': playlist_id})
    if not shutil.which("yt-dlp") or not shutil.which("ffmpeg"):
        notify("Download unavailable", "yt-dlp and FFmpeg must be installed")
        return 1

    folder = Path.home() / "0" / ("music" if mode == "audio" else "videos") / "yt"
    folder.mkdir(parents=True, exist_ok=True)
    logs = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/hub/ytdlp"
    logs.mkdir(parents=True, exist_ok=True)
    fd, log_path = tempfile.mkstemp(prefix="download-", suffix=".log", dir=logs)
    args = ["yt-dlp", "--ignore-config", "--no-playlist", "--newline", "--progress",
            "--progress-delta", "1", "--no-color",
            "--no-simulate", "--no-quiet", "--print", "before_dl:YTDLP_DURATION:%(duration)s",
            "--progress-template", "download:YTDLP_PROGRESS:%(progress)j", "-P", str(folder),
            "-o", "%(title).180B [%(id)s].%(ext)s"]
    if mode == "audio":
        args += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
    else:
        args += ["-f", "bv[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]",
                 "--merge-output-format", "mp4", "--remux-video", "mp4"]
    args += ["--", url]
    if playlist:
        args.remove('--no-playlist')
        args[1:1] = ['--yes-playlist', '--continue', '--no-abort-on-error',
                     '--embed-thumbnail', '--convert-thumbnails', 'jpg', '--embed-metadata',
                     '--replace-in-metadata', 'uploader', ' - Topic$', '',
                     '--parse-metadata', 'uploader:%(artist)s',
                     '--parse-metadata', 'uploader:%(album_artist)s',
                     '--replace-in-metadata', 'title', r'(?i)\s*[\(\[]?\b(?:feat|ft)\b\.?\s*[\)\]]?.*$', '',
                     '--replace-in-metadata', 'playlist_title', r'(?i)^album\s*-\s*', '',
                     '--parse-metadata', 'playlist_title:%(album)s',
                     '--parse-metadata', 'playlist_index:%(track_number)s']
        args[args.index('-o') + 1] = '%(playlist_title)s/%(title)s.%(ext)s'
    notification_id = notify("yt-dlp", "…", persistent=True)
    with tempfile.TemporaryDirectory(prefix="ffmpeg-", dir=logs) as progress_dir, os.fdopen(fd, "w") as log:
        progress_path = Path(progress_dir) / "progress"
        postprocessor = "ExtractAudio" if mode == "audio" else "Merger"
        args[1:1] = ["--postprocessor-args",
                     f"{postprocessor}+ffmpeg_o:-progress {shlex.quote(str(progress_path))} -stats_period 0.25 -nostats"]
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace", bufsize=1) as process:
            returncode, notification_id = monitor_download(process, progress_path, log, mode, notification_id)
    if returncode:
        notify("Download failed", f"Details: {log_path}", notification_id)
    else:
        notification_id = notify("yt-dlp · ✓", "~/" + str(folder.relative_to(Path.home())), notification_id, glyph="✓")
        close_notification_after(notification_id)
    return returncode

if __name__ == "__main__":
    sys.exit(main())
