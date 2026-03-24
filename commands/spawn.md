---
description: Spawn a worker agent in a new worktree with cmux workspace
argument-hint: <branch> "<task description>"
allowed-tools: [Bash, Read, Write]
---

# /devmux:spawn

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

Execute these steps sequentially, using `cmux tree` after splits to discover surface refs.

**Important**: All cmux commands targeting the spawned workspace must include `--workspace <ref>` since the master session's own `CMUX_WORKSPACE_ID` points to a different workspace.

4. **Create workspace** with the worktree as working directory:
   ```bash
   cmux --json new-workspace --cwd <worktree_path>
   ```
   Parse the output for the workspace ref (e.g., `OK workspace:N` — extract `workspace:N`).

5. **Rename workspace** to the branch name:
   ```bash
   cmux rename-workspace --workspace <ref> "<branch>"
   ```

6. **Discover initial topology** to find the terminal surface ref:
   ```bash
   cmux tree --workspace <ref>
   ```
   Parse the tree output. The initial workspace has one pane with one terminal surface:
   ```
   └── workspace workspace:N "<branch>"
       └── pane pane:N [focused]
           └── surface surface:N [terminal] "..." [selected]
   ```
   Note the surface ref (e.g., `surface:N`) — this is the left pane where Claude Code will run.

7. **Open browser** in the workspace (creates a right split automatically):
   ```bash
   cmux --json browser open "http://localhost:<port>" --workspace <ref>
   ```
   This returns JSON:
   ```json
   {
     "surface_ref": "surface:N",
     "pane_ref": "pane:N",
     "placement_strategy": "split_right",
     "created_split": true,
     "workspace_ref": "workspace:N"
   }
   ```
   Note the browser's `pane_ref` — this is the right pane.

8. **Split right pane** for dev server terminal below the browser:
   ```bash
   cmux --json new-split down --workspace <ref>
   ```
   **Note**: This may crash cmux on Intel Macs due to a known bug. If the command fails or cmux becomes unresponsive, inform the user:
   > "cmux crashed during split (known Intel Mac bug). Please relaunch cmux. The worktree and task file are already created — re-run `/devmux:spawn` to retry the workspace setup, or continue with the 2-pane layout (terminal + browser)."

9. **Discover final topology**:
   ```bash
   cmux tree --workspace <ref>
   ```
   The full 3-pane layout looks like:
   ```
   └── workspace workspace:N "<branch>"
       ├── pane pane:A [focused]
       │   └── surface surface:A [terminal] "..." [selected]    ← Claude Code (left)
       ├── pane pane:B
       │   └── surface surface:B [browser] "..." [selected]     ← Browser (right-top)
       └── pane pane:C
           └── surface surface:C [terminal] "..." [selected]    ← Dev server (right-bottom)
   ```
   Extract the dev server surface ref (`surface:C`).

   If step 8 crashed and only 2 panes exist (terminal + browser), skip the dev server pane setup and note this in the report.

10. **Start dev server** in the bottom-right pane (if it exists):
    ```bash
    cmux send --workspace <ref> --surface <dev_surface> "cd <worktree_path> && npm run dev -- --port <port> 2>&1 | tee .devmux.log\n"
    ```
    Adapt the command based on the project type detected by `/init`. Use the appropriate dev command and port flag from `.config/wt.toml`.

11. **Set sidebar metadata**:
    ```bash
    cmux set-status task "<task description>" --icon "hammer" --workspace <ref>
    cmux set-status branch "<branch>" --icon "git-branch" --workspace <ref>
    cmux set-status port "<port>" --icon "globe" --workspace <ref>
    cmux set-progress 0.0 --label "Spawned" --workspace <ref>
    cmux log --level info --source "devmux" --workspace <ref> -- "Spawned worker for: <task description>"
    ```

12. **Launch Claude Code** in the left pane. Check if zmx is available:
    ```bash
    which zmx 2>/dev/null
    ```
    - **With zmx**: `cmux send --workspace <ref> --surface <left_surface> "zmx new <branch> -- claude\n"`
    - **Without zmx**: `cmux send --workspace <ref> --surface <left_surface> "cd <worktree_path> && claude\n"`

### Report

Output a summary:
- Workspace: `<ref>` (branch name)
- Worktree path: `<path>`
- Dev server: `http://localhost:<port>`
- Task: `<description>`
- Layout: 3-pane (or 2-pane if split crashed)
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
