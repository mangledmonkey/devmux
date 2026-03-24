# CLAUDE.md — devmux plugin

Claude Code plugin for multi-agent worktree-based development using cmux + worktrunk + zmx.

## Project Structure

```
~/dev/devmux/
├── devmux          (bare repo)
└── devmux.main/    (main worktree — you are here)
    ├── .claude-plugin/   (plugin manifest + hooks)
    ├── commands/         (7 slash commands)
    ├── scripts/          (5 bash scripts)
    └── skills/           (worktree-workflow skill)
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
- **zmx** — session persistence (optional, processes survive cmux crashes)
- **Claude Code** — AI agent in each workspace

## Implementation Plan

Full plan: `~/dev/marketmade/.agent/plans/devmux-plugin.md`

## Known Constraints

- **cmux Intel Mac bug**: Split pane creation can crash cmux on Intel Macs (patch merged, awaiting release). Run sessions inside zmx for resilience.
- **cmux JSON schemas undocumented**: The `/spawn` command orchestrates cmux step-by-step with `cmux list-panes`/`cmux list-pane-surfaces` discovery after each operation, rather than parsing creation command output.
- **`wt switch --create` changes directory**: Use `--no-cd` when the master needs to stay in place.
