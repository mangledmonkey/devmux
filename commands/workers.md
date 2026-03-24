---
description: List active worker worktrees and their status
allowed-tools: [Bash, Read]
---

# /devmux:workers

Show a dashboard of all active worker worktrees with their status, task, and progress.

## What to do

1. **List all worktrees** with JSON output:
   ```bash
   wt list --format=json
   ```

2. **List all cmux workspaces** to match against worktree branches:
   ```bash
   cmux --json list-workspaces
   ```
   The response is:
   ```json
   {
     "workspaces": [
       { "ref": "workspace:N", "title": "...", "current_directory": "...", "index": N }
     ]
   }
   ```

3. **For each non-main worktree** (where `is_main` is false):

   a. Read the task file if it exists using the Read tool:
      `<path>/.worktree-task.md`
      Extract the task description from the first `# Task:` heading.

   b. Find the matching cmux workspace by comparing the workspace `title` to the branch name.

   c. If a matching workspace exists, get sidebar state:
      ```bash
      cmux sidebar-state --workspace <workspace_ref>
      ```
      This returns key=value pairs:
      ```
      progress=0.60 Implementing
      status_count=1
        task=Implement login flow icon=hammer
      log_count=3
        [info] Spawned worker for: ...
      ```
      Extract `progress` and status entries.

4. **Extract info from wt list JSON** for each worktree:
   - `branch` — the branch name
   - `path` — worktree directory
   - `url` — dev server URL (if configured)
   - `url_active` — whether the port is listening
   - `working_tree.modified` — has uncommitted changes
   - `main.ahead` — commits ahead of main

5. **Present a formatted table**:

   ```
   Branch          | Status    | Progress | Task                          | Port  | Commits
   feature-auth    | coding    | 60%      | Implement login flow          | 14523 | 3 ahead
   fix-sidebar     | done      | 100%     | Fix sidebar overflow          | 11847 | 1 ahead
   refactor-db     | spawned   | 0%       | Refactor database queries     | 16290 | 0 ahead
   ```

   - **Status**: from cmux sidebar status entries (or "no workspace" if no cmux workspace found)
   - **Progress**: from cmux sidebar (0-100%)
   - **Task**: first line of `.worktree-task.md`
   - **Port**: extracted from URL
   - **Commits**: from `main.ahead`

6. If no non-main worktrees exist, report "No active workers."
