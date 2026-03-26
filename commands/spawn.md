---
description: Spawn a worker agent in a new worktree with cmux workspace
argument-hint: <branch> "<task description>" [--plan-tasks 1.1,1.2] [--solo|--team]
allowed-tools: [Bash, Read, Write]
---

# /devmux:spawn

Create a new worktree, build a cmux workspace with browser and dev server, and launch a worker Claude Code session with optional Agent Teams instructions.

## What to do

Parse `$ARGUMENTS` for:
- **branch** — the branch name (required)
- **task description** — quoted string (required). Example: `feature-auth "Implement login flow"`
- **--plan-tasks 1.1,1.2** — optional comma-separated plan task IDs to link
- **--solo** — force no Agent Team (worker runs alone)
- **--team** — force full Agent Team (tester + reviewer + security)

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

3. **Read project context** for the task file. If `.devmux-plan.md` exists, read it to extract:
   - Project Context section (test framework, test/lint/check commands, Storybook availability)
   - If `--plan-tasks` was provided, extract the task descriptions, files, and acceptance criteria from the referenced plan tasks

   If no plan exists, detect project context:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh <worktree_path>
   ```

4. **Determine team composition**. Unless `--solo` or `--team` is specified, auto-detect from the task description and file paths:
   - **UI component** (files contain `component`, `stories`, `.svelte`, `.tsx`, `.vue`, routes with UI): lead + tester (unit + Storybook) + reviewer
   - **API/backend** (files contain `server`, `api`, `handler`, database, auth): lead + tester (API tests) + reviewer + security
   - **Infrastructure/config** (config files, build scripts, CI, tooling): lead + tester (smoke tests)
   - **Documentation** (only `.md` files): solo (no team)

   If `--solo`: skip Agent Teams instructions entirely.
   If `--team`: use full team (tester + reviewer + security).

5. **Write task file** to the worktree using the Write tool. Create `<worktree_path>/.worktree-task.md`:

   ```markdown
   # Task: <task description>

   **Branch**: <branch>
   **Parent branch**: <current branch at spawn time>
   **Spawned**: <date>
   **Plan tasks**: <1.1, 1.2 — or "none">

   ## Description

   <task description — if plan tasks were linked, include their full descriptions and file lists>

   ## Acceptance Criteria

   - [ ] Implementation complete
   - [ ] Tests pass
   - [ ] No lint errors
   - [ ] Code reviewed (if team includes reviewer)
   ```

   **If team composition is NOT solo**, append the Agent Teams section:

   ```markdown
   ## Agent Team Instructions

   Create an agent team for this task. Spawn teammates:

   - **tester** (REQUIRED): Writes unit tests alongside implementation, not after.
     Use <test_framework> (`<test_command>`). <If Storybook: "Write Storybook stories
     for each visual state/variant."> Every acceptance criterion must have a
     corresponding test. Run the test suite and report results.
   <If team includes reviewer:>
   - **reviewer**: Reviews code for quality, patterns, accessibility, performance.
     Require plan approval before making changes.
   <If team includes security:>
   - **security**: Audits for XSS, CSRF, injection, auth bypass. Reports with severity.

   ### Workflow
   1. Break the task into subtasks. For each implementation subtask, create a
      corresponding test subtask that depends on it.
   2. Implementer and tester work through the shared task list.
   3. When all subtasks done, run the full test suite: `<test_command>`
   4. If tests fail, create fix tasks and iterate until green.
   5. Run lint/check: `<lint_command>` / `<check_command>`
   6. Use cmux browser commands for visual feedback (browser panel at localhost:<port>).
      - `cmux browser snapshot --interactive` — get DOM/accessibility tree
      - `cmux browser console list` — check console output
      - `cmux browser errors list` — check for errors
   7. Only after ALL tests and checks pass: commit, push, create PR via `gh pr create`.
   8. Report: `cmux set-progress 1.0 --label "Tests pass, PR ready"`

   DO NOT signal completion until tests pass.
   ```

   Replace `<test_framework>`, `<test_command>`, `<lint_command>`, `<check_command>` with actual values from the project context. Omit lines for tools that don't exist (e.g., no Storybook line if `HAS_SCRIPT_STORYBOOK` is false).

### Phase B — Build cmux workspace

Execute these steps sequentially, using `cmux tree` after splits to discover surface refs.

**Important**: All cmux commands targeting the spawned workspace must include `--workspace <ref>` since the master session's own `CMUX_WORKSPACE_ID` points to a different workspace.

6. **Create workspace** with the worktree as working directory:
   ```bash
   cmux --json new-workspace --cwd <worktree_path>
   ```
   Parse the output for the workspace ref (e.g., `OK workspace:N` — extract `workspace:N`).

7. **Rename workspace** to the branch name:
   ```bash
   cmux rename-workspace --workspace <ref> "<branch>"
   ```

8. **Discover initial topology** to find the terminal surface ref:
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

9. **Open browser** in the workspace (creates a right split automatically):
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

10. **Split right pane** for dev server terminal below the browser:
   ```bash
   cmux --json new-split down --workspace <ref>
   ```
   **Note**: This may crash cmux on Intel Macs due to a known bug. If the command fails or cmux becomes unresponsive, inform the user:
   > "cmux crashed during split (known Intel Mac bug). Please relaunch cmux. The worktree and task file are already created — re-run `/devmux:spawn` to retry the workspace setup, or continue with the 2-pane layout (terminal + browser)."

11. **Discover final topology**:
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

   If step 10 crashed and only 2 panes exist (terminal + browser), skip the dev server pane setup and note this in the report.

12. **Start dev server** in the bottom-right pane (if it exists):
    ```bash
    cmux send --workspace <ref> --surface <dev_surface> "cd <worktree_path> && npm run dev -- --port <port> 2>&1 | tee .devmux.log\n"
    ```
    Adapt the command based on the project type detected by `/init`. Use the appropriate dev command and port flag from `.config/wt.toml`.

13. **Save workspace metadata** to the worktree for the worker's SessionStart hook:
    Write `<worktree_path>/.devmux-workspace.json` using the Write tool:
    ```json
    {
      "workspace_ref": "<workspace_ref>",
      "browser_surface": "<browser_surface_ref>",
      "claude_surface": "<left_surface_ref>",
      "dev_surface": "<dev_surface_ref or null>",
      "port": <port>,
      "branch": "<branch>",
      "plan_tasks": ["1.1", "1.2"]
    }
    ```

14. **Set sidebar metadata**:
    ```bash
    cmux set-status task "<task description>" --icon "hammer" --workspace <ref>
    cmux set-status branch "<branch>" --icon "git-branch" --workspace <ref>
    cmux set-status port "<port>" --icon "globe" --workspace <ref>
    cmux set-progress 0.0 --label "Spawned" --workspace <ref>
    cmux log --level info --source "devmux" --workspace <ref> -- "Spawned worker for: <task description>"
    ```

15. **Launch Claude Code** in the left pane. Check if zmx is available:
    ```bash
    which zmx 2>/dev/null
    ```
    - **With zmx**: `cmux send --workspace <ref> --surface <left_surface> "zmx new <branch> -- claude\n"`
    - **Without zmx**: `cmux send --workspace <ref> --surface <left_surface> "cd <worktree_path> && claude\n"`

### Phase C — Update plan (if applicable)

16. **Update plan file** if `--plan-tasks` was provided and `.devmux-plan.md` exists:
    Read `.devmux-plan.md` with the Read tool. For each linked plan task, update:
    - `**Status**`: `queued` → `in_progress`
    - `**Branch**`: `—` → `<branch>`
    - `**Worker**`: `—` → `<workspace_ref>`

    Write the updated plan back using the Write tool.

### Report

Output a summary:
- Workspace: `<ref>` (branch name)
- Worktree path: `<path>`
- Dev server: `http://localhost:<port>`
- Task: `<description>`
- Plan tasks: `<linked task IDs>` (or "none")
- Agent Team: `<composition>` (e.g., "lead + tester + reviewer" or "solo")
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
