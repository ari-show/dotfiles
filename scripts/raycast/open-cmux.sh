#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open cmux
# @raycast.mode silent
# @raycast.packageName cmux

set -eu
app="$HOME/.nix-profile/Applications/cmux.app"
if [ ! -d "$app" ]; then
  echo "cmux is not installed in the Nix profile" >&2
  exit 1
fi
open -a "$app"
