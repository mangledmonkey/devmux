---
name: worktree-workflow
description: Master-worker pattern for multi-agent parallel development using git worktrees, cmux workspaces, and Claude Code. Use when planning parallel work, decomposing tasks for workers, or managing the multi-agent workflow.
---

# Worktree-Based Multi-Agent Development

This skill guides the master-worker pattern for parallel AI development using git worktrees.

## When to Use

- Planning how to split work across multiple agents
- Deciding task boundaries and decomposition
- Managing the lifecycle of worker agents
- Monitoring progress across parallel workers
- Resolving conflicts between worker branches

## The Pattern

```
Master (main branch) ─── plans, decomposes, orchestrates
  ├─ Worker A (branch: feature-auth)  ─── focused task
  ├─ Worker B (branch: fix-sidebar)   ─── focused task
  └─ Worker C (branch: refactor-db)   ─── focused task
```

The **master** agent:
1. Plans the work (creates implementation plan)
2. Decomposes into independent tasks
3. Spawns workers with `/devmux:spawn`
4. Monitors progress with `/devmux:workers`
5. Harvests completed work with `/devmux:harvest`

Each **worker** agent:
1. Receives task context via `.worktree-task.md` (injected at session start)
2. Works in an isolated worktree with its own dev server
3. Reports progress via cmux sidebar (`cmux set-progress`, `cmux set-status`)
4. Commits changes on its branch
5. Signals completion (progress = 1.0, status = "done")

## Task Decomposition Guidelines

Good tasks for parallel workers:

- **Independent file sets** — workers shouldn't edit the same files
- **Clear boundaries** — well-defined inputs and outputs
- **Self-contained** — each task can be verified independently
- **Right-sized** — not so large that the worker loses context, not so small that the overhead isn't worth it

Bad tasks for parallel workers:

- Touching shared config or schema files simultaneously
- Tasks with sequential dependencies (B requires A's output)
- Refactors that span the entire codebase
- Tasks requiring interactive user feedback

### Conflict Avoidance

When decomposing, explicitly list which files each worker may modify. If overlap is unavoidable:
1. Have one worker finish first
2. Harvest their changes
3. Then spawn the dependent worker

## Available Commands

| Command | Purpose |
|---------|---------|
| `/devmux:clone <url>` | Clone repo as bare repo for worktree workflow |
| `/devmux:init` | Detect project, generate wt.toml, check tools |
| `/devmux:spawn <branch> "<task>"` | Create worker with worktree + cmux workspace |
| `/devmux:workers` | Dashboard of all active workers |
| `/devmux:harvest [branch]` | Rebase + review + merge completed work |
| `/devmux:rebase` | Rebase current branch onto origin/main |
| `/devmux:teardown [branch]` | Abandon and clean up a worker |

## Port Allocation

Each worktree gets a deterministic port via worktrunk's `{{ branch | hash_port }}` filter (range 10000-19999). This means:
- No port conflicts between worktrees
- Ports are stable across restarts (same branch = same port)
- Dev servers and browsers auto-target the correct port

## Deep-Dive Reference

See [references/architecture.md](references/architecture.md) for:
- Tool stack details (worktrunk, cmux, zmx)
- Worker workspace layout
- Session persistence with zmx
- Browser feedback loop patterns
- Generic project adaptation
