# devmux

Claude Code plugin for multi-agent parallel development using [worktrunk](https://github.com/nicholasgasior/worktrunk) + [cmux](https://cmux.com) + [Agent Teams](https://code.claude.com/docs/en/agent-teams).

A master Claude Code agent plans and decomposes work, then spawns worker agents — each in its own git worktree with a dedicated cmux workspace. Workers use Agent Teams internally (tester + reviewer + security) to develop thoroughly, run tests, and create PRs.

### Workspace layouts

```
Web (3-pane)                    Tool (2-pane)              Minimal (1-pane)
┌──────────┬──────────┐         ┌──────────┬──────────┐    ┌────────────────────┐
│          │ Browser  │         │          │ Utility  │    │                    │
│ Claude   │ (~80%)   │         │ Claude   │ terminal │    │ Claude (solo)      │
│ + Team   ├──────────┤         │ + Team   │          │    │                    │
│          │ Dev logs │         │          │          │    └────────────────────┘
│          │ (~20%)   │         │          │          │
└──────────┴──────────┘         └──────────┴──────────┘
  web frameworks                  CLIs, plugins, libs       docs only
```

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [worktrunk](https://github.com/nicholasgasior/worktrunk) (`wt`) | Worktree lifecycle, hooks, port allocation | `brew install worktrunk` |
| [cmux](https://cmux.com) (≥0.63.1) | Terminal workspaces, browser panels, sidebar | Download from cmux.com |
| [Claude Code](https://claude.ai/code) (≥2.1.33) | AI agent in each workspace | `npm install -g @anthropic-ai/claude-code` |
| [zmx](https://github.com/neurosnap/zmx) (recommended) | Session persistence, Agent Teams interactivity | `brew install neurosnap/tap/zmx` |

Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your Claude Code settings.

## Install

```bash
# Clone and use directly
git clone https://github.com/mangledmonkey/devmux.git
claude --plugin-dir ~/path/to/devmux

# Or install globally via Claude Code Skills Marketplace (coming soon)
```

Commands are namespaced as `/devmux:spawn`, `/devmux:init`, etc.

## Quick start

```bash
# 1. Clone a repo with bare-repo layout (or run /devmux:init in an existing repo)
/devmux:clone https://github.com/org/project.git

# 2. Plan the work
/devmux:plan "Build user authentication with OAuth"

# 3. Spawn workers for ready tasks
/devmux:spawn auth-routes "Implement auth API routes" --plan-tasks 1.1,1.2

# 4. Monitor progress
/devmux:status

# 5. Merge completed work
/devmux:harvest auth-routes
```

## Commands

| Command | Description | Arguments |
|---------|-------------|-----------|
| `/devmux:plan` | Create or review the master development plan | `[description]` |
| `/devmux:clone` | Clone repo as bare repo with worktree-friendly layout | `<url> [name]` |
| `/devmux:init` | Detect project type, check tools, generate `.config/wt.toml` | — |
| `/devmux:spawn` | Create worker: worktree + cmux workspace + Agent Teams | `<branch> "<task>" [--plan-tasks] [--solo\|--team]` |
| `/devmux:status` | Unified dashboard of plan progress + worker status | — |
| `/devmux:browser` | Inspect a worker's browser panel from the master session | `[branch]` |
| `/devmux:harvest` | Rebase, review, merge, update plan, rebase active workers | `[branch]` |
| `/devmux:rebase` | Fetch origin and rebase current branch onto `origin/main` | — |
| `/devmux:teardown` | Abandon worker: close workspace, remove worktree, reset plan | `[branch]` |
| `/devmux:workers` | Legacy dashboard (use `/devmux:status` instead) | — |

## How it works

### Master-worker pattern with Agent Teams

```
Master (main branch) ─── plans, decomposes, orchestrates
  ├─ Worker A (feature-auth, cmux workspace)
  │    └─ Agent Team: lead + tester + reviewer + security
  ├─ Worker B (fix-sidebar, cmux workspace)
  │    └─ Agent Team: lead + tester + security
  └─ Worker C (update-docs, cmux workspace)
       └─ Solo (no team — docs only)
```

The **master** agent creates a plan (`/devmux:plan`), spawns workers for ready tasks (`/devmux:spawn`), monitors progress (`/devmux:status`), and harvests completed branches (`/devmux:harvest`).

Each **worker** agent receives its task via `.worktree-task.md`, creates an Agent Team with teammates (tester, reviewer, security), develops with test and security gates, then commits, pushes, and creates a PR.

### What `/devmux:spawn` sets up

1. **worktrunk** creates an isolated worktree with `wt switch --create <branch>` (hooks install deps, start dev server)
2. A `.worktree-task.md` file is written with the task description and Agent Teams instructions
3. **cmux** creates a workspace with the appropriate layout (web/tool/minimal based on project type)
4. For web layouts: browser panel at `localhost:<hash_port>`, dev server pane (~20% height)
5. Claude Code launches in the left pane via zmx for session persistence
6. Sidebar metadata is set: task, branch, port, progress
7. Plan file is updated: linked tasks marked as `in_progress`

### Adaptive team composition

| Task type | Team | Layout |
|-----------|------|--------|
| UI component | lead + tester (unit + Storybook) + reviewer + security | web (3-pane) |
| API/backend | lead + tester (API tests) + reviewer + security | web (3-pane) |
| Infrastructure/config | lead + tester (smoke tests) + security | tool (2-pane) |
| CLI tool/plugin | lead + tester + security | tool (2-pane) |
| Documentation | solo (no team) | minimal (1-pane) |

Security is included on **all code tasks**. Override with `--solo` or `--team` flags.

### Security teammate

Every code task includes a security teammate that audits for:
- Injection (SQL, XSS, command, template)
- Secrets/credentials (API keys, tokens, PII)
- Authentication/authorization (missing auth, broken access control)
- Data exposure (PII in logs, error messages, URLs)
- Supply chain (dependency vulnerabilities, typosquatting)
- LLM security (prompt injection, insecure output handling)

The security teammate **reports but does not fix** — findings are routed to the implementer. Merge is blocked on CRITICAL/HIGH findings.

### Port allocation

Each worktree gets a deterministic port from worktrunk's `{{ branch | hash_port }}` filter (range 10000–19999). Same branch always maps to the same port — no conflicts, no configuration.

### Rebase and conflict resolution

When `/devmux:harvest` merges a branch:
1. **Proactive rebase**: Other active workers are offered a rebase to stay current
2. **Tiered conflict resolution**: Auto-resolve mechanical conflicts → bounce semantic conflicts back to worker → user intervenes as safety net

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

## License

MIT
