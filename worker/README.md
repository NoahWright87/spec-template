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
3. Reads and executes the **intake** command — routes open GitHub issues to the correct spec files.
4. Reads and executes the **knock-out-todos** command — implements the easiest open TODOs.
5. Commits and opens PRs for completed work.
6. Posts questions to GitHub issues for anything that needs human input.
7. Exits. The next cron run picks up where it left off.

---

## Required secrets

Never bake these into the image.

| Variable | What it is |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API key — used by Claude Code CLI |
| `GITHUB_TOKEN` | GitHub personal access token or app token — needs repo read/write + issues + PRs |

---

## Runtime parameters

| Variable | Required | Default | Description |
|---|---|---|---|
| `TARGET_REPO` | Yes | — | Target repository in `owner/repo` format |
| `TARGET_BRANCH` | No | `main` | Branch to clone and work against |
| `CLAUDE_CONFIG_PATH` | No | `.claude` | Path to config dir in the target repo (relative to repo root) |

## Adopting a repo via the worker

The easiest way to bootstrap a new repo:

1. Point the worker at the target repo with `TARGET_REPO`.
2. The worker detects no scaffold and opens a bootstrap PR automatically.
3. Review and merge the PR.
4. The next cron run switches to operate mode and begins processing normally.

**Detection:** the worker checks for `specs/AGENTS.md`. This file is unique to the scaffold and reliably absent from unscaffolded repos. If the marker is present, operate mode runs. If absent, install mode runs.

---

## Running locally in Docker Desktop

### 1. Pull the image

```bash
docker pull ghcr.io/noahwright87/spec-template-worker:latest
```

### 2. Create a state volume (once)

```bash
docker volume create spec-worker-state
```

### 3. Run a single iteration

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY="your-anthropic-key" \
  -e GITHUB_TOKEN="your-github-token" \
  -e TARGET_REPO="owner/your-repo" \
  -e TARGET_BRANCH="main" \
  -v spec-worker-state:/worker/state \
  ghcr.io/noahwright87/spec-template-worker:latest
```

### 4. Schedule recurring runs (Docker Desktop)

Use a cron expression with Docker's restart policies, or a local cron job that calls `docker run`:

```cron
# Run the worker every day at 3 AM
0 3 * * * docker run --rm -e ANTHROPIC_API_KEY="..." -e GITHUB_TOKEN="..." -e TARGET_REPO="owner/repo" -v spec-worker-state:/worker/state ghcr.io/noahwright87/spec-template-worker:latest
```

---

## Deploying in Kubernetes

The worker runs as a [`CronJob`](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) in Kubernetes.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: spec-worker-my-repo
spec:
  schedule: "0 3 * * *"        # daily at 3 AM UTC
  concurrencyPolicy: Forbid    # prevent overlapping runs
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: worker
              image: ghcr.io/noahwright87/spec-template-worker:latest
              env:
                - name: TARGET_REPO
                  value: "owner/your-repo"
                - name: TARGET_BRANCH
                  value: main
                - name: ANTHROPIC_API_KEY
                  valueFrom:
                    secretKeyRef:
                      name: spec-worker-secrets
                      key: anthropic-api-key
                - name: GITHUB_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: spec-worker-secrets
                      key: github-token
              volumeMounts:
                - name: worker-state
                  mountPath: /worker/state
          volumes:
            - name: worker-state
              persistentVolumeClaim:
                claimName: spec-worker-state-my-repo
```

Scale horizontally by running one `CronJob` per target repo, each with its own `TARGET_REPO` parameter and state volume.

---

## Per-repo customization

The worker checks for `.claude/worker-instructions.md` in the target repo before falling back to the image's built-in instructions. Drop a `worker-instructions.md` into the target repo's `.claude/` directory to override default behavior.

---

## How the image is built

The image is built automatically by GitHub Actions when files in `worker/` or `scripts/` change on `main`. See `.github/workflows/build-worker.yml`. The image is published to GitHub Container Registry (GHCR) and tagged with both `latest` and the commit SHA.
