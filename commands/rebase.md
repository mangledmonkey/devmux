---
description: Fetch origin and rebase current branch onto origin/main
allowed-tools: [Bash]
---

# /devmux:rebase

Rebase the current worktree branch onto `origin/main`. Can be run by either master or worker sessions.

## What to do

1. Run the rebase script:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/rebase-main.sh
   ```

2. Report the result:
   - **Success**: "Rebased <branch> onto origin/main. Up to date."
   - **Already up to date**: "Already up to date with origin/main."
   - **Conflicts**: List the conflicting files and advise on resolution:
     ```bash
     git diff --name-only --diff-filter=U
     ```
     Tell the user to resolve conflicts, then `git rebase --continue`, or abort with `git rebase --abort`.
