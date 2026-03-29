# CLAUDE.md — devmux plugin

Claude Code plugin for multi-agent worktree-based development using cmux + worktrunk + zmx + Agent Teams.

## Project Structure

```
~/dev/devmux/
├── devmux          (bare repo)
└── devmux.main/    (main worktree — you are here)
    ├── .claude-plugin/   (plugin manifest + hooks)
    ├── commands/         (10 slash commands)
    ├── scripts/          (5 bash scripts)
    └── skills/           (worktree-workflow skill + references)
```

## Development

Test the plugin with:
```bash
claude --plugin-dir ~/dev/devmux/devmux.main
```

Commands are namespaced as `/devmux:spawn`, `/devmux:init`, etc.

## Tool Stack

- **worktrunk** (`wt`) — git worktree lifecycle, hooks, `{{ branch | hash_port }}`
- **cmux** — macOS terminal with workspaces, browser panels, sidebar status
- **zmx** — session persistence (processes survive cmux crashes, enables Agent Teams interactivity)
- **Claude Code** — AI agent in each workspace
- **Agent Teams** — in-process teammate coordination (tester, reviewer, security) within each worker

## Architecture

devmux owns the physical layer (worktrees, cmux workspaces, dev servers). Agent Teams own the logical layer within each worker (shared task lists, inter-teammate messaging, quality gates).

Three workspace layouts:
- **Web** (3-pane): Claude left, browser right-top (~80%), dev server right-bottom (~20%)
- **Tool** (2-pane): Claude left, utility terminal right — for CLIs, plugins, libraries
- **Minimal** (1-pane): Claude only — for documentation tasks

## Plans

- Architecture plan: `~/.claude/plans/snoopy-dazzling-kernighan.md`
- Integration test plan: `~/.claude/plans/devmux-v2-integration-test.md`

## Known Constraints

- **cmux JSON schemas undocumented**: The `/spawn` command orchestrates cmux step-by-step with `cmux tree` discovery after each operation, rather than parsing creation command output.
- **`wt switch --create` changes directory**: Use `--no-cd` when the master needs to stay in place.
- **Agent Teams experimental**: Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.
- **Agent Teams in-process only**: Split-pane mode supports tmux/iTerm2 but not cmux. Workers must use in-process mode.
