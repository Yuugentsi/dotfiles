import fcntl
from functools import lru_cache
import hashlib
import json
import os
import random
import re
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.parse import quote

LIBRARY = Path.home() / "0/music"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
SOCKET = RUNTIME / "y-music-engine.sock"
CACHE = Path.home() / ".cache/omarchy/local-music"
PREFERENCES = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "y.music/preferences.json"
EXTENSIONS = {".mp3", ".flac", ".m4a", ".ogg", ".opus", ".wav", ".aac", ".webm"}


def preferences():
    defaults = {"autoplay": True, "shuffle": False}
    try:
        values = json.loads(PREFERENCES.read_text())
        return {key: values.get(key) if isinstance(values.get(key), bool) else default
                for key, default in defaults.items()}
    except (OSError, ValueError, AttributeError):
        return defaults


def set_preference(name, enabled):
    values = preferences()
    values[name] = enabled
    PREFERENCES.parent.mkdir(parents=True, exist_ok=True)
    temporary = PREFERENCES.with_suffix(f".{os.getpid()}.tmp")
    try:
        temporary.write_text(json.dumps(values))
        temporary.replace(PREFERENCES)
    finally:
        temporary.unlink(missing_ok=True)


def set_autoplay(enabled):
    set_preference("autoplay", enabled)


def metadata_path(path):
    digest = hashlib.sha256(str(path.resolve()).encode()).hexdigest()
    return CACHE / "metadata" / f"{digest}.json"


@lru_cache(maxsize=4096)
def metadata(path):
    try:
        stat = path.stat()
        signature = [stat.st_mtime_ns, stat.st_size]
    except OSError:
        signature = None
    cache_file = metadata_path(path)
    if signature is not None:
        try:
            cached = json.loads(cache_file.read_text())
            if cached.get("signature") == signature:
                return cached["metadata"]
        except (OSError, ValueError, KeyError, TypeError):
            pass

    info = {"title": path.stem, "artist": "", "album": "", "track": 0}
    try:
        from mutagen import File as AudioFile
        audio = AudioFile(path, easy=True)
        tags = audio.tags if audio else {}
        for key in ("title", "artist", "album"):
            values = tags.get(key) if tags else None
            if values:
                info[key] = str(values[0])
        values = tags.get("tracknumber") if tags else None
        if values:
            info["track"] = int(re.match(r"\d+", str(values[0])).group())
    except (ImportError, OSError, ValueError, AttributeError, TypeError):
        pass

    if signature is not None:
        try:
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            temporary = cache_file.with_suffix(f".{os.getpid()}.tmp")
            temporary.write_text(json.dumps({"signature": signature, "metadata": info}))
            temporary.replace(cache_file)
        except OSError:
            pass
    return info


def natural_key(value):
    return tuple(int(part) if part.isdigit() else part.casefold()
                 for part in re.split(r"(\d+)", value))


@lru_cache(maxsize=1)
def tracks():
    if not LIBRARY.is_dir():
        return []
    songs = (p for p in LIBRARY.rglob("*") if p.is_file() and p.suffix.lower() in EXTENSIONS
             and p.resolve().is_relative_to(LIBRARY.resolve()) and "\n" not in str(p))
    def sort_key(path):
        info = metadata(path)
        track = info["track"]
        return (str(path.parent.relative_to(LIBRARY)).casefold(),
                0 if track else 1, track if track else natural_key(info["title"]))
    return sorted(songs, key=sort_key)


def audio_request(command, *args, start=True):
    try:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(6)
            connection.connect(str(SOCKET))
            connection.sendall((json.dumps({"command": command, "args": args}) + "\n").encode())
            with connection.makefile("r") as stream:
                reply = json.loads(stream.readline())
        if "error" in reply:
            raise RuntimeError(reply["error"])
        return reply["data"]
    except (FileNotFoundError, ConnectionRefusedError):
        if not start:
            raise
        ensure_player()
        return audio_request(command, *args, start=False)


