# Autonomous Worker

The worker is a Docker container that runs Claude CLI autonomously against a target repo. It is designed as a **cron job**: it wakes up, clones the target repo, runs the intake and TODO workflow, and exits. State persists between runs via a Docker volume.

This is Layer 2 of the spec-template system — completely optional. A repo can use the scaffold (Layer 1) without ever running the autonomous worker.

---

## How it works — two modes

The worker automatically decides what to do based on whether the target repo already has the scaffold installed.

### Install mode (first run against an unscaffolded repo)

1. Clones the target repository.
2. Checks for `specs/AGENTS.md` — the scaffold detection marker.
3. Marker absent → **install mode**: copies the `dist/` scaffold payload into the repo, creates a `scaffold/bootstrap` branch, commits, and opens a bootstrap PR.
4. Exits. The next run (after the PR is merged) switches to operate mode automatically.

### Operate mode (subsequent runs)

1. Clones or updates the target repository.
2. Finds `specs/AGENTS.md` — scaffold confirmed.
3. Reads `.claude/worker-config.yaml` for the list of agents and resource limits.
4. Checks global activity signals (unprocessed issues, human comments on filed issues).
5. For each agent: checks per-agent PR state, runs Claude CLI with agent-specific instructions.
6. Each agent gets its own branch (`worker/{name}/YYYY-MM-DD`) and PR.
7. Exits. The next cron run picks up where it left off.

---

## Multi-agent architecture

The worker reads `.claude/worker-config.yaml` from the target repo to determine which agents to run:

```yaml
max_open_prs: 1
agents:
  - intake
  - knock-out-todos
```

- **`max_open_prs`** — limits how many open worker PRs can exist at once. Keeps the review queue manageable.
- **`agents`** — list of agent names. Each must have a matching instruction file in the worker image (`worker/agents/{name}.md`).

Each agent gets its own branch and PR:
- `worker/intake/2025-03-10` — intake agent's branch for March 10
- `worker/knock-out-todos/2025-03-10` — knock-out-todos agent's branch

Agents run independently: the intake agent routes issues while the knock-out-todos agent implements TODOs. Human comments on an agent's PR trigger that specific agent to respond on its next run.

---

## Quick start with Docker Compose

### Using the published image

```bash
cp .env.example .env
# Edit .env with your GITHUB_TOKEN, ANTHROPIC_API_KEY, and TARGET_REPO
docker compose up
```

### Building locally

```bash
cp .env.example .env
# Edit .env with your values
docker compose -f docker-compose.local.yml up --build
```

### Using the helper script

```bash
cp .env.example .env
# Edit .env with your values
./run-worker.sh            # Pull and run published image
./run-worker.sh --build    # Build locally first, then run
```

---

## Authentication

The worker supports two auth modes for Claude. Use whichever matches your setup.

### Option A — Claude Code subscription (personal use, recommended locally)

If you have a Claude.ai subscription (e.g. the $20/month plan), you can use it instead of paying for API tokens separately.

**One-time setup on your host machine:**

```bash
claude login   # opens browser, authenticates against claude.ai
```

This stores credentials in `~/.claude/` on the host. Mount that directory into the container — the CLI inside will find them automatically. Do **not** set `ANTHROPIC_API_KEY`.

> **Important:** The worker expects credentials to be stored as `~/.claude/.credentials.json`.
> On macOS and Windows, `claude login` stores tokens in the OS keychain by default — the file won't be present.
> If that's the case, use Option B (API key) instead, or re-run `claude login` on a Linux machine where file-based storage is the default.

```bash
docker run --rm \
  -v ~/.claude:/home/worker/.claude:ro \
  -e GITHUB_TOKEN="your-github-token" \
  -e TARGET_REPO="owner/your-repo" \
  -v spec-worker-state:/worker/state \
  ghcr.io/noahwright87/spec-template-worker:latest
```

### Option B — Anthropic API key (CI/CD, Kubernetes, work environments)

