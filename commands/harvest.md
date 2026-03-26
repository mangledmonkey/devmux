---
description: Rebase, review, test, and merge a completed worker branch
argument-hint: "[branch]"
allowed-tools: [Bash, Read, Write, Glob, Grep]
---

# /devmux:harvest

Harvest a completed worker branch: rebase onto main, review the diff, run pre-merge checks, merge, clean up the workspace, and update the plan.

## What to do

### Step 1: Identify the branch

If `$ARGUMENTS` contains a branch name, use that. Otherwise, find workers marked as done:

```bash
wt list --format=json
```

Check cmux workspaces for "done" status:
```bash
cmux --json list-workspaces
```
For each workspace matching a worktree branch, check:
```bash
cmux sidebar-state --workspace <workspace_ref>
```
Look for `progress=1.00` or a status entry containing "done".

Also check for a PR URL in the sidebar status (key `pr`). Note it for the report.

If multiple are done, list them and ask which to harvest. If none are done, report that and exit.

### Step 2: Switch to the worktree

```bash
wt switch <branch>
```

### Step 3: Rebase onto main (tiered conflict resolution)

Run the rebase script:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/rebase-main.sh
```

**If rebase succeeds**: proceed to Step 4.

**If rebase has conflicts**, apply tiered resolution:

**Tier 1 — Auto-resolve mechanical conflicts**:
Check the conflicting files:
```bash
git diff --name-only --diff-filter=U
```
If there are ≤3 files and the conflicts are mechanical (adjacent imports, barrel exports, lock file entries — look for conflict markers where both sides are additive):
- Resolve by keeping both sides
- `git add <files> && git rebase --continue`
- Proceed to Step 4

**Tier 2 — Bounce back to worker**:
If conflicts are semantic (logic changes, overlapping edits):
```bash
git rebase --abort
```
Check if the worker's cmux workspace is still open:
```bash
cmux --json list-workspaces
```
If workspace exists, send the worker a rebase task:
```bash
cmux send --workspace <workspace_ref> --surface <claude_surface> "Please rebase onto main and resolve conflicts. Main has new changes in: <conflicting files>. After resolving, signal done again.\n"
```
Report to the user: "Bounced rebase back to worker. Re-run `/devmux:harvest <branch>` when the worker signals done."
Exit.

If workspace was closed, report: "Worker workspace is closed and rebase has conflicts. Re-spawn the worker with `/devmux:spawn <branch> 'Rebase and resolve conflicts'` or resolve manually."
Exit.

**Tier 3 — User intervenes**:
If auto-resolve is uncertain, report the conflicts with both sides and let the user decide:
- List conflicting files and show the conflict markers
- Suggest: "Resolve manually, then run `/devmux:harvest <branch>` again"

### Step 4: Review the diff

Show what will be merged:
```bash
git diff main...<branch> --stat
git diff main...<branch>
```

Read key modified files to understand the changes. Use the Glob and Grep tools to inspect the changes in context:
- Are there any obvious issues?
- Do the changes match the task description in `.worktree-task.md`?
- Any leftover debug code, TODOs, or commented-out blocks?

Provide a brief review summary to the user.

### Step 5: Merge

Use worktrunk's merge command which handles squash, rebase, pre-merge hooks, and cleanup:
```bash
wt merge
```

This will:
1. Squash commits into one
2. Run pre-merge hooks (test, lint, check as configured in `.config/wt.toml`)
3. Fast-forward merge to the default branch
4. Remove the worktree and branch

If pre-merge hooks fail, report the failures and stop. The user decides whether to fix or abort.

### Step 6: Clean up cmux workspace

After merge, close the cmux workspace if it still exists:
```bash
cmux --json list-workspaces
```
Find the workspace whose `title` matches the branch name, then:
```bash
cmux close-workspace --workspace <workspace_ref>
```

If zmx was used, clean up the session:
```bash
zmx list 2>/dev/null | grep <branch> && zmx kill <branch> || true
```

### Step 7: Update the plan

If `.devmux-plan.md` exists in the project root (check from the main worktree — you should be back on the default branch after merge):

1. Read `.devmux-plan.md` with the Read tool
2. Find all tasks whose `**Branch**` matches the harvested branch
3. Update their status:
   - `**Status**`: `in_progress` → `merged`
   - `**Branch**`: keep the value for reference
   - `**Worker**`: clear to `—`
4. Move the completed task entries to the `## Completed` section with a merge date
5. Check for newly unblocked tasks: any task whose `**Depends on**` references only `merged` tasks and whose status is `queued` or `blocked`
6. Write the updated plan back using the Write tool

### Step 8: Proactive rebase of active workers

After successful merge, check if other workers are now behind main:

```bash
wt list --format=json
```

For each non-main worktree that is still active (has a matching cmux workspace):
```bash
git rev-list --count origin/main..<worker_branch>
```

If any workers are behind, report:
```
Workers now behind main after merge:
  - sidebar-ui: 3 commits behind
  - api-middleware: 3 commits behind
Rebase them? (sends /devmux:rebase to each worker's Claude session)
```

If the user confirms (or you judge it safe — e.g., the workers are idle/done), send rebase commands:
```bash
cmux send --workspace <workspace_ref> --surface <claude_surface> "/devmux:rebase\n"
```

### Step 9: Report

Summarize what was merged:
- Branch name
- Number of files changed
- Lines added/removed
- Pre-merge hook results
- PR URL (if worker created one)
- Plan tasks completed (IDs and titles)
- Newly unblocked tasks (if any)
- Suggested next action: "Spawn X?" or "Harvest Y?" or "All tasks complete"
- Current branch (should be back on the default branch)
