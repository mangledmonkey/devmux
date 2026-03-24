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

cat <<EOF
## Worker Agent Context

You are a **worker agent** in a worktree-based multi-agent development workflow.

**Branch**: \`$branch\`

### Your Task

$task_content

### Reporting Progress

Use cmux sidebar to report your status to the master agent:

- \`cmux set-progress <0.0-1.0>\` — update progress (0.0 = started, 1.0 = done)
- \`cmux set-status "<message>"\` — set a short status message
- \`cmux log "<message>"\` — append to sidebar log

Report progress at natural milestones (after completing a subtask, fixing a bug, etc.).

### Accessing Dev Server Output

Your dev server is running in a companion pane. Read its output via:

- \`cmux read-screen --surface <dev-surface> --lines 50 --scrollback\` — recent terminal output
- \`cat .worktree-dev.log\` — full log history (dev server output is tee'd here)
- \`cmux browser console list\` — browser console messages
- \`cmux browser errors list\` — browser-side errors

### When Done

1. Set progress to 1.0: \`cmux set-progress 1.0\`
2. Set status to "done": \`cmux set-status "done"\`
3. Ensure all changes are committed on this branch
4. The master agent will handle merging via \`/worktree-dev:harvest\`
EOF
