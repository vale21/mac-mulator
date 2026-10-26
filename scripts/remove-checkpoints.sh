#!/usr/bin/env bash
# Removes all Copilot checkpoint commits by deleting refs/copilot/checkpoints/*
# and pruning the now-unreferenced commit objects. Branch history is untouched.
set -euo pipefail

refs=$(git for-each-ref --format='%(refname)' refs/copilot/checkpoints)

if [[ -z "$refs" ]]; then
  echo "No refs under refs/copilot/checkpoints found."
  exit 0
fi

echo "Deleting $(echo "$refs" | wc -l | tr -d ' ') checkpoint ref(s)..."
echo "$refs" | sed 's/^/delete /' | git update-ref --stdin

# Drop reflog entries so the commits become unreachable, then garbage-collect them.
git reflog expire --expire-unreachable=now --all
git gc --prune=now --quiet

echo "Done."
