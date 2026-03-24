#!/usr/bin/env bash
# Detect project type and available tooling.
# Outputs key=value pairs for use by /init command.
#
# Usage: detect-project.sh [directory]
# Defaults to current directory if not specified.

set -euo pipefail

dir="${1:-.}"

# Resolve to absolute path for node require() compatibility
if [[ "$dir" != /* ]]; then
  dir="$(cd "$dir" && pwd)"
fi

# Detect package manager and project type
detect_node() {
  local pkg_manager="npm"
  local install_cmd="npm ci"
  local lock_file=""

  # Check lock files in priority order (npm > pnpm > yarn > bun)
  # npm's package-lock.json is checked first since it's most common
  # and projects may have stale lock files from other managers
  if [[ -f "$dir/package-lock.json" ]]; then
    lock_file="package-lock.json"
  elif [[ -f "$dir/pnpm-lock.yaml" ]]; then
    pkg_manager="pnpm"
    install_cmd="pnpm install --frozen-lockfile"
    lock_file="pnpm-lock.yaml"
  elif [[ -f "$dir/yarn.lock" ]]; then
    pkg_manager="yarn"
    install_cmd="yarn install --frozen-lockfile"
    lock_file="yarn.lock"
  elif [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
    pkg_manager="bun"
    install_cmd="bun install --frozen-lockfile"
    lock_file="bun.lockb"
  fi

  echo "PROJECT_TYPE=node"
  echo "PKG_MANAGER=$pkg_manager"
  echo "INSTALL_CMD=$install_cmd"
  echo "LOCK_FILE=$lock_file"

  # Check for available scripts in package.json
  if command -v node &>/dev/null && [[ -f "$dir/package.json" ]]; then
    local scripts
    scripts=$(node -e "
      const pkg = require('$dir/package.json');
      const s = pkg.scripts || {};
      const keys = ['dev', 'start', 'test', 'lint', 'check', 'build', 'format', 'storybook'];
      keys.forEach(k => { if (s[k]) console.log('HAS_SCRIPT_' + k.toUpperCase() + '=true'); });
    " 2>/dev/null || true)
    echo "$scripts"

    # Detect dev command with port support
    local dev_script
    dev_script=$(node -e "
      const pkg = require('$dir/package.json');
      const s = pkg.scripts || {};
      if (s.dev) console.log(s.dev);
    " 2>/dev/null || true)
    echo "DEV_SCRIPT=$dev_script"

    # Detect framework
    local deps
    deps=$(node -e "
      const pkg = require('$dir/package.json');
      const all = {...(pkg.dependencies||{}), ...(pkg.devDependencies||{})};
      console.log(Object.keys(all).join(','));
    " 2>/dev/null || true)

    if echo "$deps" | grep -q "@sveltejs/kit"; then
      echo "FRAMEWORK=sveltekit"
      echo "PORT_FLAG=--port"
    elif echo "$deps" | grep -q "next"; then
      echo "FRAMEWORK=nextjs"
      echo "PORT_FLAG=-p"
    elif echo "$deps" | grep -q "nuxt"; then
      echo "FRAMEWORK=nuxt"
      echo "PORT_FLAG=--port"
    elif echo "$deps" | grep -q "vite"; then
      echo "FRAMEWORK=vite"
      echo "PORT_FLAG=--port"
    else
      echo "FRAMEWORK=unknown"
      echo "PORT_FLAG=--port"
    fi
  fi
}

# Main detection logic
if [[ -f "$dir/package.json" ]]; then
  detect_node
elif [[ -f "$dir/Cargo.toml" ]]; then
  echo "PROJECT_TYPE=rust"
  echo "PKG_MANAGER=cargo"
  echo "INSTALL_CMD=cargo build"
  if grep -q "actix-web\|axum\|rocket\|warp" "$dir/Cargo.toml" 2>/dev/null; then
    echo "HAS_SCRIPT_DEV=true"
    echo "FRAMEWORK=rust-web"
  fi
elif [[ -f "$dir/pyproject.toml" ]]; then
  echo "PROJECT_TYPE=python"
  if [[ -f "$dir/poetry.lock" ]]; then
    echo "PKG_MANAGER=poetry"
    echo "INSTALL_CMD=poetry install"
  elif [[ -f "$dir/uv.lock" ]]; then
    echo "PKG_MANAGER=uv"
    echo "INSTALL_CMD=uv sync"
  elif [[ -f "$dir/Pipfile.lock" ]]; then
    echo "PKG_MANAGER=pipenv"
    echo "INSTALL_CMD=pipenv install"
  else
    echo "PKG_MANAGER=pip"
    echo "INSTALL_CMD=pip install -e ."
  fi
elif [[ -f "$dir/requirements.txt" ]]; then
  echo "PROJECT_TYPE=python"
  echo "PKG_MANAGER=pip"
  echo "INSTALL_CMD=pip install -r requirements.txt"
elif [[ -f "$dir/go.mod" ]]; then
  echo "PROJECT_TYPE=go"
  echo "PKG_MANAGER=go"
  echo "INSTALL_CMD=go mod download"
elif [[ -f "$dir/Gemfile" ]]; then
  echo "PROJECT_TYPE=ruby"
  echo "PKG_MANAGER=bundler"
  echo "INSTALL_CMD=bundle install"
elif [[ -f "$dir/pom.xml" ]]; then
  echo "PROJECT_TYPE=java"
  echo "PKG_MANAGER=maven"
  echo "INSTALL_CMD=mvn install"
elif [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
  echo "PROJECT_TYPE=java"
  echo "PKG_MANAGER=gradle"
  echo "INSTALL_CMD=gradle build"
else
  echo "PROJECT_TYPE=unknown"
  echo "PKG_MANAGER=unknown"
  echo "INSTALL_CMD="
fi
