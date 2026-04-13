# Scout Reports — GH Pages Setup

Scout generates a `data.json` report (in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format) each cycle under `docs/reports/{date}/data.json`. This file explains how to wire up automatic GH Pages publishing so those reports render as a proper site.

## How it works

1. Scout commits `docs/reports/YYYY-MM-DD/data.json` to main
2. `.github/workflows/reports.yml` triggers on that path change
3. It calls a composite action in `repo-report` that builds the React app against this repo's data
4. The built site is deployed to this repo's GH Pages

## Current status

`reports.yml` is wired up and ready. It's waiting on one thing: the composite action in `repo-report` doesn't exist yet.

**Once it's created, this workflow will work automatically.**

To enable it, open a Claude Code session in the `repo-report` repo and paste the instructions below.

---

## Instructions for the repo-report session

> Paste this into a Claude Code session opened in the `repo-report` repo.

---

I need you to create a composite GitHub Action in this repo that other repos can use to build and publish their Scout reports.

**Background:** Scout is an agent that generates `SprintReport` JSON files (the format this app renders) in each repo it runs against. Each calling repo has reports under `docs/reports/{date}/data.json`. They want to build the repo-report React app against their own data and deploy it to their GH Pages.

**What to create:** `.github/actions/build-reports/action.yml` — a composite action.

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `reports_path` | `docs/reports` | Path to the reports directory in the calling repo |
| `output_path` | `_site` | Where to write the built app |
| `base_url` | `/` | VITE_BASE_URL — set to `/<repo-name>` for GH Pages (e.g., `/spec-template`) |
| `additional_static_dirs` | `` | Comma-separated list of extra directories from the calling repo to copy into `output_path` alongside the app (e.g., `docs,specs`) |

**What the action must do:**

1. The action lives in `repo-report`, so `${{ github.action_path }}` points to `.github/actions/build-reports/` inside the repo-report checkout. The repo root is at `${{ github.action_path }}/../../..` — use that as the build source so the correct app version is always used for the ref/tag the caller specifies.

2. Clone the design system next to the repo root (the build expects `../design` to exist relative to the repo root — match exactly what `deploy.yml` does):
   ```bash
   git clone --depth 1 https://github.com/NoahWright87/design.git \
     "${{ github.action_path }}/../../.././../design"
   ```

3. Copy the calling repo's reports into the app's `public/reports/`:
   ```bash
   cp -r "$GITHUB_WORKSPACE/${{ inputs.reports_path }}/." \
     "${{ github.action_path }}/../../../public/reports/"
   ```

4. Auto-generate `public/reports/index.json` if one doesn't already exist in the copied data. Scan for `*/data.json` files, read `meta.title`, `meta.dateRange`, and `summary.stats` from each, and write a valid `ReportIndex` JSON:
   ```json
   { "team": "<repo name from GITHUB_REPOSITORY>", "reports": [ { "slug": "...", "title": "...", "dateRange": {...}, "stats": [...] } ] }
   ```
   Reports should be sorted newest-first by slug (the date string sorts correctly lexicographically).

5. Build the app:
   ```bash
   cd "${{ github.action_path }}/../../.."
   npm ci && VITE_BASE_URL="${{ inputs.base_url }}" npm run build
   ```

6. Copy output to `inputs.output_path`:
   ```bash
   cp -r "${{ github.action_path }}/../../../dist/." "$GITHUB_WORKSPACE/${{ inputs.output_path }}/"
   ```

7. If `additional_static_dirs` is non-empty, copy each comma-separated directory from the calling repo into `output_path` as a subdirectory:
   ```bash
   # e.g., for "docs,specs": copy ./docs → _site/docs/, ./specs → _site/specs/
   ```

**Versioning:** After creating the action, tag it so callers can pin to a version:
```bash
git tag v1
git push origin v1
```

Future breaking changes should bump to `v2`, etc. Non-breaking improvements can use `v1.1`, `v1.2` — update the `v1` floating tag to point at the latest non-breaking release:
```bash
git tag -f v1 <new-sha>
git push -f origin v1
```

**Also update `deploy.yml`** in this repo to use the new composite action for its own deployment (dogfooding), replacing the inline steps.

---

## After the composite action is created

1. Remove the note from `.github/workflows/pages.yml` (or delete `pages.yml` entirely — `reports.yml` passes `additional_static_dirs: docs,specs` so those pages keep publishing)
2. Update `reports.yml` if you want to pin to a specific version tag (e.g., `@v1.2`) instead of `@v1`
