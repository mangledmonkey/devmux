---
description: Spawn a worker agent in a new worktree with cmux workspace
argument-hint: <branch> "<task description>"
allowed-tools: [Bash, Read, Write]
---

# /worktree-dev:spawn

Create a new worktree, build a cmux workspace with browser and dev server, and launch a worker Claude Code session.

## What to do

Parse `$ARGUMENTS` for the branch name and task description. The task should be quoted. Example: `feature-auth "Implement login flow with session management"`.

### Phase A — Create worktree

1. **Create the worktree** (master stays in current directory):
   ```bash
   wt switch --create <branch> --no-cd
   ```

2. **Get worktree info** from worktrunk's JSON output:
   ```bash
   wt list --format=json
   ```
   Parse the JSON to find the entry matching `<branch>`. Extract:
   - `path` — the worktree directory
   - `url` — the dev server URL (includes hash_port from `.config/wt.toml`)

   If `url` is present, extract the port from it. Otherwise fall back:
   ```bash
   wt step eval '{{ branch | hash_port }}'
   ```
   Note: run this from within the worktree context if needed.

3. **Write task file** to the worktree using the Write tool. Create `<worktree_path>/.worktree-task.md`:

   ```markdown
   # Task: <task description>

   **Branch**: <branch>
   **Parent branch**: <current branch at spawn time>
   **Spawned**: <date>

   ## Description

   <task description>

   ## Acceptance Criteria

   - [ ] Implementation complete
   - [ ] Tests pass
   - [ ] No lint errors
   ```

### Phase B — Build cmux workspace

Execute these steps sequentially, inspecting topology after splits to discover surface refs. **cmux may crash on Intel Macs during split operations** — if it does, inform the user to relaunch cmux and re-run the spawn.

4. **Create workspace**:
   ```bash
   cmux --json new-workspace
   ```
   Note the workspace ref from the output (e.g., `workspace:N`).

5. **Rename workspace** to the branch name:
   ```bash
   cmux rename-workspace --workspace <ref> "<branch>"
   ```

6. **Discover initial topology** to find the left pane surface:
   ```bash
   cmux list-panes --workspace <ref>
   cmux list-pane-surfaces --pane <left_pane_ref>
   ```
   Note the surface ref — this is the left pane (Claude Code will run here).

7. **Create right pane** with a split:
   ```bash
   cmux --json new-split right --panel <left_pane_ref>
   ```

8. **Discover topology** after split to find the right pane:
   ```bash
   cmux list-panes --workspace <ref>
   ```
   Identify the new pane (right side).

9. **Open browser** in the right pane:
   ```bash
   cmux --json browser open "http://localhost:<port>" --workspace <ref>
   ```

10. **Split right pane** for dev server:
    ```bash
    cmux --json new-split down --panel <right_pane_ref>
    ```

11. **Discover final topology** — now 3 areas exist:
    ```bash
    cmux list-panes --workspace <ref>
    ```
    Map out: left pane (Claude Code), right-top pane (browser), right-bottom pane (dev server).
    Get the dev server surface ref:
    ```bash
    cmux list-pane-surfaces --pane <bottom_right_pane_ref>
    ```

12. **Start dev server** in the bottom-right pane:
    ```bash
    cmux send --surface <dev_surface> "cd <worktree_path> && npm run dev -- --port <port> 2>&1 | tee .worktree-dev.log\n"
    ```
    Adapt the command based on the project type detected by `/init`. Use the appropriate dev command and port flag.

13. **Set sidebar metadata**:
    ```bash
    cmux set-status "spawned: <branch>"
    cmux set-progress 0.0
    cmux log "Task: <task description>"
    cmux log "Port: <port>"
    cmux log "Branch: <branch>"
    ```

14. **Launch Claude Code** in the left pane. Check if zmx is available:
    ```bash
    which zmx 2>/dev/null
    ```
    - **With zmx**: `cmux send --surface <left_surface> "zmx new <branch> -- claude\n"`
    - **Without zmx**: `cmux send --surface <left_surface> "cd <worktree_path> && claude\n"`

### Report

Output a summary:
- Workspace: `<ref>` (branch name)
- Worktree path: `<path>`
- Dev server: `http://localhost:<port>`
- Task: `<description>`
- Worker Claude Code is launching in the left pane

## Layout Reference

```
┌─────────────────┬──────────────────┐
│                 │ cmux Browser     │
│ Claude Code     │ localhost:<port> │
│ (worker agent)  │                  │
│                 ├──────────────────┤
│                 │ Dev Server logs  │
│                 │ :<port>          │
└─────────────────┴──────────────────┘
```