def ensure_player():
    try:
        audio_request("ping", start=False)
        return
    except (OSError, ConnectionError):
        pass
    with (RUNTIME / "omarchy-local-music.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            audio_request("ping", start=False)
            return
        except (OSError, ConnectionError):
            pass
        with (RUNTIME / "y-music-engine.log").open("a") as log:
            process = subprocess.Popen(
                [sys.executable, "-B", str(Path(__file__).with_name("crossfade.py"))],
                stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
        for _ in range(200):
            try:
                audio_request("ping", start=False)
                return
            except (OSError, ConnectionError):
                if process.poll() is not None:
                    break
                time.sleep(0.03)
        raise RuntimeError("Could not start the music engine; see " + str(RUNTIME / "y-music-engine.log"))


def cover_path(path):
    source = Path(path)
    signature = ["track-cover-v1", str(source.resolve())]
    for item in (source, source.with_suffix(".jpg"), source.parent / "cover.jpg", source.parent / "folder.jpg"):
        try:
            stat = item.stat()
            signature.append((str(item), stat.st_mtime_ns, stat.st_size))
        except OSError:
            pass
    digest = hashlib.sha256(json.dumps(signature, ensure_ascii=False).encode()).hexdigest()
    return CACHE / f"{digest}.jpg"


def cover_uri(cover):
    return "file://" + quote(str(cover))


def extract_cover(path):
    source = Path(path)
    cover = cover_path(path)
    pending = cover.with_suffix(".pending")
    temporary = cover.with_suffix(".tmp.jpg")
    try:
        if not source.is_file() or not source.resolve().is_relative_to((Path.home() / "0/music").resolve()):
            return
        result = subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(source), "-an", "-frames:v", "1", str(temporary)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20, check=False,
        )
        if result.returncode == 0 and temporary.is_file() and temporary.stat().st_size:
            temporary.replace(cover)
            return
        for sidecar in (source.with_suffix(".jpg"), source.parent / "cover.jpg", source.parent / "folder.jpg"):
            if sidecar.is_file():
                import shutil
                shutil.copyfile(sidecar, temporary)
                temporary.replace(cover)
                return
        match = re.search(r"\[([A-Za-z0-9_-]{11})\]$", source.stem)
        if match:
            from urllib.request import urlopen
            with urlopen(f"https://i.ytimg.com/vi/{match.group(1)}/hqdefault.jpg", timeout=10) as response:
                data = response.read(5_000_000)
            if data.startswith(b"\xff\xd8"):
                temporary.write_bytes(data)
                temporary.replace(cover)
                return
        cover.with_suffix(".missing").touch()
    except (OSError, subprocess.TimeoutExpired):
        cover.with_suffix(".missing").touch()
    finally:
        pending.unlink(missing_ok=True)
        temporary.unlink(missing_ok=True)


def request_cover(path):
    CACHE.mkdir(parents=True, exist_ok=True)
    cover = cover_path(path)
    if cover.exists() or cover.with_suffix(".missing").exists():
        return
    pending = cover.with_suffix(".pending")
    if pending.exists() and time.time() - pending.stat().st_mtime < 60:
        return
    pending.touch()
    subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "cover", path],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    return True


def play(path):
    songs = tracks()
    selected = Path(path)
    if selected not in songs:
        raise ValueError("Track is outside the music library")
    audio_request("play", str(selected), [str(path) for path in songs])
    request_cover(str(selected))


def play_artist(artist, artist_order=None):
    groups = {}
    for path in tracks():
        name = metadata(path)["artist"] or "—"
        groups.setdefault(name, []).append(path)
    if artist not in groups:
        raise ValueError("No tracks found for this artist")
    names = sorted(groups, key=lambda name: (-len(groups[name]), name.casefold()))
    if artist_order is not None:
        if not isinstance(artist_order, list) or any(not isinstance(name, str) for name in artist_order):
            raise ValueError("Invalid artist order")
        supplied = list(dict.fromkeys(name for name in artist_order if name in groups))
        names = supplied + [name for name in names if name not in supplied]
    start = names.index(artist)
    names = names[start:] + names[:start]
    def order(path):
        info = metadata(path)
        return (info["album"].casefold(), info["track"] or float("inf"), natural_key(info["title"]))
    queue = []
    for index, name in enumerate(names):
        songs = sorted(groups[name], key=order)
        if index == 0:
            first = songs.index(random.choice(songs))
            songs = songs[first:] + songs[:first]
        queue.extend(songs)
    selected = queue[0]
    audio_request("play", str(selected), [str(path) for path in queue])
    request_cover(str(selected))


