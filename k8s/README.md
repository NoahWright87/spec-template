# Kubernetes Deployment

Deploy the spec-template worker as a Kubernetes CronJob using [Kustomize](https://kustomize.io/).

---

## Directory structure

```
k8s/
├── base/
│   ├── cronjob.yaml          # Base CronJob template (no repo-specific config)
│   └── kustomization.yaml
├── overlays/
│   └── spec-template/
│       └── kustomization.yaml # Live overlay for this repo — copy for each new repo
├── kustomization.yaml         # Top-level entry point (references overlays)
└── README.md
```

---

## Solo dev quickstart (Docker Desktop)

If you're running Kubernetes locally via Docker Desktop, this is the fastest path. No cloud infrastructure required.

### 1. Enable Kubernetes in Docker Desktop

Settings → Kubernetes → Enable Kubernetes → Apply & Restart.

Verify: `kubectl cluster-info` should show a local cluster.

### 2. Choose your auth method

**API key mode** (simplest — recommended):

```bash
kubectl create secret generic spec-worker-secrets \
  --from-literal=anthropic-api-key='sk-ant-...' \
  --from-literal=github-token='ghp_...'
```

**Subscription mode** (use your existing `claude login` credentials):

This works when your credentials are stored as a file (not in the OS keychain). Check:

```bash
ls ~/.claude/.credentials.json   # must exist
```

If it exists, you can mount it into the pod using a `hostPath` volume. The Secret still needs a placeholder for the `anthropic-api-key` key (the entrypoint ignores it when `~/.claude/.credentials.json` is present):

```bash
# GitHub token is still required
kubectl create secret generic spec-worker-secrets \
  --from-literal=anthropic-api-key='unused' \
  --from-literal=github-token='ghp_...'
```

Then patch your overlay to mount the host's `~/.claude` directory — see [Subscription mode](#subscription-mode--claude-credentials) below.

### 3. Create an overlay for your repo

```bash
cp -r k8s/overlays/spec-template k8s/overlays/my-repo
# Edit kustomization.yaml: set nameSuffix, TARGET_REPO, schedule, MODEL
```

### 4. Apply and test

```bash
# Preview what will be deployed
kubectl kustomize k8s/overlays/my-repo/

# Apply
kubectl apply -k k8s/overlays/my-repo/

# Trigger a manual run immediately
kubectl create job --from=cronjob/spec-template-worker-my-repo manual-test-$(date +%s)

# Watch the logs
kubectl logs -l app=spec-template-worker --tail=100 -f
```

---

## Prerequisites (cloud / shared cluster)

### 1. Create a Kubernetes Secret

```bash
kubectl create secret generic spec-worker-secrets \
  --from-literal=anthropic-api-key='sk-ant-...' \
  --from-literal=github-token='ghp_...'
```

### 2. Ensure the worker image is accessible

The base manifests reference `ghcr.io/noahwright87/spec-template-worker`. If your cluster can't pull from GHCR, mirror the image to your own registry and update the `images` block in `k8s/kustomization.yaml`.

---

## Creating an overlay for your repo

1. Copy the spec-template overlay as a starting point:

```bash
cp -r k8s/overlays/spec-template k8s/overlays/my-repo
```

2. Edit `k8s/overlays/my-repo/kustomization.yaml`:
   - Set `nameSuffix` to something unique (e.g., `-my-repo`)
   - Set `TARGET_REPO` to your `owner/repo`
   - Adjust `schedule` (cron expression) as needed
   - Optionally set `MODEL` (e.g., `claude-sonnet-4-6`, `claude-haiku-4-5`)

3. Add the overlay to `k8s/kustomization.yaml`:

```yaml
resources:
  - overlays/spec-template
  - overlays/my-repo
```

---

## Subscription mode / Claude credentials

If you want to use a Claude Code subscription (via `claude login`) instead of an API key, the worker needs access to `~/.claude/.credentials.json` from the host.

**Important:** `claude login` on macOS and Windows stores credentials in the OS keychain by default — there will be no `.credentials.json` file. In that case, API key mode is the only option for containers. On Linux, credentials are typically file-based and this approach works.

### How it works

The worker's `AUTH_MODE` is determined automatically:
- If `ANTHROPIC_API_KEY` is set → API key mode
- If `~/.claude/.credentials.json` exists inside the container → subscription mode

You provide the credentials by mounting the host's `~/.claude` directory into the container as a read-only volume.

### Kustomize patch for hostPath mount (Docker Desktop / local k8s)

Add these patches to your overlay's `kustomization.yaml`:

```yaml
patches:
  - target:
      kind: CronJob
      name: spec-template-worker
    patch: |-
      # Remove the API key env var
      - op: remove
        path: /spec/jobTemplate/spec/template/spec/containers/0/env/0
      # Mount ~/.claude from the host
      - op: add
        path: /spec/jobTemplate/spec/template/spec/containers/0/volumeMounts
        value:
          - name: claude-credentials
            mountPath: /home/worker/.claude
            readOnly: true
      - op: add
        path: /spec/jobTemplate/spec/template/spec/volumes
        value:
          - name: claude-credentials
            hostPath:
              path: /run/desktop/mnt/host/c/Users/YOUR_USERNAME/.claude
              type: Directory
```

Replace `/run/desktop/mnt/host/c/Users/YOUR_USERNAME/.claude` with the actual path. Docker Desktop on Windows exposes the host filesystem under `/run/desktop/mnt/host/`.

On Linux, use the direct path: `/home/YOUR_USERNAME/.claude`.

---

## Deploying

### Preview the rendered manifests

```bash
kubectl kustomize k8s/
```

### Apply to your cluster

```bash
kubectl apply -k k8s/
```

### Apply a single overlay

```bash
kubectl apply -k k8s/overlays/my-repo/
```

---

## Monitoring

### List CronJobs

```bash
kubectl get cronjobs -l app=spec-template-worker
```

### View recent Jobs

```bash
kubectl get jobs --sort-by=.metadata.creationTimestamp | tail -10
```

### Check logs from the latest run

```bash
kubectl logs -l app=spec-template-worker --tail=100
```

### Trigger a manual run

```bash
kubectl create job --from=cronjob/spec-template-worker-my-repo manual-test-$(date +%s)
```

---

## Troubleshooting

### Worker not running

- Verify the CronJob exists: `kubectl get cronjobs`
- Check schedule: the `example` overlay defaults to every 6 hours (`0 */6 * * *`)
- Look for failed Jobs: `kubectl get jobs | grep -i fail`

### Job failing

- Check pod logs: `kubectl logs <pod-name>`
- Common issues:
  - **GITHUB_TOKEN invalid:** Secret key `github-token` must be a valid PAT with repo write access
  - **ANTHROPIC_API_KEY invalid:** Secret key `anthropic-api-key` must be a valid API key
  - **Subscription auth failing:** Check that `~/.claude/.credentials.json` exists on the host and the `hostPath` volume path is correct. macOS/Windows users: credentials may be in the OS keychain — use API key mode instead
  - **Image pull error:** Ensure GHCR is accessible or mirror the image

### Testing locally before deploying

```bash
# Render and inspect the manifests
kubectl kustomize k8s/ | less

# Dry-run apply
kubectl apply -k k8s/ --dry-run=client
```

---

## Scaling

Scale horizontally by adding one overlay per target repo. Each overlay creates an independent CronJob with its own schedule, model, and target repo.
