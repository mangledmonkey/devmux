#!/usr/bin/env bash
# Fetch origin and rebase current branch onto origin/main.
# Portable bash equivalent of git-rebase-main.fish.
#
# Usage: rebase-main.sh [base-branch]
# Defaults to "main" if no base branch specified.

set -euo pipefail

base="${1:-main}"

echo "Fetching origin..."
git fetch origin

echo "Rebasing onto origin/$base..."
if git rebase "origin/$base"; then
  echo "Rebase successful."
else
  echo ""
  echo "Rebase has conflicts. Resolve them, then:"
  echo "  git rebase --continue"
  echo ""
  echo "Or abort with:"
  echo "  git rebase --abort"
  exit 1
fi
