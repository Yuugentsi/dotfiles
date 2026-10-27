import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import hashlib
import fcntl

EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".avif", ".jxl", ".svg", ".tif", ".tiff"}
ROOTS = [Path.home() / "Pictures", Path.home() / "0/pictures"]

def images():
    found = {}
    errors = []
    for root in ROOTS:
        if not root.exists():
            continue
        def onerror(error):
            errors.append(str(error))
        for directory, folders, files in os.walk(root, onerror=onerror):
            folders[:] = [name for name in folders if not name.startswith(".")]
            for name in files:
                path = Path(directory) / name
                if path.suffix.lower() not in EXTENSIONS:
                    continue
                try:
                    resolved = path.resolve()
                    stat = resolved.stat()
                    if not resolved.is_file():
                        continue
                    found[str(resolved)] = {
                        "path": str(resolved), "url": resolved.as_uri(),
                        "name": name, "folder": str(path.parent),
                        "modified": stat.st_mtime_ns,
                        "size": stat.st_size,
                    }
                except OSError as error:
                    errors.append(str(error))
    return {"images": sorted(found.values(), key=lambda entry: (-entry["modified"], entry["path"])),
            "error": "\n".join(errors)}

def clipboard_image(filename):
    path = Path(filename).resolve(strict=True)
    if path.suffix.lower() not in EXTENSIONS or not path.is_file():
        raise ValueError("Choose a valid image.")
    if path.suffix.lower() == ".png":
        return path
    stat = path.stat()
    key = hashlib.sha256(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()
    cache = Path.home() / ".cache/y.images/clipboard"
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (key + ".png")
    with (cache / (key + ".lock")).open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not target.exists():
            with tempfile.NamedTemporaryFile(dir=cache, suffix=".png", delete=False) as temporary:
                output = Path(temporary.name)
            try:
                subprocess.run(["magick", str(path) + "[0]", "-auto-orient",
                                "-define", "png:compression-level=1", str(output)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=30)
                output.replace(target)
            finally:
                output.unlink(missing_ok=True)
    return target

def copy_image(filename):
    path = clipboard_image(filename)

    with path.open("rb") as source, tempfile.TemporaryFile() as errors:
        copied = subprocess.run(["wl-copy", "--type", "image/png"], stdin=source,
                                stdout=subprocess.DEVNULL, stderr=errors, timeout=10)
        if copied.returncode:
            errors.seek(0)
            raise ValueError(errors.read().decode(errors="replace").strip() or "Failed to copy image.")

if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "copy":
            copy_image(sys.argv[2])
        elif len(sys.argv) == 3 and sys.argv[1] == "prepare":
            clipboard_image(sys.argv[2])
        elif len(sys.argv) == 1:
            print(json.dumps(images(), ensure_ascii=False))
        else:
            raise ValueError("Invalid command.")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
