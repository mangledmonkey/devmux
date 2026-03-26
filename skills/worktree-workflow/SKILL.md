---
name: worktree-workflow
description: Master-worker pattern for multi-agent parallel development using git worktrees, cmux workspaces, Agent Teams, and Claude Code. Use when planning parallel work, decomposing tasks for workers, managing the multi-agent workflow, or coordinating Agent Teams within workers.
---

# Worktree-Based Multi-Agent Development (v2)

This skill guides the master-worker pattern for parallel AI development using git worktrees, with Agent Teams for sub-task coordination within each worker.

## When to Use

- Planning how to split work across multiple agents
- Deciding task boundaries and decomposition
- Managing the lifecycle of worker agents
- Monitoring progress across parallel workers
- Resolving conflicts between worker branches
- Configuring Agent Teams for workers (testing, review, security)

## Architecture

```
Master (main branch) ─── plans, decomposes, orchestrates
  ├─ Worker A (branch: feature-auth, cmux workspace)
  │    └─ Agent Team (in-process): lead + tester + reviewer
  ├─ Worker B (branch: fix-sidebar, cmux workspace)
  │    └─ Agent Team (in-process): lead + tester
  └─ Worker C (branch: update-docs, cmux workspace)
       └─ Solo (no team — docs only)
```

**devmux** owns the physical layer: worktrees (`wt`), cmux workspaces, dev servers, session persistence (`zmx`).

**Agent Teams** own the logical layer within each worker: shared task lists, inter-teammate messaging, quality gate hooks.

## Master Workflow

1. **Plan**: `/devmux:plan "description"` — creates `.devmux-plan.md` with decomposed tasks
2. **Spawn**: `/devmux:spawn <branch> "<task>" --plan-tasks 1.1,1.2` — creates worktree + cmux workspace + launches worker with Agent Teams instructions
3. **Monitor**: `/devmux:status` — unified dashboard of plan progress + worker status
4. **Inspect**: `/devmux:browser [branch]` — check a worker's browser panel from master
5. **Harvest**: `/devmux:harvest [branch]` — rebase + review + merge + update plan + rebase active workers

## Worker Workflow (with Agent Team)

1. Receives task context via `.worktree-task.md` (injected at SessionStart)
2. Creates Agent Team per instructions (tester + reviewer, in-process mode)
3. Breaks task into subtasks on the shared task list
4. Tester writes tests alongside implementation (not after)
5. Lead runs browser feedback loops (snapshot, console, errors)
6. Reports progress via cmux sidebar
7. When all tests pass and review is clean: commit, push, create PR
8. Signals completion (progress 1.0, status "PR ready")

## Task Decomposition Guidelines

Good tasks for parallel workers:

- **Independent file sets** — workers shouldn't edit the same files
- **Clear boundaries** — well-defined inputs and outputs
- **Self-contained** — each task can be verified independently
- **Right-sized** — substantial enough to justify a worker, not so large the agent loses context

### Shared File Protocol

Files that multiple tasks touch need special handling:

- **Lock files**: Sequential — only one worker installs deps at a time
- **Barrel exports / index files**: Append-only — workers add entries but don't restructure
- **Shared types/schemas**: Assign to a prerequisite task that merges first
- **Config files**: Create a prerequisite "config setup" task if needed

### Adaptive Team Composition

| Task type | Team | Indicators |
|-----------|------|------------|
| UI component | lead + tester (unit + Storybook) + reviewer | `.svelte`, `.tsx`, `.vue`, components/, routes with UI |
| API/backend | lead + tester (API tests) + reviewer + security | server/, api/, handlers, database, auth |
| Infrastructure/config | lead + tester (smoke tests) | config, build scripts, CI, tooling |
| Documentation | solo (no team) | only `.md` files |

Override with `--solo` or `--team` flags on `/devmux:spawn`.

## Available Commands

| Command | Purpose |
|---------|---------|
| `/devmux:plan [description]` | Create or review the master development plan |
| `/devmux:clone <url>` | Clone repo as bare repo for worktree workflow |
| `/devmux:init` | Detect project, generate wt.toml, check tools |
| `/devmux:spawn <branch> "<task>"` | Create worker with worktree + cmux workspace + Agent Teams |
| `/devmux:status` | Unified dashboard of plan progress + worker status |
| `/devmux:browser [branch]` | Inspect a worker's browser panel from master |
| `/devmux:harvest [branch]` | Rebase + review + merge + update plan |
| `/devmux:rebase` | Rebase current branch onto origin/main |
| `/devmux:teardown [branch]` | Abandon and clean up a worker |

## Testing Requirements

Every worker that writes code must run tests. Testing is gated:

1. **Worker gate**: Tests must pass before the worker signals completion
2. **Harvest gate**: Pre-merge hooks run tests again after rebasing onto main

The tester teammate writes tests alongside implementation, covers all acceptance criteria, and writes Storybook stories for UI components (when available).

## Port Allocation

Each worktree gets a deterministic port via worktrunk's `{{ branch | hash_port }}` filter (range 10000-19999). Same branch = same port, always.

## Deep-Dive References

- [references/architecture.md](references/architecture.md) — Tool stack, workspace layout, data flow
- [references/agent-teams.md](references/agent-teams.md) — Agent Teams integration patterns
- [references/browser-loop.md](references/browser-loop.md) — Browser feedback loop for visual development
