# Autonomous Worker Runtime — Current State

## Related

- [`worker.todo.md`](worker.todo.md) — future worker runtime work

## Purpose

Layer 3 of the spec-template system — completely optional. A Docker container that runs Claude CLI autonomously against a target repo on a cron schedule. It wakes up, clones the repo, runs agents, and exits.

## Inputs

**Claude authentication (choose one — never bake into image):**
- **Option A — Anthropic API key:** set `ANTHROPIC_API_KEY`; uses the pay-per-token API
- **Option B — Claude Code subscription:** omit `ANTHROPIC_API_KEY`; mount host `~/.claude` into the container so the CLI uses OAuth credentials

**GitHub authentication (choose one):**
- **Option A — GitHub App (recommended):** set `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_APP_INSTALLATION_ID`
- **Option B — Personal Access Token:** set `GH_TOKEN`

**Runtime parameters:** `TARGET_REPO` (required), `TARGET_BRANCH` (default: `main`), `MODEL` (optional), `WORKER_DEBUG` (optional)

## Outputs

- Commits and PRs in the target repo from autonomous Claude runs
- GitHub issues labeled and routed
- TODOs implemented, specs updated
- Progress reports (scout agent)

## Behavior

### Container contents

`worker/Dockerfile` is built on `node:20-alpine` and includes:
- Claude Code CLI (`@anthropic-ai/claude-code`, pinned version)
- GitHub CLI (`gh`), yq (YAML parser)
- Git, curl, jq

### Execution flow (`entrypoint.sh`)

1. Validate required env vars; detect GitHub auth mode (App → PAT fallback)
2. Detect Claude auth mode (API key or subscription credentials)
3. Write `~/.claude/settings.json` with full tool permissions
4. Pre-flight checks: model access validation, GitHub token validity + push permission, Claude CLI binary
5. Clone target repo, or `fetch` + `reset --hard` for updates; configure git identity
6. **Scaffold detection:** check for `.agents/config.yaml` or `specs/AGENTS.md`
7. **Install mode** (no scaffold): copy templates from `agents/templates/` → create `scaffold/bootstrap` branch → commit → push → open bootstrap PR → exit
8. **Operate mode** (scaffold present): read `.agents/config.yaml` for agent list → auto-upgrade config if needed → run per-agent check/startup scripts → invoke Claude CLI for each agent with situation report

### Multi-agent architecture

Each agent gets its own branch (`worker/{agent-name}/YYYY-MM-DD`) and PR. The entrypoint:
- Reads `.agents/config.yaml` from the target repo for agent list and settings
- Runs per-agent `check.sh` scripts to determine if work exists
- Runs per-agent `startup.sh` scripts to gather context (issues, eligible TODOs, etc.)
- Builds a situation report (PR state, comments, conflicts, startup data) prepended to the agent prompt
- Enforces dual PR caps (per-agent and fleet-wide `max_open_prs`)

### Config v2

`.agents/config.yaml` controls the agent fleet. Auto-upgraded from v1 by `upgrade_config()` in `common.sh`.

### Activity detection

Per-agent `check.sh` scripts (v2) determine whether each agent should run. Agents with no work are skipped — no tokens consumed. Each agent type has its own signals (unprocessed issues for intake, unrefined TODOs for refine, etc.).

### CI/CD

`.github/workflows/build-worker.yml` builds and publishes the worker image to GHCR (`ghcr.io/noahwright87/spec-template-worker`) when files in `worker/` or `agents/` change on `main`. Tagged with commit SHA and `latest`.

## User Experience

Worker operators run `docker compose up` with injected secrets and `TARGET_REPO`. Schedule via cron or Kubernetes `CronJob`. See `worker/README.md` for the full reference.

## Acceptance

- Worker container starts, clones a target repo, detects scaffold presence, and runs the appropriate mode
- Install mode: opens a bootstrap PR with scaffold templates; subsequent runs switch to operate mode after merge
- Operate mode: each agent checks for work independently; skips with no tokens consumed if no signals
- Per-agent PRs: each agent gets its own branch and PR; situation report provides pre-fetched context
- `build-worker.yml` triggers on pushes to `worker/` and `agents/`; publishes to GHCR
- Target repos can override task files via `.agents/overrides/`
