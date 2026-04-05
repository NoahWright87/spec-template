# Contributing

## Architecture overview

This repo has three layers. Keep them clearly separated as you work.

### Layer 1 — Installable scaffold

The files that downstream repos copy in to adopt the spec-template system. Commands live in `.claude/commands/` (installed into target repos) and also in `plugin/commands/` (installable via `claude plugin install`).

**Scaffold templates** live in `agents/templates/`. The worker's install mode copies these directly into target repos.

| Source | Installed as | Notes |
|--------|-------------|-------|
| `agents/templates/spec.md` | `specs/spec.md` | Template only — not this repo's live spec |
| `agents/templates/spec.todo.md` | `specs/spec.todo.md` | Template only |
| `agents/templates/INTAKE.md` | `specs/INTAKE.md` | Template only |
| `agents/templates/AGENTS.md` | `specs/AGENTS.md` | Template only |
| `agents/templates/README.md` | `specs/README.md` | Template only |
| `agents/templates/deps-README.md` | `specs/deps/README.md` | Template only |
| `agents/templates/spec-check.yml` | `.github/workflows/spec-check.yml` | PR check workflow |
| `agents/templates/config.yaml` | `.agents/config.yaml` | Agent config v2 |

### Layer 2 — Composable agents

The `agents/` directory at the repo root defines the multi-agent system:

| Path | Purpose |
|------|---------|
| `agents/*.md` | Agent definitions (intake, refine, knock-out-todos, scout) |
| `agents/tasks/*.md` | Reusable task files referenced by agents |
| `agents/templates/` | Scaffold templates installed into target repos |
| `agents/references/` | Reference docs (sizing guide, etc.) |
| `agents/scout/templates/` | Report templates for the scout agent |

### Layer 3 — Autonomous worker

Files in `worker/` define the containerized runner that executes agents autonomously:

| Path | Purpose |
|------|---------|
| `worker/entrypoint.sh` | Main orchestrator script |
| `worker/scripts/common.sh` | Shared bash functions |
| `worker/scripts/github-app-token.mjs` | GitHub App token generator |
| `worker/scripts/{agent}/` | Per-agent check and startup scripts |
| `worker/Dockerfile` | Container image definition |

See [`worker/README.md`](worker/README.md) for operator docs.

### Plugin system

The `plugin/` directory mirrors `.claude/commands/` for distribution via `claude plugin install`:

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin metadata |
| `plugin/commands/what-now.md` | Entry point |
| `plugin/commands/what-now/*.md` | Subcommands |
