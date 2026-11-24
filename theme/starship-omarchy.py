"""Render the shared Starship layout with Omarchy's current theme colors."""

import os
from pathlib import Path
import tomllib

from apply import atomic_write, toml_dump


def channels(color):
    return tuple(int(color[index:index + 2], 16) for index in (1, 3, 5))


def blend(accent, background, strength):
    return "#" + "".join(
        f"{round(base + (tint - base) * strength):02x}"
        for tint, base in zip(channels(accent), channels(background))
    )


home = Path.home()
config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
cache = Path(os.environ.get("XDG_CACHE_HOME") or home / ".cache") / "dotfiles"
theme = home / ".local/state/omarchy/current/theme/colors.toml"
colors = tomllib.loads(theme.read_text())
layout = tomllib.loads((config / "starship.toml").read_text())
palette = layout["palettes"]["shared"]
accent, background = colors["accent"], colors["background"]

palette.update(
    prompt_accent=accent,
    prompt_text=background,
    prompt_segment=blend(accent, background, 0.34),
    git_segment=blend(accent, background, 0.19),
    runtime_segment=background,
    runtime_segment_alt=background,
)
layout["directory"]["style"] = "fg:foreground bg:prompt_segment"
layout["git_branch"]["style"] = "fg:foreground bg:git_segment"
layout["git_status"]["style"] = layout["git_branch"]["style"]
layout["git_branch"]["format"] = "[ $symbol $branch ]($style)"
layout["time"]["format"] = "[  $time ](fg:prompt_accent bg:runtime_segment)"
palette["foreground"] = colors["foreground"]

cache.mkdir(parents=True, exist_ok=True)
atomic_write(cache / "starship-omarchy.toml", toml_dump(layout))
