#!/usr/bin/env bash
# Check availability of required and optional tools for worktree-dev workflow.
# Outputs status for each tool with install instructions for missing ones.

set -euo pipefail

status=0

check_tool() {
  local name="$1"
  local required="$2"
  local install_cmd="$3"
  local description="$4"

  if command -v "$name" &>/dev/null; then
    local version
    version=$("$name" --version 2>/dev/null | head -1 || echo "installed")
    echo "OK  $name — $version"
  else
    if [[ "$required" == "true" ]]; then
      echo "MISSING  $name (required) — $description"
      echo "         Install: $install_cmd"
      status=1
    else
      echo "MISSING  $name (optional) — $description"
      echo "         Install: $install_cmd"
    fi
  fi
}

echo "=== worktree-dev tool check ==="
echo ""

check_tool "wt" "true" \
  "brew install worktrunk && wt config shell install" \
  "Git worktree lifecycle manager (hooks, hash_port, switch/merge)"

check_tool "cmux" "true" \
  "Download from https://cmux.dev" \
  "Terminal workspace manager with browser, sidebar, and pane automation"

check_tool "zmx" "false" \
  "brew install neurosnap/tap/zmx" \
  "Session persistence — processes survive terminal/cmux crashes"

check_tool "git" "true" \
  "xcode-select --install" \
  "Git version control"

echo ""
if [[ $status -eq 0 ]]; then
  echo "All required tools available."
else
  echo "Some required tools are missing. Install them before proceeding."
fi

exit $status
