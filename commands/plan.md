---
description: Create or update the master development plan
argument-hint: "[description of what to build]"
allowed-tools: [Bash, Read, Write, Glob, Grep]
---

# /devmux:plan

Create, update, or review the master development plan (`.devmux-plan.md`) that drives task decomposition and worker orchestration.

## What to do

### If `$ARGUMENTS` contains a description: Create or rewrite the plan

#### Step 1: Detect project context

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh
```

Parse the output for `PROJECT_TYPE`, `FRAMEWORK`, `PKG_MANAGER`, `HAS_SCRIPT_*` flags, and `DEV_SCRIPT`. These inform task decomposition and testing strategy.

Also read `CLAUDE.md` and any existing docs to understand the project's architecture.

#### Step 2: Analyze the codebase

Use Glob and Grep to understand the project structure:
- Source directories, routing patterns, component organization
- Existing test files and testing framework (`*.test.*`, `*.spec.*`, `*.stories.*`)
- Shared files that multiple tasks might touch (barrel exports, type definitions, schemas, config)
- Entry points and key modules relevant to the described work

#### Step 3: Decompose into tasks

Break the work into tasks following these principles:

**Good tasks**:
- Independent file sets — workers shouldn't edit the same files
- Clear boundaries — well-defined inputs and outputs
- Self-contained — each task can be verified independently
- Right-sized — substantial enough to justify a worker, not so large the agent loses context

**Conflict avoidance**:
- Explicitly list which files each task may modify in the `Files:` field
- Flag overlapping file sets and either reorder tasks or add dependencies
- Shared files require special handling (see Shared File Protocol below)

**Shared file protocol**:
- **Lock files** (`package-lock.json`, `pnpm-lock.yaml`): If multiple tasks add dependencies, make them sequential (add `Depends on` links)
- **Barrel exports / index files**: Mark as "append-only" — workers add entries but don't restructure
- **Shared type/schema files**: Assign to a prerequisite task that merges first, or split so each task adds to non-overlapping sections
- **Config files**: If multiple tasks need changes, create a prerequisite "config setup" task

**Dependency ordering**:
- Tasks that produce shared types/schemas come first
- Tasks that consume those outputs depend on them
- Independent features (non-overlapping files) can run in parallel

#### Step 4: Determine team composition per task

For each task, infer the type and note the recommended Agent Team composition:

| Task type | Team composition | Indicators |
|-----------|-----------------|------------|
| UI component | lead + tester (unit + Storybook) + reviewer + security | Files in components/, routes with UI, `.svelte`/`.tsx`/`.vue` |
| API/backend | lead + tester (API tests) + reviewer + security | Files in server/, api/, routes with handlers, database |
| Infrastructure/config | lead + tester (smoke tests) + security | Config files, build scripts, CI, tooling |
| Documentation | solo (no team) | Only `.md` files, no code changes |

Note this as a `Team:` field on each task (used by `/devmux:spawn` to generate Agent Team instructions).

#### Step 5: Write the plan file

Write `.devmux-plan.md` in the project root using the Write tool. Follow this format exactly:

```markdown
# Plan: <short project/feature name>

Created: <YYYY-MM-DD>
Updated: <ISO 8601 timestamp>
Status: draft

## Objective

<2-3 sentence description of what we're building and why>

## Project Context

- **Type**: <PROJECT_TYPE> / <FRAMEWORK>
- **Package manager**: <PKG_MANAGER>
- **Test framework**: <vitest|jest|pytest|go test|etc.>
- **Has Storybook**: <yes|no>
- **Test command**: <npm run test:unit -- --run | etc.>
- **Lint command**: <npm run lint | etc.>
- **Check command**: <npm run check | etc.>

## Tasks

### 1. <Category Name>

#### 1.1 <Task title>
- **Status**: queued
- **Branch**: —
- **Worker**: —
- **Team**: <UI | API | infra | docs | solo>
- **Files**: <file globs this task may modify>
- **Depends on**: <task IDs or —>
- **PR**: —
- **Description**: <1-2 sentences>

#### 1.2 <Task title>
...

### 2. <Category Name>
...

## Shared Files

List files that multiple tasks touch, with the protocol for each:
- `<file>`: <append-only | sequential | prerequisite task X.Y>

## Completed
<!-- Merged tasks move here with merge date -->

## Notes
<!-- User preferences, architectural decisions, constraints -->
```

#### Step 6: Report

Summarize the plan:
- Number of task groups and tasks
- Parallelism: how many tasks can run simultaneously (no dependency conflicts)
- Shared file risks flagged
- Suggested spawn order (which tasks to start first)
- Ask if the user wants to revise anything before spawning workers

---

### If `$ARGUMENTS` is empty: Review existing plan

#### Step 1: Read the plan file

```bash
test -f .devmux-plan.md && echo "exists" || echo "missing"
```

If missing, tell the user: "No plan exists. Run `/devmux:plan <description>` to create one."

If it exists, read it with the Read tool.

#### Step 2: Check worker status

Get current state from worktrees and cmux:
```bash
wt list --format=json
```

```bash
cmux --json list-workspaces
```

For each workspace matching a worktree branch:
```bash
cmux sidebar-state --workspace <workspace_ref>
```

#### Step 3: Present plan status

Show a summary:
- **Plan objective** (first line)
- **Completion**: X of Y tasks merged, Z in progress, W queued
- **Active workers**: branch, progress %, current status
- **Blocked tasks**: which tasks are waiting on what
- **Ready to spawn**: tasks with all dependencies met, status = queued
- **Suggested next action**: "Spawn X?" or "Harvest Y?" or "All tasks complete — plan done"

#### Step 4: Offer revision

If the user wants to change the plan:
- They can edit `.devmux-plan.md` directly
- Or describe changes and you update the plan file with the Edit tool
- Recalculate dependencies and parallelism after changes
