# devmux

Claude Code plugin for multi-agent parallel development using [worktrunk](https://github.com/nicholasgasior/worktrunk) + [cmux](https://cmux.com).

A master Claude Code agent plans and decomposes work, then spawns worker agents — each in its own git worktree with a dedicated cmux workspace, browser panel, dev server, and sidebar status reporting.

```
┌─────────────────┬──────────────────┐
│                 │  cmux Browser    │
│  Claude Code    │  localhost:14523 │
│  (worker agent) │                  │
│                 ├──────────────────┤
│                 │  Dev Server      │
│                 │  :14523          │
└─────────────────┴──────────────────┘
  ↑ each worker gets this layout
```

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [worktrunk](https://github.com/nicholasgasior/worktrunk) (`wt`) | Worktree lifecycle, hooks, port allocation | `brew install worktrunk` |
| [cmux](https://cmux.com) | Terminal workspaces, browser panels, sidebar | Download from cmux.com |
| [Claude Code](https://claude.ai/code) | AI agent in each workspace | `npm install -g @anthropic-ai/claude-code` |
| [zmx](https://github.com/nicholasgasior/zmx) (optional) | Session persistence across crashes | `brew install neurosnap/tap/zmx` |

## Install

```bash
# Clone and use directly
git clone https://github.com/user/devmux.git
claude --plugin-dir ~/path/to/devmux

# Or add to an existing Claude Code session
# (plugin management via Claude Code settings)
```

Commands are namespaced as `/devmux:spawn`, `/devmux:init`, etc.

## Quick start

```bash
# 1. Clone a repo with bare-repo layout (or run /devmux:init in an existing repo)
/devmux:clone https://github.com/org/project.git

# 2. Spawn a worker on a new branch
/devmux:spawn feature-auth "Implement OAuth login with session management"

# 3. Monitor workers
/devmux:workers

# 4. Merge completed work
/devmux:harvest feature-auth
```

## Commands

| Command | Description | Arguments |
|---------|-------------|-----------|
| `/devmux:clone` | Clone repo as bare repo with worktree-friendly layout | `<url> [name]` |
| `/devmux:init` | Detect project type, check tools, generate `.config/wt.toml` | — |
| `/devmux:spawn` | Create worker: worktree + cmux workspace + browser + dev server | `<branch> "<task>"` |
| `/devmux:workers` | Dashboard of all active workers with status and progress | — |
| `/devmux:harvest` | Rebase, review, test, merge, and clean up a completed branch | `[branch]` |
| `/devmux:rebase` | Fetch origin and rebase current branch onto `origin/main` | — |
| `/devmux:teardown` | Abandon worker: close workspace, remove worktree | `[branch]` |

## How it works

### Master-worker pattern

```
Master (main branch) ─── plans, decomposes, orchestrates
  ├─ Worker A (feature-auth)  ─── focused task, isolated worktree
  ├─ Worker B (fix-sidebar)   ─── focused task, isolated worktree
  └─ Worker C (refactor-db)   ─── focused task, isolated worktree
```

The **master** agent decomposes work into independent tasks, spawns workers with `/devmux:spawn`, monitors progress with `/devmux:workers`, and harvests completed branches with `/devmux:harvest`.

Each **worker** agent receives its task via `.worktree-task.md` (injected at session start by a hook), works in isolation, reports progress through the cmux sidebar, and signals completion when done.

### What `/devmux:spawn` sets up

1. **worktrunk** creates an isolated worktree with `wt switch --create <branch>`
2. A `.worktree-task.md` file is written to the worktree with the task description
3. **cmux** creates a workspace with the three-pane layout shown above
4. The dev server starts on a deterministic port via worktrunk's `{{ branch | hash_port }}`
5. The cmux browser panel opens pointing at the dev server
6. Claude Code launches in the left pane (wrapped in zmx if available)
7. Sidebar metadata is set: task, branch, port, progress

### Port allocation

Each worktree gets a deterministic port from worktrunk's `{{ branch | hash_port }}` filter (range 10000–19999). Same branch always maps to the same port — no conflicts, no configuration.

### Worker status reporting

Workers report to the master through the cmux sidebar:

```bash
cmux set-progress 0.6 --label "Implementing"
cmux set-status status "writing tests" --icon "hammer"
cmux log --level info --source "feature-auth" -- "Auth middleware done"
```

The master reads this with `/devmux:workers` which aggregates `wt list` and `cmux sidebar-state`.

### Bare repo model

For worktree-heavy workflows, devmux uses bare repos where all worktrees are peers:

```
project/
├── project          (bare repo — git data only)
├── project.main     (main worktree)
├── project.feature  (feature worktree)
└── project.fix      (bugfix worktree)
```

`/devmux:clone` creates this layout. `/devmux:init` configures existing repos.

## Supported project types

`/devmux:init` auto-detects the project and generates `.config/wt.toml` with appropriate lifecycle hooks.

| Type | Detection | Dev server port flag |
|------|-----------|---------------------|
| SvelteKit | `@sveltejs/kit` in package.json | `--port` |
| Next.js | `next` in package.json | `-p` |
| Vite | `vite` in package.json | `--port` |
| Node.js | `package.json` | varies |
| Rust | `Cargo.toml` | — |
| Python | `pyproject.toml` | — |
| Go | `go.mod` | — |
| Ruby | `Gemfile` | — |
| Java | `pom.xml` / `build.gradle` | — |

## Known issues

- **cmux split crash on Intel Macs**: `new-split` can crash cmux (patch merged, awaiting release). Workaround: run sessions inside zmx for crash resilience. The spawn command degrades gracefully to a 2-pane layout if splits fail.

## License

MIT
