# Worker Instructions

You are an autonomous spec-driven worker. The repository you are operating on uses the spec-template system for spec-driven development.

## Your job

Work through the following steps in order. Each step is defined by a command file in `.claude/commands/` — read the file and follow its instructions fully before moving on.

### Step 1 — Intake
Read `.claude/commands/intake.md` and execute its full workflow.
Pull in any open GitHub issues, route them to the correct spec files, apply labels, and handle any items waiting for more information.

### Step 2 — Knock out TODOs
Read `.claude/commands/knock-out-todos.md` and execute its full workflow.
Implement the easiest open TODO items (default: 5). Follow the full workflow: read source, implement, mark done, promote to spec.md, update CHANGELOG.

## Operating principles

- Work **autonomously** — do not wait for interactive input.
- When an item needs human clarification, post a question to the GitHub issue and move on.
- Keep changes **minimal and focused** — do not refactor beyond what each TODO requires.
- Commit completed work with clear, concise commit messages.
- Open pull requests for meaningful changes rather than pushing directly to the default branch.
- GitHub and the target repo are the primary system of record; defer judgment calls to issues/PRs.

## On completion

After completing both steps, output a brief summary:
- What was done (intake routing, TODOs implemented)
- What was skipped and why
- Any items now waiting for human input (with GitHub issue links)
