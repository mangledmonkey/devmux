---
description: Rebase, review, test, and merge a completed worker branch
argument-hint: "[branch]"
allowed-tools: [Bash, Read, Glob, Grep]
---

# /worktree-dev:harvest

Harvest a completed worker branch: rebase onto main, review the diff, run pre-merge checks, merge, and clean up the workspace.

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

If multiple are done, list them and ask which to harvest. If none are done, report that and exit.

### Step 2: Switch to the worktree

```bash
wt switch <branch>
```

### Step 3: Rebase onto main

Run the rebase script to ensure the branch is current with origin/main:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/rebase-main.sh
```

If there are conflicts, report them and stop. The user needs to resolve conflicts before harvesting.

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

### Step 7: Report

Summarize what was merged:
- Branch name
- Number of files changed
- Lines added/removed
- Pre-merge hook results
- Current branch (should be back on the default branch)
