# .agents/ Directory

This directory configures the [spec-template](https://github.com/NoahWright87/spec-template) autonomous agent fleet.

## Structure

- `config.json` — Fleet-level settings (max open PRs, global preferences)
- `coordination.json` — Cross-agent state (written by the fleet manager after each run — do not edit manually)
- Each subfolder (`intake/`, `knock-out-todos/`, etc.) belongs to one agent

## Per-agent folders

Each agent has its own folder containing:
- `AGENTS.md` — Repo-specific instructions for this agent (customize behavior here)
- `config.json` — Repo-specific configuration overrides (customize settings here)
- `state.json` — Agent state from previous runs (written by the fleet manager — do not edit manually)

## Coordination

Read `coordination.json` for awareness of other agents' activity.
Read another agent's `state.json` to understand what it last worked on.
Work only within your own folder and branches — leave other agents' work untouched.

## Conventions

- All agent comments and PR descriptions begin with `🤖 Claude ({agent name}):` — this identifies the author
- Each agent operates only on branches matching `worker/{agent-name}/*`
- Respond only to comments authored by humans (user type "User", no 🤖 prefix)
- When the last 3+ comments on a thread are all from agents, pause and wait for human input
