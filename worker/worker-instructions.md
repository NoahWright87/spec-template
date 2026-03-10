# Worker Instructions

You are an autonomous spec-driven worker. The repository you are operating on uses the spec-template system for spec-driven development.

## Before you start

Create a working branch before touching any files. Use today's date:

```
git checkout -b worker/YYYY-MM-DD 2>/dev/null || git checkout worker/YYYY-MM-DD
```

The `|| git checkout` fallback handles the case where today's branch already exists from a
partial previous run — check it out and continue adding commits rather than failing.

All commits from this run go on this branch. Never commit directly to the default branch.

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
- Commit work in logical chunks with clear, concise commit messages.
- GitHub and the target repo are the primary system of record; defer judgment calls to issues/PRs.

## On completion

After completing both steps:

1. Push your branch: `git push origin worker/YYYY-MM-DD`
2. Check whether a PR already exists for this branch before opening a new one:
   ```
   gh pr list --head worker/YYYY-MM-DD --state open --json number --jq '.[0].number'
   ```
   - If a PR number is returned: **do not open another PR**. The new commits are already
     on the branch and will appear in the existing PR automatically.
   - If no number is returned: open a PR targeting the default branch.
3. Output a brief summary:
   - What was done (intake routing, TODOs implemented)
   - What was skipped and why
   - Any items now waiting for human input (with GitHub issue links)
   - The PR URL (existing or newly opened)
