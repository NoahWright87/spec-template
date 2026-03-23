# Tasks Directory

Tasks are self-contained markdown instruction units. Each task describes one specific capability (branch management, PR lifecycle, echo chamber prevention, etc.) that can be composed into agents.

## How tasks are used

The fleet manager reads an agent's manifest to find its `> Tasks:` list, then concatenates the referenced task files in order to build the agent's full prompt. Tasks listed earlier appear earlier in the prompt and receive more emphasis.

## Conventions

- **Affirmative language only** — say what to do, pair any constraint with its positive form. Words like "don't" and "never" are load-bearing; if skimmed past, the instruction inverts.
- **Self-contained** — each task works on its own with no cross-references to other task files. The agent manifest handles composition.
- **Environment variables** — use `$AGENT_NAME`, `$AGENT_BRANCH`, `$WORKER_PR_NUMBER`, `$TARGET_BRANCH` for runtime values. These are exported by the fleet manager before invoking Claude.
- **Documentation headers** — the `> Purpose:` and `> Scope:` lines at the top are human-readable documentation, not parsed by the assembler.

## Adding a new task

1. Create a new `.md` file in this directory
2. Include `> Purpose:` and `> Scope:` headers for documentation
3. Write instructions using affirmative language
4. Reference the task by its filename (without `.md`) in agent manifests

## Current tasks

| Task | Purpose |
|------|---------|
| `echo-chamber-prevention` | Agent identity, human-only interaction rules |
| `branch-management` | Branch checkout, fetch, merge conflict resolution |
| `pr-lifecycle` | Review comments, respond to feedback, self-review |
| `intake-routing` | Route ideas/issues to spec TODO files |
| `todo-implementation` | Pick and implement easiest TODOs |
| `refinement` | Add effort estimates and detail to TODOs |
| `spec-backfill` | Generate specs from existing code |
| `commit-and-push` | Stage, commit, push to remote |
| `pr-creation` | Create or update PRs |
| `summary-reporting` | Post run summary to console |
