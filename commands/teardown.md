---
description: Abandon and clean up a worker worktree and its cmux workspace
argument-hint: "[branch]"
allowed-tools: [Bash, Read]
---

# /worktree-dev:teardown

Abandon a worker's work, close its cmux workspace, and remove the worktree.

## What to do

### Step 1: Identify the branch

If `$ARGUMENTS` contains a branch name, use that. Otherwise, list available worktrees for the user to choose:
```bash
wt list
```

### Step 2: Confirm with user

Before teardown, warn that this will discard all uncommitted and unpushed work on the branch. If the branch has commits ahead of main that haven't been pushed, mention this explicitly.

Check:
```bash
wt list --format=json
```
Look at the `main.ahead` and `remote.ahead` fields for the target branch.

### Step 3: Close cmux workspace

Find and close the workspace matching the branch:
```bash
cmux list-workspaces
```
If a matching workspace exists:
```bash
cmux close-workspace --workspace <workspace_ref>
```

### Step 4: Kill zmx session

If zmx was used:
```bash
zmx list 2>/dev/null | grep <branch> && zmx kill <branch> || true
```

### Step 5: Remove worktree

Switch away from the worktree if currently in it (switch to the default branch):
```bash
wt switch ^
```

Then remove:
```bash
wt remove <branch> --force
```

### Step 6: Report

Confirm cleanup:
- Workspace closed
- zmx session killed (if applicable)
- Worktree and branch removed
- Currently on: `<default branch>`
