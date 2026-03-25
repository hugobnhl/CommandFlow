#!/bin/zsh
set -euo pipefail

paths=(
  "/Applications/CommandFlow.app"
  "$HOME/Library/Preferences/com.commandflow.macos.plist"
  "$HOME/Downloads/CommandFlow.dmg"
  "$HOME/.Trash/CommandFlow.app"
  "$HOME/.Trash/dmgCommandFlow.dmg1.43 MB .textClipping"
)

for target in "${paths[@]}"; do
  if [[ -e "$target" ]]; then
    rm -rf "$target"
    echo "Removed: $target"
  else
    echo "Skipped: $target"
  fi
done

echo "Legacy cleanup finished."

