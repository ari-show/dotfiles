#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open Ghostty
# @raycast.mode silent
# @raycast.packageName Ghostty

set -eu
app="$HOME/.nix-profile/Applications/Ghostty.app"
if [ ! -d "$app" ]; then
  echo "Ghostty is not installed in the Nix profile" >&2
  exit 1
fi
open -a "$app"
