#!/usr/bin/env bash
# Clone a repo as a bare repo with worktree-friendly layout.
# Portable bash equivalent of git-clone-bare.fish.
#
# Usage: clone-bare.sh <url> [name]
# Creates: <name>/<name> (bare repo) with worktrees as siblings

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: clone-bare.sh <url> [name]"
  echo ""
  echo "Creates: <name>/<name> (bare repo) with worktrees as <name>/<branch>"
  exit 1
fi

url="$1"

# Parse repo name from URL if not provided
if [[ $# -ge 2 ]]; then
  name="$2"
else
  name=$(basename "$url" .git)
fi

if [[ -d "$name" ]]; then
  echo "Error: directory '$name' already exists"
  exit 1
fi

echo "Cloning $url into $name/$name (bare)..."
mkdir -p "$name"

if ! git clone --bare "$url" "$name/$name"; then
  rmdir "$name" 2>/dev/null || true
  exit 1
fi

# Apply critical config fixes for worktree workflows
echo "Applying config fixes..."
git -C "$name/$name" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git -C "$name/$name" config core.logallrefupdates true
git -C "$name/$name" config push.default current
git -C "$name/$name" config worktree.guessRemote true

# Populate remote tracking refs
echo "Fetching remote refs..."
git -C "$name/$name" fetch origin

echo ""
echo "Done! Bare repo at $name/$name"
echo ""
echo "Next steps:"
echo "  cd $name/$name"
echo "  wt switch main        # create main worktree"
echo "  wt switch --create feature-name  # start a feature"

# Output bare repo path for programmatic use
echo "BARE_REPO_PATH=$name/$name"
