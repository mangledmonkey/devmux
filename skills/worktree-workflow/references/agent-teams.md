# Agent Teams Integration

How devmux workers use Claude Code Agent Teams for sub-task coordination.

## Key Constraint: In-Process Mode Only

Agent Teams' split-pane mode supports tmux/iTerm2 but NOT cmux. Since devmux uses cmux for the visual layer, all Agent Teams within workers must run in **in-process mode** (the default).

Teammates work through the shared task list and file system. Only the worker lead has cmux access for browser feedback loops.

## Team Composition by Task Type

The `/devmux:spawn` command auto-detects the task type and writes appropriate `## Agent Team Instructions` into `.worktree-task.md`.

| Task type | Teammates | Key instructions |
|-----------|-----------|-----------------|
| UI component | tester (unit + Storybook) + reviewer | Storybook stories, browser snapshot verification |
| API/backend | tester (API tests) + reviewer + security | API test patterns, security audit |
| Infrastructure | tester (smoke tests) | Minimal smoke/regression tests |
| Documentation | none (solo) | No team needed |

## Worker Lead Responsibilities

The worker lead (the main Claude session in the cmux workspace):
- Creates the Agent Team based on `.worktree-task.md` instructions
- Decomposes the task into subtasks on the shared task list
- Runs browser feedback loops between implementation rounds
- Verifies all tests pass before signaling completion
- Commits, pushes, and creates the PR
- Reports progress to the master via cmux sidebar

## Tester Teammate Pattern

The tester is **always required** for code tasks. Its responsibilities:

1. Write tests alongside implementation — not after
2. Use the project's detected test framework
3. Cover every acceptance criterion with at least one test
4. Write Storybook stories for UI components (if project uses Storybook)
5. Run the test suite and report pass/fail

The tester should create test subtasks that depend on the corresponding implementation subtasks in the shared task list.

## Reviewer Teammate Pattern

The reviewer:
- Checks for best practices, proper error handling, accessibility, performance
- Requires plan approval before making any changes
- Reports issues clearly with suggested fixes
- Does NOT edit files — only reviews and comments via the task list

## Security Teammate Pattern

Included for API/backend tasks. Audits for:
- XSS, CSRF, injection vulnerabilities
- Authentication/authorization bypass
- Data exposure, insecure defaults
- Reports with severity ratings (critical/high/medium/low)

## Quality Gate Flow

```
1. Implementation subtasks completed
2. Test subtasks completed
3. Lead runs full test suite → must pass
4. Lead runs lint/check → must pass
5. Lead checks browser (UI tasks) → must be clean
6. If any gate fails → create fix tasks, iterate
7. All gates pass → commit + push + PR
8. Signal completion via cmux sidebar
```

## What NOT to Do

- Do NOT use split-pane mode (`--teammate-mode tmux`) — cmux handles layout
- Do NOT let teammates access cmux — only the lead has cmux access
- Do NOT signal completion before tests pass
- Do NOT spawn nested teams — teammates cannot create their own teams
