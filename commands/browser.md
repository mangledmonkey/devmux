---
description: Inspect a worker's browser panel from the master session
argument-hint: "[branch]"
allowed-tools: [Bash, Read]
---

# /devmux:browser

Take a snapshot, read console logs, and check for errors in a worker's cmux browser panel — without switching to that workspace.

## What to do

### Step 1: Identify the target worker

If `$ARGUMENTS` contains a branch name, use that.

Otherwise, list available workers and their workspaces:
```bash
cmux --json list-workspaces
```

Show the workspace titles (branch names) and ask which one to inspect.

### Step 2: Find the browser surface

Get the workspace topology:
```bash
cmux tree --workspace <workspace_ref>
```

Find the surface marked `[browser]` in the tree output. Example:
```
└── workspace workspace:5 "auth-routes"
    ├── pane pane:10
    │   └── surface surface:20 [terminal] "claude" [selected]
    ├── pane pane:11
    │   └── surface surface:21 [browser] "localhost:14523" [selected]    ← this one
    └── pane pane:12
        └── surface surface:22 [terminal] "dev" [selected]
```

Extract the browser surface ref (e.g., `surface:21`).

If no browser surface exists, report: "No browser panel found in workspace <branch>."

### Step 3: Get the current URL

```bash
cmux browser get-url --surface <browser_surface>
```

### Step 4: Take a snapshot

Get the DOM/accessibility tree:
```bash
cmux browser snapshot --surface <browser_surface> --interactive
```

This returns a structured representation of the page. Review it for:
- Is the page loaded and rendering content?
- Are expected components/elements present?
- Any visible error states or blank areas?

### Step 5: Check console and errors

```bash
cmux browser console list --surface <browser_surface>
```

```bash
cmux browser errors list --surface <browser_surface>
```

### Step 6: Report

Present a summary:
- **URL**: current page URL
- **Page state**: brief description of what's rendered (from snapshot)
- **Console**: number of log entries, any warnings/errors highlighted
- **Errors**: list of any errors, with messages
- **Assessment**: "Looks healthy" or "Issues found: <details>"

If there are issues and this is before a harvest, suggest: "You may want to send the worker a fix task before harvesting."

### Optional: Evaluate JavaScript

If the user asks to check something specific, you can run JS in the browser:
```bash
cmux browser eval --surface <browser_surface> "<javascript expression>"
```

For example, checking if a specific element exists:
```bash
cmux browser eval --surface <browser_surface> "document.querySelector('.login-form') !== null"
```
