#!/bin/bash
if [[ "$(uname)" == "Darwin" ]]; then
  pbcopy
else
  xsel --clipboard
fi
