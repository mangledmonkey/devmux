# Browser Feedback Loop

How worker agents use cmux's browser automation for rapid visual development iteration.

## Overview

Each worker's cmux workspace includes a browser panel (right-top pane) pointed at the dev server (`localhost:<hash_port>`). The worker lead uses cmux browser commands to inspect the running application, catch visual issues, and drive iteration with teammates.

## Who Has Browser Access

**Only the worker lead** — not teammates. Teammates are in-process agents that work through the shared task list and file system. The lead orchestrates browser checks as quality gates between implementation rounds.

## Browser Surface Reference

The browser surface ref is saved to `.devmux-workspace.json` by `/devmux:spawn` and injected into the worker context by `session-context.sh`. Use `--surface <ref>` on all browser commands.

If the surface ref isn't available, discover it:
```bash
cmux tree
```
Look for the surface marked `[browser]`.

## Core Commands

### Wait for page load
```bash
cmux browser wait --surface <ref> --load-state complete --timeout-ms 15000
```

### Take DOM snapshot
```bash
cmux browser snapshot --surface <ref> --interactive
```
Returns a structured accessibility tree. Use `--compact` for a shorter version.

### Take visual screenshot
```bash
cmux browser screenshot --surface <ref> --json
```

### Check console
```bash
cmux browser console list --surface <ref>
```

### Check errors
```bash
cmux browser errors list --surface <ref>
```

### Navigate
```bash
cmux browser goto --surface <ref> "http://localhost:<port>/path"
```

### Evaluate JavaScript
```bash
cmux browser eval --surface <ref> "document.querySelector('.component') !== null"
```

## Feedback Loop Pattern

### Standard implementation loop
```
1. Teammate implements feature
2. Lead waits for dev server reload:
   cmux browser wait --surface <ref> --load-state complete --timeout-ms 15000
3. Lead inspects:
   cmux browser snapshot --surface <ref> --interactive
   cmux browser console list --surface <ref>
   cmux browser errors list --surface <ref>
4. If errors → create fix task for teammate via Agent Teams task list
5. Repeat until clean
```

### Storybook verification loop
```
1. Tester teammate creates stories
2. Lead navigates to Storybook:
   cmux browser goto --surface <ref> "http://localhost:<port>/storybook"
3. Lead waits for Storybook to load:
   cmux browser wait --surface <ref> --text "<component name>" --timeout-ms 10000
4. Lead takes snapshot:
   cmux browser snapshot --surface <ref> --interactive
5. Verify:
   - All story variants present?
   - Components rendering correctly?
   - Console errors?
6. If issues → create fix tasks, iterate
```

### Pre-completion visual QA
```
1. Tests pass in terminal
2. Lead navigates to key pages/components
3. Takes snapshots and checks console for each
4. Verifies no visual regressions
5. Clean → proceed to commit + PR
```

## Master-Side Browser Inspection

The master agent can inspect any worker's browser panel without switching workspaces using `/devmux:browser [branch]`. This is useful for:
- Visual QA before harvesting
- Checking if a worker's dev server is healthy
- Debugging issues reported by a worker

## Advanced Browser Commands

### Network inspection
```bash
cmux browser network requests --surface <ref>
```

### Element interaction (for testing forms, etc.)
```bash
cmux browser click --surface <ref> "button.submit"
cmux browser fill --surface <ref> "input[name=email]" "test@example.com"
```

### Wait for specific content
```bash
cmux browser wait --surface <ref> --text "Welcome" --timeout-ms 5000
```

### Check element state
```bash
cmux browser is visible --surface <ref> ".error-message"
cmux browser get text --surface <ref> ".status-badge"
```
