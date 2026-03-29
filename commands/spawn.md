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
   **Verify**: Check that the command succeeded (exit code 0). If it fails, report the error to the user and **stop** — do not continue to Phase B. Common failures:
   - Branch already exists: suggest a different name or `wt switch <branch>` to reuse
   - Uncommitted changes: suggest committing or stashing first
   - Disk full: report the error

2. **Get worktree info** from worktrunk's JSON output:
   ```bash
   wt list --format=json
   ```
   Parse the JSON to find the entry matching `<branch>`. Extract:
   - `path` — the worktree directory (**required** — stop if not found; worktree creation likely failed)
   - `url` — the dev server URL (optional, includes hash_port from `.config/wt.toml`)

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
   - **UI component** (files contain `component`, `stories`, `.svelte`, `.tsx`, `.vue`, routes with UI): lead + tester (unit + Storybook) + reviewer + security
   - **API/backend** (files contain `server`, `api`, `handler`, database, auth): lead + tester (API tests) + reviewer + security
   - **Infrastructure/config** (config files, build scripts, CI, tooling): lead + tester (smoke tests) + security
   - **Documentation** (only `.md` files): solo (no team)

   Security is included on **all code tasks** — it audits for secrets, PII exposure, injection, auth/authz issues, and insecure data handling regardless of whether the code is frontend, backend, or infrastructure.

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
   - **security**: Reviews ALL code changes for security vulnerabilities. Does NOT
     modify code — reports findings to the lead, who routes fixes to the implementer.
     See the Security Review Protocol below.

   ### Workflow
   1. Break the task into subtasks. For each implementation subtask, create a
      corresponding test subtask that depends on it.
   2. Implementer and tester work through the shared task list.
   3. When implementation is complete, assign the security teammate to review
      all changed files (full diff from base branch).
   4. If security finds CRITICAL or HIGH issues: route fixes to implementer,
      then re-review. Max 2 remediation cycles before escalating to human.
   5. Run the full test suite: `<test_command>`
   6. If tests fail, create fix tasks and iterate until green.
   7. Run lint/check: `<lint_command>` / `<check_command>`
   <If layout is web:>
   8. Use cmux browser commands for visual feedback (browser panel at localhost:<port>).
      - `cmux browser snapshot --interactive` — get DOM/accessibility tree
      - `cmux browser console list` — check console output
      - `cmux browser errors list` — check for errors
   9. Only after ALL tests, checks, and security review pass: commit, push,
      create PR via `gh pr create`.
   10. Report: `cmux set-progress 1.0 --label "Tests pass, PR ready"`

   DO NOT signal completion until tests pass AND security review is PASS or PASS WITH NOTES.

   ### Security Review Protocol

   The security teammate systematically checks every code change for:

   **Always check:**
   - **Injection**: SQL, XSS, command, template injection. Trace all user input
     from source (HTTP params, form fields, API bodies) to sink (DB queries, HTML
     rendering, system commands). Every path must have sanitization/parameterization.
   - **Secrets**: Hardcoded API keys, tokens, passwords, private keys, connection
     strings. Look for high-entropy strings, known prefixes (sk-, AKIA, ghp_, xoxb-,
     Bearer), and files that should not be committed (.env, *.pem, *.key).
   - **Auth/Authz**: Endpoints performing state changes must require authentication.
     Resource access must verify the requesting user owns/has permission to the
     requested resource. Check JWT handling, session management, CSRF protection.
   - **Data exposure**: PII and sensitive data must not be logged, included in error
     responses, stored unencrypted, or passed in URL parameters.

   **Check when relevant:**
   - **Supply chain**: New dependencies pinned, well-known, not typosquatting.
   - **Cryptography**: Strong algorithms (no MD5/SHA1 for security), secure random
     (no Math.random for tokens), proper modes.
   - **LLM security**: If code interacts with LLMs — prompt injection defenses,
     output sanitization, system prompt protection.
   - **File operations**: Path traversal checks on user-supplied filenames.
   - **Deserialization**: Untrusted data deserialized safely.

   **Severity classification:**
   - **CRITICAL**: Directly exploitable (RCE, data breach, no preconditions). Block merge.
   - **HIGH**: Exploitable with preconditions or systemic auth failure. Block merge.
   - **MEDIUM**: Increases attack surface, not directly exploitable. Report, recommend fix.
   - **LOW**: Hardening suggestion. Report as improvement.

   **Report format** for each finding:
   - File and line numbers
   - CWE category
   - Description (what, why, how exploited)
   - Evidence (the problematic code)
   - Remediation (corrected code)
   - Test suggestion (for the tester teammate to verify the fix)

   **Verdict**: PASS (no Critical/High) | FAIL (Critical/High present) | PASS WITH NOTES (Medium/Low only)
   ```

   Replace `<test_framework>`, `<test_command>`, `<lint_command>`, `<check_command>` with actual values from the project context. Omit lines for tools that don't exist (e.g., no Storybook line if `HAS_SCRIPT_STORYBOOK` is false). Omit the cmux browser steps if layout is `tool` or `minimal`.

### Phase B — Build cmux workspace

Execute these steps sequentially, using `cmux tree` after splits to discover surface refs.

**Important**: All cmux commands targeting the spawned workspace must include `--workspace <ref>` since the master session's own `CMUX_WORKSPACE_ID` points to a different workspace.

#### Determine layout type

Before building the workspace, decide the layout based on project type:

- **Web layout** (3-pane): If the project has a dev server (`HAS_SCRIPT_DEV=true`) — this is the default for web frameworks (SvelteKit, Next.js, Vite, etc.)
- **Tool layout** (2-pane): If the project has no dev server, or is a CLI tool, plugin, library, or non-web project. Left pane: Claude Code, right pane: general terminal for running commands/tests.
- **Minimal layout** (1-pane): If `--solo` is set and the task is documentation-only. Just Claude Code.

The browser and dev server panes can always be added later on demand via `cmux browser open` and `cmux new-split`.

#### Steps for all layouts

6. **Create workspace** with the worktree as working directory:
   ```bash
   cmux --json new-workspace --cwd <worktree_path>
   ```
   Parse the output for the workspace ref (e.g., `OK workspace:N` — extract `workspace:N`).

   **If this fails** (cmux not running, path doesn't exist): report the error and **stop**. The worktree was created in Phase A — tell the user they can launch the worker manually with `cd <worktree_path> && claude`.

7. **Rename workspace** to the branch name:
   ```bash
   cmux rename-workspace --workspace <ref> "<branch>"
   ```

8. **Discover initial topology** to find the terminal surface ref:
   ```bash
   cmux tree --workspace <ref>
   ```
   Note the surface ref — this is the left pane where Claude Code will run.

#### Web layout (3-pane): dev server + browser

9. **Open browser** in the workspace (creates a right split automatically):
   ```bash
   cmux --json browser open "http://localhost:<port>" --workspace <ref>
   ```
   Note the browser's `pane_ref` — this is the right pane.

   **If browser open fails**: Fall back to **tool layout** instead (the browser can be opened later once the dev server is running). Continue with the tool layout steps below and write `"layout": "tool"` (not `"web"`) to `.devmux-workspace.json`.

10. **Split right pane** for dev server terminal below the browser:
    ```bash
    cmux --json new-split down --workspace <ref>
    ```

11. **Resize browser pane** so the dev server pane is ~20% of the right column. The dev server pane is for log monitoring, not interaction:
    ```bash
    cmux resize-pane --pane <browser_pane> --workspace <ref> -D --amount 300
    ```
    This grows the browser pane downward, pushing the dev server to ~20%. The amount of 300 pixels works reliably across typical window sizes (adjusts a ~50/50 split to ~80/20).

12. **Discover final topology**:
    ```bash
    cmux tree --workspace <ref>
    ```
    The full 3-pane layout looks like:
    ```
    └── workspace workspace:N "<branch>"
        ├── pane pane:A [focused]
        │   └── surface surface:A [terminal] "..." [selected]    ← Claude Code (left)
        ├── pane pane:B
        │   └── surface surface:B [browser] "..." [selected]     ← Browser (right, ~80%)
        └── pane pane:C
            └── surface surface:C [terminal] "..." [selected]    ← Dev server (right, ~20%)
    ```

13. **Start dev server** in the bottom-right pane:
    ```bash
    cmux send --workspace <ref> --surface <dev_surface> "cd <worktree_path> && npm run dev -- --port <port> 2>&1 | tee .devmux.log\n"
    ```
    Adapt the command based on the project type detected by `/init`. Use the appropriate dev command and port flag from `.config/wt.toml`.

#### Tool layout (2-pane): no dev server or browser by default

9. **Split for a utility terminal** on the right:
   ```bash
   cmux --json new-split right --workspace <ref>
   ```

10. **Discover topology**:
    ```bash
    cmux tree --workspace <ref>
    ```
    Layout:
    ```
    └── workspace workspace:N "<branch>"
        ├── pane pane:A [focused]
        │   └── surface surface:A [terminal] "..." [selected]    ← Claude Code (left)
        └── pane pane:B
            └── surface surface:B [terminal] "..." [selected]    ← Utility terminal (right)
    ```
    The utility terminal is available for running tests, builds, or any commands. A browser can be opened on demand later with `cmux browser open <url> --workspace <ref>`.

#### Minimal layout (1-pane): documentation tasks

Skip splitting entirely. The workspace has a single terminal pane for Claude Code.

#### Save metadata and launch (all layouts)

14. **Save workspace metadata** to the worktree for the worker's SessionStart hook:
    Write `<worktree_path>/.devmux-workspace.json` using the Write tool:
    ```json
    {
      "workspace_ref": "<workspace_ref>",
      "browser_surface": "<browser_surface_ref or null>",
      "claude_surface": "<left_surface_ref>",
      "dev_surface": "<dev_surface_ref or null>",
      "utility_surface": "<utility_surface_ref or null>",
      "port": "<port or null>",
      "branch": "<branch>",
      "layout": "<web|tool|minimal>",
      "plan_tasks": ["1.1", "1.2"]
    }
    ```

15. **Set sidebar metadata**:
    ```bash
    cmux set-status task "<task description>" --icon "hammer" --workspace <ref>
    cmux set-status branch "<branch>" --icon "git-branch" --workspace <ref>
    cmux set-progress 0.0 --label "Spawned" --workspace <ref>
    cmux log --level info --source "devmux" --workspace <ref> -- "Spawned worker for: <task description>"
    ```
    Only set the port status if a dev server is running:
    ```bash
    cmux set-status port "<port>" --icon "globe" --workspace <ref>
    ```

16. **Launch Claude Code** in the left pane. Use zmx for session persistence (critical for Agent Teams interactivity — the user must be able to switch to the workspace and interact with the Claude session and its teammates):
    ```bash
    which zmx 2>/dev/null
    ```
    - **With zmx** (recommended): `cmux send --workspace <ref> --surface <left_surface> "zmx attach <branch> claude\n"`
    - **Without zmx**: `cmux send --workspace <ref> --surface <left_surface> "cd <worktree_path> && claude\n"`

    zmx is strongly recommended because it provides session persistence AND allows the user to switch to the workspace and interact with the Claude session and its Agent Team teammates via `Shift+Down`. The devmux plugin is expected to be loaded globally (via settings or Skills Marketplace), so no `--plugin-dir` flag is needed.

### Phase C — Update plan (if applicable)

17. **Update plan file** if `--plan-tasks` was provided and `.devmux-plan.md` exists:
    Read `.devmux-plan.md` with the Read tool. For each linked plan task, update:
    - `**Status**`: `queued` → `in_progress`
    - `**Branch**`: `—` → `<branch>`
    - `**Worker**`: `—` → `<workspace_ref>`

    Write the updated plan back using the Write tool.

### Report

Output a summary:
- Workspace: `<ref>` (branch name)
- Worktree path: `<path>`
- Layout: `<web|tool|minimal>`
- Dev server: `http://localhost:<port>` (or "none — add browser on demand with `cmux browser open`")
- Task: `<description>`
- Plan tasks: `<linked task IDs>` (or "none")
- Agent Team: `<composition>` (e.g., "lead + tester + reviewer + security" or "solo")
- Worker Claude Code is launching in the left pane (via zmx if available)
- To interact with the worker's Agent Team: switch to the cmux workspace tab, then use `Shift+Down` to cycle between teammates

## Layout Reference

### Web layout (3-pane) — web frameworks with dev servers
```
┌─────────────────┬──────────────────┐
│                 │ cmux Browser     │
│ Claude Code     │ localhost:<port> │
│ (worker agent   │ (~80% height)    │
│  + Agent Team)  ├──────────────────┤
│                 │ Dev Server logs  │
│                 │ (~20% height)    │
└─────────────────┴──────────────────┘
```

### Tool layout (2-pane) — CLIs, plugins, libraries
```
┌─────────────────┬──────────────────┐
│                 │                  │
│ Claude Code     │ Utility terminal │
│ (worker agent   │ (tests, builds,  │
│  + Agent Team)  │  commands)       │
│                 │                  │
└─────────────────┴──────────────────┘
```
Browser can be added on demand: `cmux browser open <url> --workspace <ref>`

### Minimal layout (1-pane) — documentation-only tasks
```
┌────────────────────────────────────┐
│                                    │
│ Claude Code (solo worker)          │
│                                    │
└────────────────────────────────────┘
```
