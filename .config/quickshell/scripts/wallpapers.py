import fcntl
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import time

LIBRARY = Path.home() / "0/pictures/wallpapers"
STATE = Path.home() / ".local/state/omarchy/hyprpaper"
CONFIG = Path.home() / ".config/hypr/hyprpaper.conf"
EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".avif", ".jxl"}


def images():
    LIBRARY.mkdir(parents=True, exist_ok=True)
    return sorted((path for path in LIBRARY.rglob("*") if path.is_file()
                   and path.suffix.lower() in EXTENSIONS), key=lambda path: path.name.casefold())


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or args[0])
    return result.stdout


def current_state():
    try:
        return json.loads((STATE / "selection.json").read_text())
    except (FileNotFoundError, ValueError):
        return {"path": "", "mode": "normal"}


def ensure_hyprpaper():
    if not shutil.which("hyprpaper"):
        raise RuntimeError("Hyprpaper is not installed")
    check = subprocess.run(["hyprctl", "hyprpaper", "listactive"], capture_output=True, text=True)
    if check.returncode == 0:
        return
    log = (STATE / "hyprpaper.log").open("a")
    subprocess.Popen(["hyprpaper", "-c", str(CONFIG)], stdin=subprocess.DEVNULL,
                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    log.close()
    for _ in range(40):
        check = subprocess.run(["hyprctl", "hyprpaper", "listactive"], capture_output=True, text=True)
        if check.returncode == 0:
            return
        time.sleep(0.05)
    raise RuntimeError(f"Hyprpaper did not start. See {STATE / 'hyprpaper.log'}")


def apply(path, mode):
    source = Path(path).expanduser().resolve()
    if mode not in ("normal", "blur", "dark") or not source.is_file():
        raise ValueError("Choose an existing image")
    if source.suffix.lower() not in EXTENSIONS:
        raise ValueError("Unsupported image format")
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "apply.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        monitors = json.loads(run(["hyprctl", "-j", "monitors"]))
        dimensions = max(((m["width"], m["height"]) for m in monitors), key=lambda size: size[0] * size[1])
        target = STATE / f"wallpaper-{time.time_ns()}.png"
        temporary = STATE / "next.png"
        args = ["magick", str(source), "-auto-orient"]
        if mode != "normal":
            size = f"{dimensions[0]}x{dimensions[1]}"
            args += ["-resize", size + "^", "-gravity", "center", "-extent", size,
                     "-blur", "0x15", "-modulate", "30" if mode == "dark" else "60"]
        run(args + [str(temporary)])
        temporary.replace(target)
        if CONFIG.is_file() and not CONFIG.with_suffix(".conf.before-wallpapers").exists():
            shutil.copy2(CONFIG, CONFIG.with_suffix(".conf.before-wallpapers"))
        CONFIG.write_text(f"splash = false\nipc = true\nwallpaper {{\n    monitor =\n    path = {target}\n    fit_mode = cover\n}}\n")
        ensure_hyprpaper()
        for monitor in monitors:
            run(["hyprctl", "hyprpaper", "wallpaper", f"{monitor['name']},{target},cover"])
        (STATE / "selection.json").write_text(json.dumps({"path": str(source), "mode": mode}))
        link = STATE / "current.png"
        link.unlink(missing_ok=True)
        link.symlink_to(target.name)
        for old in STATE.glob("wallpaper-*.png"):
            if old != target:
                old.unlink(missing_ok=True)


def restore():
    if not (STATE / "current.png").is_file() or not CONFIG.is_file():
        return
    STATE.mkdir(parents=True, exist_ok=True)
    ensure_hyprpaper()


def main(args):
    if args == ["list"]:
        print(json.dumps({"images": [{"path": str(p), "url": p.as_uri(), "name": p.stem} for p in images()],
                          "selected": current_state()}))
    elif args == ["restore"]:
        restore()
    elif len(args) == 3 and args[0] == "apply":
        apply(args[1], args[2])
    elif len(args) == 2 and args[0] == "random":
        choices = images()
        if not choices:
            raise ValueError("Add images to ~/0/pictures/wallpapers")
        apply(str(random.choice(choices)), args[1])
    else:
        raise ValueError("Unknown command")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
