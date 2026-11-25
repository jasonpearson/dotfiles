# /// script
# requires-python = ">=3.9"
# dependencies = ["tomlkit==0.15.3"]
# ///
"""Apply the repo's Codex TOML fragments without replacing local settings."""

import argparse
from collections.abc import MutableMapping
import os
from pathlib import Path
import stat
import tempfile

import tomlkit


def merge(target, fragment):
    for key, value in fragment.items():
        current = target.get(key)
        if isinstance(value, MutableMapping) and isinstance(current, MutableMapping):
            merge(current, value)
        elif type(current) is not type(value) or current != value:
            target[key] = value


def apply(path, fragments):
    try:
        original = path.read_bytes().decode("utf-8")
        mode = stat.S_IMODE(path.stat().st_mode)
    except FileNotFoundError:
        original, mode = "", 0o600

    config = tomlkit.parse(original)
    for fragment in fragments:
        merge(config, tomlkit.parse(fragment.read_text(encoding="utf-8")))
    updated = tomlkit.dumps(config)
    if updated == original:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    output = tempfile.NamedTemporaryFile(dir=path.parent, delete=False)
    temporary = Path(output.name)
    try:
        with output:
            output.write(updated.encode("utf-8"))
            os.fchmod(output.fileno(), mode)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--theme", action="store_true", help="also select the dotfiles theme")
    args = parser.parse_args()

    codex_home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
    path = (codex_home / "config.toml").resolve()
    source = Path(__file__).resolve().parent
    names = ["tmux.toml", "attention.toml"]
    if args.theme:
        names.append("theme.toml")
    try:
        changed = apply(path, [source / name for name in names])
    except (OSError, ValueError, tomlkit.exceptions.TOMLKitError) as error:
        parser.exit(1, f"Could not update {path}: {error}\n")
    print(f"{'Updated' if changed else 'Already up to date:'} {path}")


if __name__ == "__main__":
    main()
