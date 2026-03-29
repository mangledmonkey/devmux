# Architecture Reference (v2)

Deep-dive into the devmux plugin architecture. See also [agent-teams.md](agent-teams.md) and [browser-loop.md](browser-loop.md).

## Tool Stack

### worktrunk (`wt`)
Git worktree lifecycle manager. Handles:
- `wt switch --create <branch>` — create worktree from branch
- `wt switch --no-cd` — create without changing directory (for master orchestration)
- `wt list --format=json` — programmatic worktree listing with status, URLs, CI
- `wt merge` — squash + rebase + pre-merge hooks + merge + cleanup
- `wt remove` — clean worktree removal
- `{{ branch | hash_port }}` — deterministic port allocation (10000-19999)
- `.config/wt.toml` — project-level hooks (post-create, post-start, pre-merge, etc.)

### cmux
macOS native terminal with visual workspace management:
- **Windows/Workspaces/Panes/Surfaces** — hierarchical topology
- **Browser panels** — WKWebView-based browser surfaces alongside terminals
- **Sidebar** — status, progress, and log display per workspace
- **send/read-screen** — terminal automation (send keystrokes, read output)
- **browser automation** — snapshot, click, fill, evaluate JS
- **Short refs** — `workspace:N`, `pane:N`, `surface:N` for deterministic targeting

### zmx (optional)
Session persistence layer:
- Wraps processes so they survive terminal/cmux crashes
- `zmx attach <name> <command>` — attach to session (creates if needed), run command
- `zmx attach <name>` — reattach after crash
- `zmx list` — show active sessions
- Not a multiplexer — just persistence

### Claude Code
AI agent running in each workspace:
- Master session plans and orchestrates via `.devmux-plan.md`
- Worker sessions execute focused tasks
- SessionStart hook injects task context in worktrees
- Workers read `.worktree-task.md` for their assignment
- Workers use Agent Teams (in-process mode) for sub-task coordination

### Claude Code Agent Teams (within workers)
Sub-task coordination layer running inside each worker session:
- **In-process mode only** — cmux handles the visual layer, not tmux
- Shared task list with dependency resolution
- Inter-teammate messaging (mailbox)
- Quality gate hooks: `TaskCompleted`, `TeammateIdle`
- Plan approval flow for reviewer teammates
- Teammates: tester, reviewer, security (adaptive by task type)

## Worker Workspace Layouts

### Web layout (3-pane) — web frameworks with dev servers
```
┌─────────────────┬──────────────────┐
│                 │ cmux Browser     │
│ Claude Code     │ localhost:port   │
│ (worker agent   │ (~80% height)    │
│  + Agent Team)  ├──────────────────┤
│                 │ Dev Server logs  │
│                 │ (~20% height)    │
└─────────────────┴──────────────────┘
```

### Tool layout (2-pane) — CLIs, plugins, libraries
```
┌─────────────────┬──────────────────┐
│ Claude Code     │ Utility terminal │
│ (worker agent   │ (tests, builds)  │
│  + Agent Team)  │                  │
└─────────────────┴──────────────────┘
```

### Minimal layout (1-pane) — documentation-only tasks
```
┌────────────────────────────────────┐
│ Claude Code (solo worker)          │
└────────────────────────────────────┘
```

Browser can be added on demand to any layout: `cmux browser open <url>`

## Data Flow

