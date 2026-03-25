#!/bin/zsh
set -euo pipefail

repo_name="${1:-CommandFlow}"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated yet."
  echo "Run: gh auth login"
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' already exists."
  git remote -v
  exit 0
fi

gh repo create "${repo_name}" \
  --private \
  --source=. \
  --remote=origin \
  --push

