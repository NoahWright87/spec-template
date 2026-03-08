# Spec Template — Current State

## Purpose
A two-product system for spec-driven development: an installable scaffold that gives AI a persistent memory in any repo, and an optional autonomous worker container that runs the intake/TODO workflow on a schedule.

## Related

- [`scaffold.todo.md`](scaffold.todo.md) — future scaffold and dist/ work
- [`worker.todo.md`](worker.todo.md) — future worker runtime work
- [`spec.todo.md`](spec.todo.md) — meta-tooling improvements (commands, UX)

## Contract

### Inputs

**Layer 1 — Installable scaffold:**
- Developer copies scaffold files (from `dist/` or via `/respec`) into a target repo
- AI reads spec files and command files when doing work in that repo

**Layer 2 — Autonomous worker:**
- Runtime secrets: `ANTHROPIC_API_KEY`, `GITHUB_TOKEN` (injected at container start)
- Runtime parameters: `TARGET_REPO` (required), `TARGET_BRANCH` (default: `main`), `CLAUDE_CONFIG_PATH`

### Outputs

**Layer 1:**
- `specs/` directory in the target repo with current-state and roadmap markdown files
- `.claude/commands/` with four slash commands
- `.github/workflows/spec-check.yml` — PR check that warns when source changes lack spec updates

**Layer 2:**
- Commits and PRs in the target repo from autonomous Claude runs
- GitHub issues labeled and routed
- TODOs implemented, specs updated

### Guarantees / Constraints

- Scaffold files in `dist/` are auto-generated from source — edit sources, run `scripts/generate-dist.sh`, commit result
- Worker secrets are never baked into the image — always injected at runtime
- Worker state volume is a supporting cache; GitHub and the target repo are the primary system of record

## Behavior

### Layer 1 — Scaffold

The installable scaffold consists of:

| Source | Installed path | Purpose |
|--------|---------------|---------|
| `.claude/commands/respec.md` | `.claude/commands/respec.md` | Install or update the spec system |
| `.claude/commands/intake.md` | `.claude/commands/intake.md` | Route ideas and GitHub Issues into spec files |
| `.claude/commands/knock-out-todos.md` | `.claude/commands/knock-out-todos.md` | Implement open TODOs and update specs |
| `.claude/commands/spec-backfill.md` | `.claude/commands/spec-backfill.md` | Bootstrap specs from existing code |
| `scaffold/specs/spec.md` | `specs/spec.md` | Current-state spec template |
| `scaffold/specs/spec.todo.md` | `specs/spec.todo.md` | Roadmap template |
| `scaffold/specs/INTAKE.md` | `specs/INTAKE.md` | Ideas intake bucket |
| `scaffold/specs/AGENTS.md` | `specs/AGENTS.md` | Agent instructions for the specs directory |
| `scaffold/specs/README.md` | `specs/README.md` | Human-readable guide to the specs directory |
| `scaffold/specs/deps/README.md` | `specs/deps/README.md` | Templates for dep specs and outbound TODOs |
| `.github/workflows/spec-check.yml` | `.github/workflows/spec-check.yml` | PR check for spec coverage |

The `dist/` directory is the generated output — commit it so downstream users can consume it without running the generator.

### Layer 2 — Worker

The worker container (`worker/Dockerfile`) is built on `node:20-slim` and includes:
- Claude Code CLI (`@anthropic-ai/claude-code`)
- GitHub CLI (`gh`)
- Git, curl, jq

**Cron job model:** each run spins up a container, executes the workflow, and exits. State persists between runs in a Docker volume mounted at `/worker/state`.

**Execution flow (entrypoint.sh):**
1. Validate required env vars (`ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `TARGET_REPO`)
2. Authenticate `gh` CLI with `GITHUB_TOKEN`
3. Clone target repo, or `fetch` + `reset --hard` for updates
4. **Scaffold detection:** check for `specs/AGENTS.md` in the workspace
5. **Install mode** (marker absent): copy `/worker/dist/` into workspace → create `scaffold/bootstrap-*` branch → commit → push → open bootstrap PR → exit
6. **Operate mode** (marker present): run Claude CLI non-interactively with worker instructions → tee to `/worker/state/last-run.log` → exit

**Scaffold detection:** `specs/AGENTS.md` is the canonical marker. It is distinctive to the scaffold and reliably absent from unscaffolded repos. The check is explicit and runs before any workflow logic.

**Install mode PR:** titled "Install spec-template scaffold"; includes a list of installed files, next steps for the maintainer, and a link to the source repo. Branch name: `scaffold/bootstrap-YYYYMMDD-HHMMSS`.

**Worker instructions:** defined in `worker/worker-instructions.md` (baked into image). Target repos can override with `.claude/worker-instructions.md`.

**Per-repo customization:** the entrypoint checks for `.claude/worker-instructions.md` in the cloned target repo before falling back to the image's built-in instructions.

### CI/CD

`.github/workflows/build-worker.yml` builds and publishes the worker image to GHCR (`ghcr.io/noahwright87/spec-template-worker`) when files in `worker/` or `scripts/` change on `main`. Tagged with commit SHA and `latest`.

### dist/ generation

`scripts/generate-dist.sh` copies scaffold source files into `dist/` with auto-generated do-not-edit headers. Run it after any source change, then commit the result.

## User Experience (UX)

**Scaffold consumers:** run `/respec` from their AI assistant, or copy files from `dist/` manually. The `/respec` command handles fresh install, re-install, and updates.

**Worker operators:** run `docker run` with injected secrets and `TARGET_REPO`. Schedule via cron or Kubernetes `CronJob`. See `worker/README.md` for the full reference.

## Acceptance

- `dist/` contains all scaffold files with auto-generated headers; re-running `generate-dist.sh` produces identical output for unchanged sources
- Worker container starts, clones a target repo, detects scaffold presence, and runs the appropriate mode (install or operate)
- Install mode: opens a bootstrap PR with the `dist/` payload; subsequent runs switch to operate mode automatically after the PR is merged
- Operate mode: runs intake + knock-out-todos via Claude CLI; exits with code 0 on success
- `build-worker.yml` triggers on pushes to `worker/` and `scripts/`, publishes to GHCR
- Target repos can override worker instructions by placing `.claude/worker-instructions.md` in the repo