```
Master plans:
  1. /devmux:plan "description"           →  analyzes codebase
  2. Write .devmux-plan.md                →  tasks with dependencies, file ownership

Master spawns worker:
  1. wt switch --create <branch> --no-cd  →  creates worktree (hooks: npm ci, dev server)
  2. Write .worktree-task.md              →  task + Agent Teams instructions
  3. Write .devmux-workspace.json         →  cmux surface refs for worker
  4. cmux new-workspace + browser + split →  3-pane layout
  5. cmux send (dev server)               →  start dev server
  6. cmux send (claude)                   →  launch worker agent
  7. Update .devmux-plan.md               →  tasks → in_progress

Worker operates (with Agent Team):
  1. SessionStart hook reads .worktree-task.md  →  context + team instructions
  2. Worker creates Agent Team (tester + reviewer, in-process mode)
  3. Lead decomposes into subtasks on shared task list
  4. Tester writes tests alongside implementation
  5. Lead runs browser feedback loops: snapshot / console / errors
  6. Lead reports: cmux set-progress / set-status / log
  7. All tests pass → commit, push, gh pr create
  8. cmux set-progress 1.0, set-status pr "<URL>"

Master harvests:
  1. Rebase onto main (tiered conflict resolution)
  2. wt merge  →  squash + pre-merge hooks + merge + cleanup
  3. cmux close-workspace + zmx kill
  4. Update .devmux-plan.md  →  tasks → merged
  5. Proactively rebase active workers behind main
  6. Report unblocked tasks, suggest next spawns
```

## Worker Log Access

Workers can read dev server output three ways:

1. **Terminal output** (live, recent lines):
   ```bash
   cmux read-screen --surface <dev-surface> --lines 50 --scrollback
   ```

2. **Log file** (full history):
   ```bash
   cat .devmux.log
   ```
   The dev server is started with `2>&1 | tee .devmux.log`.

3. **Browser console/errors**:
   ```bash
   cmux browser console list
   cmux browser errors list
   ```

## Port Allocation

Worktrunk's `{{ branch | hash_port }}` filter generates deterministic ports:
- Input: branch name
- Output: port in range 10000-19999
- Hash is stable: same branch always gets the same port
- Configured in `.config/wt.toml`:
  ```toml
  [post-start]
  server = "npm run dev -- --port {{ branch | hash_port }}"

  [list]
  url = "http://localhost:{{ branch | hash_port }}"
  ```

## Session Persistence with zmx

When zmx is available, worker Claude Code sessions are wrapped:
```bash
zmx attach <branch-name> claude
```

Benefits:
- If cmux crashes (known Intel Mac bug with split panes), the Claude session survives
- Relaunch cmux, then `zmx attach <branch-name>` to reconnect
- Worker's full conversation context is preserved

Without zmx, sessions run directly in cmux panes. If cmux crashes, sessions are lost.

## Bare Repo Model

For worktree-heavy workflows, repos use bare repo layout:
```
project/
├── project          (bare repo — no working directory)
├── project.main     (main worktree)
├── project.feature  (feature worktree)
└── project.fix      (bugfix worktree)
```

Benefits:
- All worktrees are peers (no "main worktree" blocking operations)
- Clean separation: bare repo holds git data, worktrees hold code
- Pattern matches worktrunk's default path template

Created via `/devmux:clone` or by running `clone-bare.sh` directly.

Critical git config applied to bare repos:
- `remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"` — fetch all remote branches
- `core.logallrefupdates true` — enable reflog
- `push.default current` — push current branch without explicit remote
- `worktree.guessRemote true` — auto-track remote branches

## Generic Project Adaptation

The `/devmux:init` command detects project type and generates appropriate `.config/wt.toml`. Supported project types:

| Type | Detection | Package Manager | Dev Server |
|------|-----------|----------------|------------|
| Node.js/SvelteKit | `package.json` + `@sveltejs/kit` | npm/pnpm/yarn/bun | `npm run dev --port` |
| Node.js/Next.js | `package.json` + `next` | npm/pnpm/yarn/bun | `npm run dev -p` |
| Node.js/Vite | `package.json` + `vite` | npm/pnpm/yarn/bun | `npm run dev --port` |
| Rust | `Cargo.toml` | cargo | varies |
| Python | `pyproject.toml` | poetry/uv/pip | varies |
| Go | `go.mod` | go | varies |
| Ruby | `Gemfile` | bundler | varies |
| Java | `pom.xml`/`build.gradle` | maven/gradle | varies |

The generated hooks adapt to what's available (only adds test/lint/check hooks if the project has those scripts).
