#!/usr/bin/env python3
"""Render portable app themes without rewriting managed configuration.

Python 3.11+ (provided by mise), standard library only. On Omarchy the input is
its user-template output; elsewhere it is a checked-in preset. Explicit selection
also saves a per-machine preference under XDG_STATE_HOME, never in app configs.
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

PRESETS = {"catppuccin": "palette.toml", "ethereal": "ethereal.toml"}

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


def selection_path():
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "dotfiles/theme/selection"


def selected_preset():
    path = selection_path()
    name = path.read_text().strip() if path.exists() else "catppuccin"
    if name not in PRESETS:
        raise ValueError(f"{path}: unknown preset {name!r}; choose catppuccin or ethereal")
    return name


def read_preset(name):
    path = Path(__file__).resolve().with_name(PRESETS[name])
    palette = read_palette(path)
    data = tomllib.loads(path.read_text())
    scheme = data.get("colorscheme")
    if not isinstance(scheme, str) or not re.fullmatch(r"[a-zA-Z0-9_.-]+", scheme):
        raise ValueError(f"{path}: invalid Neovim colorscheme")
    neovim = json.dumps({"source": "manual", "preset": name,
                         "colorscheme": scheme, "mode": palette["mode"]}) + "\n"
    terminal = data.get("ghostty", {})
    if not isinstance(terminal, dict):
        raise ValueError(f"{path}: ghostty must be a table")
    if "theme" in terminal:
        builtin = terminal["theme"]
        if not isinstance(builtin, str) or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9 ._-]*", builtin):
            raise ValueError(f"{path}: invalid built-in Ghostty theme name")
        ghostty = f"theme = {builtin}\n"
    else:
        keys = ("cursor-color", "cursor-text", "selection-foreground", "selection-background")
        for key in keys:
            if not isinstance(terminal.get(key), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", terminal[key]):
                raise ValueError(f"{path}: invalid Ghostty {key}")
        ansi = terminal.get("palette")
        if not isinstance(ansi, list) or len(ansi) != 16 or any(
            not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color) for color in ansi
        ):
            raise ValueError(f"{path}: Ghostty palette must contain 16 hex colors")
        # Clear the bundled theme so no unspecified Mocha theme settings leak in.
        ghostty = "theme =\n" + "".join(
            f"{key} = {palette[key]}\n" for key in ("foreground", "background")
        ) + "".join(f"{key} = {terminal[key]}\n" for key in keys)
        ghostty += "".join(f"palette = {index}={color}\n" for index, color in enumerate(ansi))
    return palette, ghostty, neovim


def select_palette(cache, manual, preset):
    # This producer path is hardcoded by Omarchy, not XDG_STATE_HOME or nvim's
    # stdpath('state'). A previous Omarchy palette survives its rm/mv gap.
    current = Path.home() / ".local/state/omarchy/current/theme/dotfiles-palette.toml"
    previous = cache / "source"
    was_omarchy = previous.exists() and previous.read_text() == "omarchy\n"
    if not manual:
        for attempt in range(4):
            try:
                return read_palette(current), "omarchy", None, None
            except FileNotFoundError:
                if not was_omarchy:
                    break
                if attempt < 3:
                    time.sleep(0.05)
        if was_omarchy:
            raise ValueError("Omarchy palette temporarily unavailable; keeping the last theme. "
                             "Use --manual to deliberately return to the fallback.")
    palette, ghostty, neovim = read_preset(preset)
    return palette, "manual", ghostty, neovim


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
        preset = args.select or selected_preset()
        palette, source, ghostty, neovim = select_palette(cache, args.manual, preset)
        if args.select and source == "omarchy":
            raise ValueError("Omarchy is active; use `omarchy theme set` instead. "
                             "This selector is for macOS and non-Omarchy Linux.")
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
        if source == "manual":
            atomic_write(cache / "ghostty.conf", "# Generated by dotfiles theme/apply.py.\n" + ghostty)
            atomic_write(cache / "neovim.json", neovim)
        else:
            # Ghostty's later Omarchy include is authoritative. Clear any stale
            # manual fragment; Neovim reads Omarchy directly, not this marker.
            atomic_write(cache / "ghostty.conf", "# Colors supplied by Omarchy.\n")
            atomic_write(cache / "neovim.json", '{"source": "omarchy"}\n')
        atomic_write(cache / "starship.toml", starship)
        atomic_write(cache / "tmux.conf", tmux)
        atomic_write(cache / "source", source + "\n")
        # Publish the shell change last: its pre-prompt callback can now safely
        # use both the new Readline color and the complete Starship config.
        atomic_write(cache / "colors.sh", shell)
        if args.select:
            selection = selection_path()
            selection.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            atomic_write(selection, preset + "\n")
        if not args.no_reload:
            reload_tmux(cache, args.tmux_socket)
    if args.select:
        tmux_status = "reload skipped" if args.no_reload else "refresh requested"
        print(f"Selected {preset}. Bash/Starship: next prompt; tmux: {tmux_status}; Neovim: automatic.")
        shortcut = "Cmd+Shift+," if sys.platform == "darwin" else "Ctrl+Shift+,"
        print(f"Ghostty: reload configuration with {shortcut}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-reload", action="store_true", help="render without touching tmux servers")
    parser.add_argument("--tmux-socket", help="register and update only this tmux server (used at startup)")
    parser.add_argument("--manual", action="store_true", help="use the saved preset even when Omarchy is present (one run)")
    parser.add_argument("--select", nargs="?", const="", choices=["", *PRESETS], metavar="PRESET",
                        help="save and apply a preset; without a name, show current selection and choices")
    args = parser.parse_args()
    if args.select is not None and args.manual:
        parser.error("--select cannot be combined with --manual; Omarchy owns theme selection when present")
    try:
        if args.select == "":
            print(f"Saved preset: {selected_preset()}")
            omarchy = Path.home() / ".local/state/omarchy/current/theme/dotfiles-palette.toml"
            if omarchy.exists():
                print("Omarchy is active and takes precedence; use `omarchy theme set`.")
            print("Available: " + ", ".join(PRESETS))
            print("Switch: mise theme <name>")
            return 0
        apply(args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"dotfiles theme: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
