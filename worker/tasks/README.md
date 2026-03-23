# Tasks

Composable instruction units for the spec-template agent fleet.

Each `.md` file in this directory is a **task** — a self-contained set of instructions that teaches an agent how to do one specific thing. Tasks are combined by **agent manifests** (in `worker/agents/`) to create specialized agents.

## How it works

1. An agent manifest (e.g., `worker/agents/intake.md`) declares its tasks: `> Tasks: echo-chamber-prevention, branch-management, ...`
2. The fleet manager reads the manifest, concatenates the task files in order, and appends the agent-specific content
3. The assembled prompt is passed to Claude CLI

## Task list

| Task | What it does |
|------|-------------|
| `echo-chamber-prevention` | Ensures agents identify themselves (🤖 prefix), respond only to humans, and stay in their own lanes |
| `branch-management` | Sets up working branches, handles merge conflicts |
| `pr-lifecycle` | Reads and responds to PR comments, runs self-review |
| `intake-routing` | Routes ideas and GitHub Issues to spec TODO files |
| `todo-implementation` | Picks and implements the easiest open TODO items |
| `refinement` | Adds effort estimates and technical detail to TODOs |
| `spec-backfill` | Generates specs from existing code |
| `commit-and-push` | Checks for work done, pushes to remote |
| `pr-creation` | Creates or updates PRs with summary comments |
| `summary-reporting` | Outputs a run summary to console for logging |

## Writing a new task

See `AGENTS.md` in this directory for conventions (affirmative language, self-contained, env var usage).
