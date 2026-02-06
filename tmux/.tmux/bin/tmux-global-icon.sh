#!/bin/bash
for f in /tmp/tmux-state*; do
    [[ -f "$f" ]] && echo " 🟠" && exit 0
done
