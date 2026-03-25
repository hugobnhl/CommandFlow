#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/new_worktree.sh <feature-name>"
  exit 1
fi

feature_slug="${1:l}"
feature_slug="${feature_slug// /-}"
branch_name="codex/${feature_slug}"
worktree_path="../CommandFlow-${feature_slug}"

git worktree add "${worktree_path}" -b "${branch_name}"

echo "Created worktree:"
echo "  Branch: ${branch_name}"
echo "  Path:   ${worktree_path}"

