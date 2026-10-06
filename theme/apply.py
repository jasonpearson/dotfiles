#!/usr/bin/env python3
"""Render portable shell themes; only generated cache files are ever written.

Python 3.11+ (provided by mise), standard library only. On Omarchy the input is
its user-template output; elsewhere it is the adjacent manual palette.toml.
"""

import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import tomllib

COLORS = (
    "foreground", "background", "accent", "muted", "error", "status_background",
    "prompt_accent", "prompt_text", "prompt_segment", "git_segment",
    "runtime_segment", "runtime_segment_alt", "hostname", "node",
)
EXPORTS = {
    "THEME_FOREGROUND": "foreground", "THEME_BACKGROUND": "background",
    "THEME_ACCENT": "accent", "THEME_ERROR": "error",
    **{"STARSHIP_" + key.upper(): key for key in COLORS if key.startswith(("prompt_", "runtime_"))},
    "STARSHIP_GIT_SEGMENT": "git_segment", "STARSHIP_HOSTNAME": "hostname",
    "STARSHIP_NODE": "node",
}


def toml_value(value):
    """Serialize parsed TOML values, including custom Starship module options."""
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value).lower()
    if isinstance(value, (datetime.datetime, datetime.date, datetime.time)):
        return value.isoformat()
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{toml_value(k)} = {toml_value(v)}" for k, v in value.items()) + " }"
    raise ValueError(f"Unsupported TOML value: {type(value).__name__}")


def toml_dump(data, prefix=()):
    lines = []
    if prefix:
        lines.append("[" + ".".join(toml_value(key) for key in prefix) + "]")
    for key, value in data.items():
        if not isinstance(value, dict):
            lines.append(f"{toml_value(key)} = {toml_value(value)}")
    for key, value in data.items():
        if isinstance(value, dict):
            lines.extend(("", toml_dump(value, (*prefix, key))))
    return "\n".join(lines) + "\n"


def read_palette(path):
    palette = tomllib.loads(path.read_text())
    if palette.get("mode") not in ("dark", "light"):
        raise ValueError(f"{path}: mode must be dark or light")
    for key in COLORS:
        if not isinstance(palette.get(key), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", palette[key]):
            raise ValueError(f"{path}: {key} must be a six-digit hex color")
    return {key: palette[key] for key in ("mode", *COLORS)}


def atomic_write(path, text):
    if path.exists() and path.read_text() == text:
        return
    fd, name = tempfile.mkstemp(prefix=".theme-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def select_palette(cache, manual):
    # This producer path is hardcoded by Omarchy, not XDG_STATE_HOME or nvim's
    # stdpath('state'). A previous Omarchy palette survives its rm/mv gap.
    current = Path.home() / ".local/state/omarchy/current/theme/dotfiles-palette.toml"
    previous = cache / "source"
    was_omarchy = previous.exists() and previous.read_text() == "omarchy\n"
    if not manual:
        for attempt in range(4):
            try:
                return read_palette(current), "omarchy"
            except FileNotFoundError:
                if not was_omarchy:
                    break
                if attempt < 3:
                    time.sleep(0.05)
        if was_omarchy:
            raise ValueError("Omarchy palette temporarily unavailable; keeping the last theme. "
                             "Use --manual to deliberately return to the fallback.")
    return read_palette(Path(__file__).resolve().with_name("palette.toml")), "manual"


def reload_tmux(cache, socket):
    """Register explicit servers; never create a server or reload keybindings."""
    registry = cache / "tmux-sockets.json"
    sockets = set(json.loads(registry.read_text())) if registry.exists() else set()
    if socket:
        sockets.add(socket)
    sockets = {path for path in sockets if Path(path).exists() and stat.S_ISSOCK(Path(path).stat().st_mode)}
    atomic_write(registry, json.dumps(sorted(sockets)) + "\n")
    binary = shutil.which("tmux")
    if not binary:
        return
    env = dict(os.environ)
    env.pop("TMUX", None)
    # Explicit startup registration targets just that server. The theme hook
    # targets registered servers plus the default server (which may predate us).
    targets = [["-S", socket]] if socket else [[], *(["-S", path] for path in sorted(sockets))]
    for target in targets:
        subprocess.run([binary, "-N", *target, "source-file", str(cache / "tmux.conf")],
                       env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)


def apply(args):
    # Mise deploys to these explicit destinations, not XDG_CONFIG_HOME.
    config = Path.home() / ".config"
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "dotfiles/theme"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (cache / ".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        palette, source = select_palette(cache, args.manual)
        layout = tomllib.loads((config / "starship.toml").read_text())
        layout["palette"] = "shared"
        layout.setdefault("palettes", {})["shared"] = {key: palette[key] for key in COLORS}
        starship = toml_dump(layout)
        # Round-trip before publishing so malformed output never replaces a
        # working prompt. No source/config symlink is opened for writing.
        if tomllib.loads(starship) != layout:
            raise ValueError("Starship TOML did not round-trip")
        tmux = "# Generated by dotfiles theme/apply.py.\n" + "".join(
            f'set -g @theme_{key} "{palette[key]}"\n' for key in COLORS
        ) + f'setw -g clock-mode-colour "{palette["accent"]}"\n'
        shell = "# Generated by dotfiles theme/apply.py.\n" + "".join(
            f"export {name}='{palette[key]}'\n" for name, key in EXPORTS.items()
        )
        atomic_write(cache / "starship.toml", starship)
        atomic_write(cache / "tmux.conf", tmux)
        atomic_write(cache / "source", source + "\n")
        # Publish the shell change last: its pre-prompt callback can now safely
        # use both the new Readline color and the complete Starship config.
        atomic_write(cache / "colors.sh", shell)
        if not args.no_reload:
            reload_tmux(cache, args.tmux_socket)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-reload", action="store_true", help="render without touching tmux servers")
    parser.add_argument("--tmux-socket", help="register and update only this tmux server (used at startup)")
    parser.add_argument("--manual", action="store_true", help="use the fallback even when Omarchy is present")
    args = parser.parse_args()
    try:
        apply(args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"dotfiles theme: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
