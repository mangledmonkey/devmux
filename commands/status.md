---
description: Unified dashboard of plan progress and worker status
allowed-tools: [Bash, Read]
---

# /devmux:status

Show a unified dashboard combining the master plan progress with live worker status from worktrees and cmux.

## What to do

### Step 1: Read the plan file

Check if `.devmux-plan.md` exists:
```bash
test -f .devmux-plan.md && echo "exists" || echo "missing"
```

If it exists, read it with the Read tool. Parse:
- All task entries (ID, status, branch, description, depends on, PR)
- Count by status: queued, in_progress, done, merged, blocked

If no plan exists, fall back to the v1 workers dashboard behavior (skip to Step 3).

### Step 2: Compute plan summary

Calculate:
- **Total tasks**: count of all tasks
- **Completion %**: `(merged + done) / total * 100`
- **Blocked tasks**: tasks whose `Depends on` references tasks that are not yet `merged`
- **Ready to spawn**: tasks with status `queued` and all dependencies `merged`

### Step 3: Get worker status from worktrees + cmux

```bash
wt list --format=json
```

```bash
cmux --json list-workspaces
```

For each non-main worktree with a matching cmux workspace:
```bash
cmux sidebar-state --workspace <workspace_ref>
```

Extract per worker:
- Branch name
- Progress (from cmux sidebar `progress=` line)
- Status message (from cmux sidebar status entries)
- PR URL (from cmux sidebar status entry with key `pr`, if present)
- Commits ahead of main (`main.ahead` from wt list)
- Whether dev server port is active (`url_active` from wt list)

### Step 4: Present the dashboard

#### If plan exists:

```
## Plan: <objective>
Progress: ████████░░░░░░░░ 45% (9/20 tasks merged)

### Active Workers
Branch          | Progress | Status      | Task                    | PR
auth-routes     | ███░ 75% | testing     | Auth API routes (1.1)   | —
sidebar-fix     | █████100%| PR ready    | Fix sidebar (2.3)       | #42

### Ready to Spawn (dependencies met)
- 1.3 Auth UI components (depends on: 1.1 ✓ merged)
- 2.4 Dashboard layout (no dependencies)

### Blocked
- 3.1 Admin panel (waiting on: 2.1 in_progress)

### Recently Completed
- 1.1 Auth API routes — merged 2026-03-24
- 2.2 Navigation refactor — merged 2026-03-24
```

#### If no plan exists:

Fall back to the v1 table format (same as `/devmux:workers`):

```
Branch          | Status    | Progress | Task                          | Port  | Commits
feature-auth    | coding    | 60%      | Implement login flow          | 14523 | 3 ahead
```

### Step 5: Suggest next action

Based on the dashboard state, suggest one of:
- **"Harvest X"** — if a worker shows progress 1.0 / status "done" or "PR ready"
- **"Spawn X"** — if there are ready-to-spawn tasks and available capacity
- **"All tasks complete"** — if everything is merged
- **"Waiting on workers"** — if all ready tasks are in progress, nothing else to do
