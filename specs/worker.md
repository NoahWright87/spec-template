# Autonomous Worker Runtime — Current State

## Related

- [`worker.todo.md`](worker.todo.md) — future worker runtime work

## Purpose

Layer 2 of the spec-template system — completely optional. A Docker container that runs Claude CLI autonomously against a target repo on a cron schedule. It wakes up, clones the repo, runs the intake and TODO workflow, and exits.

## Inputs

**Authentication (choose one — never bake into image):**
- **Option A — Claude Code subscription:** omit `ANTHROPIC_API_KEY`; mount host `~/.claude` into the container (`-v ~/.claude:/root/.claude:ro`) so the CLI uses OAuth credentials from `claude login`
- **Option B — Anthropic API key:** set `ANTHROPIC_API_KEY`; uses the pay-per-token API at api.anthropic.com

**Always required:**
- `GITHUB_TOKEN` — GitHub personal access token or app token (repo read/write + issues + PRs)

**Runtime parameters:** `TARGET_REPO` (required), `TARGET_BRANCH` (default: `main`), `CLAUDE_CONFIG_PATH`

## Outputs

- Commits and PRs in the target repo from autonomous Claude runs
- GitHub issues labeled and routed
- TODOs implemented, specs updated

## Behavior

### Container contents

`worker/Dockerfile` is built on `node:20-slim` and includes:
- Claude Code CLI (`@anthropic-ai/claude-code`, pinned version)
- GitHub CLI (`gh`)
- Git, curl, jq, rsync

### Execution flow (`entrypoint.sh`)

1. Validate required env vars (`GITHUB_TOKEN`, `TARGET_REPO`); detect auth mode: API key (`ANTHROPIC_API_KEY` set) or subscription (`~/.claude` mounted) — exits with a helpful message if neither is present
2. Authenticate `gh` CLI with `GITHUB_TOKEN`
3. Clone target repo, or `fetch` + `reset --hard` for updates
4. **Scaffold detection:** check for `specs/AGENTS.md` in the workspace
5. **Install mode** (marker absent): copy `/worker/dist/` into workspace → create `scaffold/bootstrap` branch → commit → push → open bootstrap PR → exit
6. **Operate mode — pre-flight** (marker present): query GitHub for unprocessed issues, open TODO count, and INTAKE waiting items; if all are 0, exit early without invoking Claude (no-op run)
7. **Operate mode — run** (marker present, work detected): pass pre-computed stats as context to Claude CLI non-interactively with worker instructions → tee to `/worker/state/last-run.log` → exit

### Scaffold detection

`specs/AGENTS.md` is the canonical marker. It is distinctive to the scaffold and reliably absent from unscaffolded repos. The check is explicit and runs before any workflow logic.

### Install mode

- Branch name: `scaffold/bootstrap` (deterministic — stale branches from closed PRs are cleaned up before each attempt)
- Open PR check: if a bootstrap PR is already open, the run exits early without creating a duplicate
- File copy: `rsync --ignore-existing` — non-destructive, preserves any existing files in the target repo
- PR title: "Install spec-template scaffold"; includes installed file list, next steps, and a link to the source repo

### Pre-flight (operate mode)

Before invoking Claude, the entrypoint computes three stats via `gh` and `grep`:

| Stat | Source | Purpose |
|------|--------|---------|
| Unprocessed GH issues | `gh issue list` filtered for no intake label | Feed intake step |
| Open TODO items | `grep -c '^- '` across `specs/**/*.todo.md` | Feed knock-out-todos step |
| INTAKE waiting items | `grep` for `waiting for response` in `INTAKE.md` | Re-surface stale items |

If all three are zero, the run exits without calling Claude (no tokens consumed). Otherwise, the stats are prepended to the Claude prompt so the model has immediate context and does not need to repeat the same queries.

### Operate mode

The worker creates a dated branch (`worker/YYYY-MM-DD`) before touching any files, runs the intake + knock-out-todos workflow via Claude CLI, then opens a PR. State persists between runs in a Docker volume mounted at `/worker/state`.

### Worker instructions

Defined in `worker/worker-instructions.md` (baked into image). Target repos can override with `.claude/worker-instructions.md` — the entrypoint checks for this file before falling back to the image's built-in instructions.

### CI/CD

`.github/workflows/build-worker.yml` builds and publishes the worker image to GHCR (`ghcr.io/noahwright87/spec-template-worker`) when files in `worker/`, `scripts/`, or `dist/` change on `main`. Tagged with commit SHA and `latest`.

## User Experience

Worker operators run `docker run` with injected secrets and `TARGET_REPO`. Schedule via cron or Kubernetes `CronJob`. See `worker/README.md` for the full reference.

## Acceptance

- Worker container starts, clones a target repo, detects scaffold presence, and runs the appropriate mode (install or operate)
- Install mode: opens a bootstrap PR with the `dist/` payload; subsequent runs switch to operate mode automatically after the PR is merged
- Operate mode (pre-flight): computes unprocessed issues, open TODOs, and waiting INTAKE items; exits without invoking Claude if all are zero
- Operate mode (run): passes pre-computed stats as context; runs intake + knock-out-todos via Claude CLI; exits with code 0 on success
- `build-worker.yml` triggers on pushes to `worker/`, `scripts/`, and `dist/`; publishes to GHCR
- Target repos can override worker instructions by placing `.claude/worker-instructions.md` in the repo
