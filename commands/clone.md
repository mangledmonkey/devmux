---
description: Clone a repo as a bare repo with worktree-friendly layout
argument-hint: <url> [name]
allowed-tools: [Bash, Read, Write]
---

# /devmux:clone

Clone a repository as a bare repo optimized for worktree-based development.

## What to do

1. Parse `$ARGUMENTS` for the URL and optional name. If no name given, derive from URL (strip `.git` suffix, use basename).

2. Run the clone script from the plugin:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/clone-bare.sh <url> [name]
   ```

   This creates the layout:
   ```
   <name>/
   ├── <name>          (bare repo)
   └── <name>.main     (after wt switch below)
   ```

3. Create the main worktree:
   ```bash
   cd <name>/<name> && wt switch main
   ```

   This creates `<name>/<name>.main/` as the working directory.

4. After the worktree is created, `cd` into it and run `/devmux:init` to detect the project type and generate `.config/wt.toml`.

5. Report the result:
   - Bare repo path
   - Main worktree path
   - Next steps: `cd <name>/<name>.main` to start working

## Notes

- This is the recommended entry point for new projects in the worktree workflow.
- The bare repo layout avoids the "main worktree" problem where the primary checkout blocks branch operations.
- All worktrees are peers — no worktree is special.
- Critical git config fixes applied by the script: `remote.origin.fetch`, `core.logallrefupdates`, `push.default current`, `worktree.guessRemote`.
