import concurrent.futures
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOTS = [Path.home() / "Videos", Path.home() / "0/videos"]
CACHE = Path.home() / ".cache/y.media/videos"


def cache_path(path):
    stat = path.stat()
    key = hashlib.sha256(f"{path.resolve()}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()
    return CACHE / key


def scan():
    found = {}
    errors = []
    for root in ROOTS:
        if not root.is_dir():
            continue
        for directory, folders, files in os.walk(root, onerror=lambda error: errors.append(str(error))):
            folders[:] = [name for name in folders if not name.startswith(".")]
            for name in files:
                if Path(name).suffix.lower() != ".mp4":
                    continue
                try:
                    path = (Path(directory) / name).resolve(strict=True)
                    if not path.is_file():
                        continue
                    stat = path.stat()
                    cache = cache_path(path)
                    thumbnail = cache.with_suffix(".jpg")
                    try:
                        metadata = json.loads(cache.with_suffix(".json").read_text())
                    except (OSError, ValueError):
                        metadata = {}
                    found[str(path)] = {
                        "path": str(path), "url": path.as_uri(), "name": name, "folder": str(path.parent),
                        "modified": stat.st_mtime_ns, "size": stat.st_size,
                        "thumbnail": thumbnail.as_uri() if thumbnail.is_file() else "",
                        "duration": metadata.get("duration", 0),
                        "processed": bool(metadata.get("processed")),
                    }
                except OSError as error:
                    errors.append(str(error))
    return {"videos": sorted(found.values(), key=lambda item: (-item["modified"], item["path"])),
            "error": "\n".join(errors)}


def prepare(entry):
    path = Path(entry["path"])
    temporary = None
    try:
        cache = cache_path(path)
        thumbnail = cache.with_suffix(".jpg")
        temporary = cache.with_suffix(f".{os.getpid()}.tmp.jpg")
        metadata = {"processed": True, "duration": 0}
        if not thumbnail.is_file():
            result = subprocess.run(
                ["ffmpegthumbnailer", "-i", str(path), "-o", str(temporary),
                 "-s", "480", "-t", "10%", "-q", "8"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=25,
            )
            if result.returncode == 0 and temporary.is_file() and temporary.stat().st_size:
                temporary.replace(thumbnail)
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of",
             "default=noprint_wrappers=1:nokey=1", str(path)],
            capture_output=True, text=True, timeout=15,
        )
        try:
            duration = float(result.stdout.strip())
            if math.isfinite(duration) and duration > 0:
                metadata["duration"] = duration
        except ValueError:
            pass
        metadata_file = cache.with_suffix(".json")
        temporary_metadata = metadata_file.with_suffix(f".{os.getpid()}.tmp")
        temporary_metadata.write_text(json.dumps(metadata))
        temporary_metadata.replace(metadata_file)
    except (OSError, subprocess.TimeoutExpired):
        pass
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def thumbnails():
    CACHE.mkdir(parents=True, exist_ok=True)
    with (CACHE / "worker.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        pending = [entry for entry in scan()["videos"] if not entry["processed"]]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(prepare, pending))


def main(args):
    if args == ["thumbnails"]:
        thumbnails()
        return
    if args != ["list"]:
        raise ValueError("Invalid command")
    result = scan()
    if any(not entry["processed"] for entry in result["videos"]):
        subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), "thumbnails"],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1:])
