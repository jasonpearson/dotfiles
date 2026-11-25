"""Render agent JSON with tmux-attention and, optionally, Moshi hooks."""

import argparse
import json
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("agent", choices=("claude", "codex"))
    parser.add_argument("--moshi", action="store_true")
    args = parser.parse_args()

    agents_dir = Path(__file__).resolve().parent
    config = read_json(agents_dir / "claude" / "settings.json") if args.agent == "claude" else {}
    hooks = config.setdefault("hooks", {})

    integrations = ("tmux", "moshi") if args.moshi else ("tmux",)
    for integration in integrations:
        fragment = agents_dir.parent / integration / f"{args.agent}-hooks.json"
        for event, groups in read_json(fragment).items():
            hooks.setdefault(event, []).extend(groups)

    print(json.dumps(config, indent=2))


if __name__ == "__main__":
    main()
