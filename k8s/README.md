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
│   └── example/
│       └── kustomization.yaml # Example: patches in TARGET_REPO, schedule, MODEL
├── kustomization.yaml         # Top-level entry point (references overlays)
└── README.md
```

---

## Prerequisites

### 1. Create a Kubernetes Secret

The worker needs two secrets. Create them in the target namespace:

```bash
kubectl create secret generic spec-worker-secrets \
  --from-literal=anthropic-api-key='sk-ant-...' \
  --from-literal=github-token='ghp_...'
```

### 2. Ensure the worker image is accessible

The base manifests reference `ghcr.io/noahwright87/spec-template-worker`. If your cluster can't pull from GHCR, mirror the image to your own registry and update the `images` block in `k8s/kustomization.yaml`.

---

## Creating an overlay for your repo

1. Copy the example overlay:

```bash
cp -r k8s/overlays/example k8s/overlays/my-repo
```

2. Edit `k8s/overlays/my-repo/kustomization.yaml`:
   - Set `nameSuffix` to something unique (e.g., `-my-repo`)
   - Set `TARGET_REPO` to your `owner/repo`
   - Adjust `schedule` (cron expression) as needed
   - Optionally set `MODEL` (e.g., `claude-sonnet-4-5`, `claude-haiku-4-5`)

3. Add the overlay to `k8s/kustomization.yaml`:

```yaml
resources:
  - overlays/my-repo
```

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