Create an API key at [console.anthropic.com](https://console.anthropic.com). This is a separate, pay-per-token product from the claude.ai subscription.

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e GITHUB_TOKEN="your-github-token" \
  -e TARGET_REPO="owner/your-repo" \
  -v spec-worker-state:/worker/state \
  ghcr.io/noahwright87/spec-template-worker:latest
```

To use a custom API endpoint (enterprise proxy or gateway), add `ANTHROPIC_BASE_URL`:

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY="sk-..." \
  -e ANTHROPIC_BASE_URL="https://your-proxy.example.com" \
  -e GITHUB_TOKEN="your-github-token" \
  -e TARGET_REPO="owner/your-repo" \
  -v spec-worker-state:/worker/state \
  ghcr.io/noahwright87/spec-template-worker:latest
```

---

## Required secrets

Never bake these into the image.

| Variable | Required | What it is |
|---|---|---|
| `GITHUB_TOKEN` | Always | GitHub personal access token or app token — needs repo read/write + issues + PRs |
| `ANTHROPIC_API_KEY` | Option B only | Anthropic API key — not needed if using Option A (subscription mount) |

---

## Runtime parameters

| Variable | Required | Default | Description |
|---|---|---|---|
| `TARGET_REPO` | Yes | — | Target repository in `owner/repo` format |
| `TARGET_BRANCH` | No | `main` | Branch to clone and work against |
| `CLAUDE_CONFIG_PATH` | No | `.claude` | Path to config dir in the target repo (relative to repo root) |
| `ANTHROPIC_BASE_URL` | No | — | Custom API endpoint for enterprise proxy/gateway deployments |
| `MODEL` | No | CLI default | Claude model to use (e.g., `claude-sonnet-4-5`, `claude-haiku-4-5`) |

---

## Model selection

The `MODEL` parameter lets you choose which Claude model the worker uses. This is especially useful for:

- **Cost optimization** — use Haiku for simple intake/routing tasks
- **Quality control** — use Opus for complex implementation work
- **Enterprise gateways** that only have certain models available

**Examples:**
```bash
# Use Sonnet 4.6 (good balance of speed and capability)
-e MODEL=claude-sonnet-4-6

# Use Haiku for cost-efficient processing
-e MODEL=claude-haiku-4-5

# Use Opus for complex tasks
-e MODEL=claude-opus-4-6
```

**Model validation:** When using API key mode, the worker validates model access before starting work. If the model ID is wrong or your key doesn't have access, it fails immediately with a clear error message (any non-200 response is treated as a fatal preflight failure).

**Subscription mode + MODEL:** You can set `MODEL` in subscription mode too — the worker will pass `--model` to the Claude CLI. Model validation is skipped (there's no API key to validate against), but the CLI will use the specified model for the run. If the model ID is invalid, the Claude CLI will report an error when it starts.

---

## Adopting a repo via the worker

The easiest way to bootstrap a new repo:

1. Point the worker at the target repo with `TARGET_REPO`.
2. The worker detects no scaffold and opens a bootstrap PR automatically.
3. Review and merge the PR.
4. The next cron run switches to operate mode and begins processing normally.

**Detection:** the worker checks for `specs/AGENTS.md`. This file is unique to the scaffold and reliably absent from unscaffolded repos. If the marker is present, operate mode runs. If absent, install mode runs.

---

## Deploying in Kubernetes

The worker runs as a [`CronJob`](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) in Kubernetes. See [`k8s/README.md`](../k8s/README.md) for full kustomize-based deployment instructions, including:

- Base CronJob template with Secret-based credentials
- Per-repo overlays with schedule and model configuration
- Horizontal scaling (one CronJob per target repo)

---

## How the image is built

The image is built automatically by GitHub Actions when files in `worker/`, `scripts/`, or `dist/` change on `main`. See `.github/workflows/build-worker.yml`. The image is published to GitHub Container Registry (GHCR) and tagged with both `latest` and the commit SHA.
