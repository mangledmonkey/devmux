---
description: List active worker worktrees and their status
allowed-tools: [Bash, Read]
---

# /worktree-dev:workers

Show a dashboard of all active worker worktrees with their status, task, and progress.

## What to do

1. **List all worktrees** with JSON output:
   ```bash
   wt list --format=json
   ```

2. **For each non-main worktree** (where `is_main` is false):

   a. Read the task file if it exists:
   ```bash
   cat <path>/.worktree-task.md 2>/dev/null
   ```
   Extract the task description from the first `# Task:` heading.

   b. Check cmux workspace status. Try to find a workspace named after the branch:
   ```bash
   cmux list-workspaces
   ```
   Look for a workspace matching the branch name.

   c. If a matching workspace exists, check sidebar state:
   ```bash
   cmux sidebar-state --workspace <workspace_ref>
   ```
   This provides status, progress, and log entries set by the worker agent.

3. **Extract info from wt list JSON** for each worktree:
   - `branch` — the branch name
   - `path` — worktree directory
   - `url` — dev server URL (if configured)
   - `url_active` — whether the port is listening
   - `working_tree.modified` — has uncommitted changes
   - `main.ahead` — commits ahead of main

4. **Present a formatted table**:

   ```
   Branch          | Status    | Progress | Task                          | Port  | Commits
   feature-auth    | coding    | 60%      | Implement login flow          | 14523 | 3 ahead
   fix-sidebar     | done      | 100%     | Fix sidebar overflow          | 11847 | 1 ahead
   refactor-db     | spawned   | 0%       | Refactor database queries     | 16290 | 0 ahead
   ```

   - **Status**: from cmux sidebar (or "no workspace" if no cmux workspace found)
   - **Progress**: from cmux sidebar (0-100%)
   - **Task**: first line of `.worktree-task.md`
   - **Port**: extracted from URL
   - **Commits**: from `main.ahead`

5. If no non-main worktrees exist, report "No active workers."