def delete_track(path):
    selected = Path(path)
    if selected not in tracks():
        raise ValueError("Track is outside the music library")
    deleted_cover = cover_path(selected)
    cache_metadata = metadata_path(selected)
    result = audio_request("delete", str(selected))
    try:
        cache_metadata.unlink(missing_ok=True)
        (CACHE / "boundaries" / cache_metadata.name).unlink(missing_ok=True)
        deleted_cover.unlink(missing_ok=True)
    except OSError:
        pass
    return result


def play_random_if_idle():
    if not preferences()["autoplay"]:
        return
    current = state(include_library=False)
    if current["path"] and not current["paused"]:
        return
    songs = tracks()
    if songs:
        play(str(random.choice(songs)))


def state(include_library=True):
    result = {"title": "Music", "artist": "", "path": "", "paused": True,
              "position": 0, "duration": 0, "volume": 60, "cover": "", "shuffle": preferences()["shuffle"]}
    if include_library:
        result["tracks"] = [{"path": str(p), "title": p.stem} for p in tracks()]
    try:
        current = audio_request("state")
        path = current["path"]
        tags = current["metadata"]
        result.update(path=path, title=tags.get("TITLE") or tags.get("title") or
                      (Path(path).stem if path else "Music"),
                      artist=tags.get("ARTIST") or tags.get("artist") or "",
                      paused=current["paused"], position=current["position"],
                      duration=current["duration"], volume=current["volume"], shuffle=current.get("shuffle", False))
        if path:
            cover = cover_path(path)
            if cover.is_file():
                result["cover"] = cover_uri(cover)
            else:
                request_cover(path)
    except (OSError, ConnectionError):
        pass
    return result


def main(args):
    if args == ["preferences"]:
        print(json.dumps(preferences()))
        return
    if len(args) == 2 and args[0] == "autoplay" and args[1] in ("on", "off"):
        set_autoplay(args[1] == "on")
        return
    if args == ["library"]:
        items = []
        requested_covers = 0
        for path in tracks():
            info = metadata(path)
            cover = cover_path(path)
            if not cover.is_file() and requested_covers < 4:
                if request_cover(str(path)):
                    requested_covers += 1
            items.append({"path": str(path), "title": info["title"],
                          "artist": info["artist"], "album": info["album"], "track": info["track"],
                          "cover": cover_uri(cover) if cover.is_file() else ""})
        print(json.dumps(items))
        return
    if args == ["random-if-idle"]:
        play_random_if_idle()
        return
    if args == ["shuffle"]:
        audio_request("shuffle")
        return
    if args == ["state-fast"]:
        print(json.dumps(state(include_library=False)))
        return
    if len(args) == 2 and args[0] == "cover":
        extract_cover(args[1])
        return
    if args == ["state"]:
        print(json.dumps(state()))
        return
    if len(args) == 2 and args[0] == "play":
        play(args[1])
        return
    if len(args) in (2, 3) and args[0] == "play-artist":
        play_artist(args[1], json.loads(args[2]) if len(args) == 3 else None)
        return
    if len(args) == 2 and args[0] == "delete":
        delete_track(args[1])
        return
    if args == ["toggle"] and not state()["path"]:
        songs = tracks()
        if songs:
            play(str(songs[0]))
        return
    if args in (["toggle"], ["next"], ["previous"]):
        audio_request(args[0])
    elif len(args) == 2 and args[0] in ("seek", "volume"):
        audio_request(args[0], float(args[1]))
    else:
        raise ValueError("Unknown command")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
