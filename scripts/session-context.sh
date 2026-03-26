#!/usr/bin/env bash
# SessionStart hook: inject worker context when running in a linked worktree.
# If .worktree-task.md exists in the worktree root, output task context and
# instructions for the worker agent. Otherwise, output nothing.

set -euo pipefail

# Check if we're in a linked worktree (.git is a file pointing to the main repo)
git_path=".git"
if [[ ! -f "$git_path" ]]; then
  # Not a linked worktree (either main worktree or not a git repo) — no context
  exit 0
fi

# Check for task file
task_file=".worktree-task.md"
if [[ ! -f "$task_file" ]]; then
  exit 0
fi

# We're in a worker worktree with a task — inject context
branch=$(git branch --show-current 2>/dev/null || echo "unknown")
task_content=$(cat "$task_file")

# Check if task file includes Agent Team instructions
has_agent_teams=false
if grep -q "^## Agent Team Instructions" "$task_file" 2>/dev/null; then
  has_agent_teams=true
fi

# Read workspace metadata if available (written by /devmux:spawn)
workspace_json=".devmux-workspace.json"
browser_surface=""
plan_tasks=""
if [[ -f "$workspace_json" ]]; then
  browser_surface=$(grep -o '"browser_surface"[[:space:]]*:[[:space:]]*"[^"]*"' "$workspace_json" | head -1 | sed 's/.*: *"//;s/"//')
  plan_tasks=$(grep -o '"plan_tasks"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$workspace_json" | head -1 | sed 's/.*: *//;s/[][]//g;s/"//g')
fi

cat <<EOF
## Worker Agent Context

You are a **worker agent** in a worktree-based multi-agent development workflow.

**Branch**: \`$branch\`
EOF

# Include plan task IDs if available
if [[ -n "$plan_tasks" ]]; then
  echo "**Plan tasks**: $plan_tasks"
fi

# Include browser surface ref if available
if [[ -n "$browser_surface" ]]; then
  echo "**Browser surface**: \`$browser_surface\`"
fi

cat <<EOF

### Your Task

$task_content

### Reporting Progress

Use cmux sidebar to report your status to the master agent:

- \`cmux set-progress <0.0-1.0> --label "<phase>"\` — update progress (0.0 = started, 1.0 = done)
- \`cmux set-status status "<message>" --icon "hammer"\` — set a short status message (key=value format)
- \`cmux log --level info --source "$branch" -- "<message>"\` — append to sidebar log

Report progress at natural milestones (after completing a subtask, fixing a bug, etc.).

### Accessing Dev Server Output

Your dev server is running in a companion pane. Read its output via:

- \`cmux read-screen --surface <dev-surface> --lines 50 --scrollback\` — recent terminal output
- \`cat .devmux.log\` — full log history (dev server output is tee'd here)
EOF

# Include browser-specific instructions with the correct surface ref
if [[ -n "$browser_surface" ]]; then
  cat <<EOF
- \`cmux browser console list --surface $browser_surface\` — browser console messages
- \`cmux browser errors list --surface $browser_surface\` — browser-side errors
- \`cmux browser snapshot --surface $browser_surface --interactive\` — DOM/accessibility tree
- \`cmux browser screenshot --surface $browser_surface\` — visual screenshot
EOF
else
  cat <<EOF
- \`cmux browser console list\` — browser console messages
- \`cmux browser errors list\` — browser-side errors
EOF
fi

# Agent Teams preamble if task file includes team instructions
if [[ "$has_agent_teams" == "true" ]]; then
  cat <<EOF

### Agent Teams

Your task file includes **Agent Team Instructions**. You should create an Agent Team
as described in the instructions below. Use in-process mode (the default) — do NOT
use split-pane mode, as cmux handles the visual layout.

Follow the workflow in the Agent Team Instructions section of your task carefully.
The tester teammate is REQUIRED — do not skip testing. You must not signal completion
(progress 1.0) until all tests pass.
EOF
fi

cat <<EOF

### When Done

1. Ensure all tests pass and lint/check is clean
2. Commit all changes on this branch
3. Push and create a PR: \`gh pr create --fill\`
4. Set progress to 1.0: \`cmux set-progress 1.0 --label "Tests pass, PR ready"\`
5. Set PR status: \`cmux set-status pr "<PR-URL>" --icon "pull-request"\`
6. Set status to done: \`cmux set-status status "done" --icon "checkmark"\`
7. The master agent will handle merging via \`/devmux:harvest\`
EOF
