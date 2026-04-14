# Scout Reports — GH Pages Publishing

Scout generates a `data.json` report each cycle at `docs/reports/{date}/data.json` in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format. This file explains how reports get published to GH Pages.

## How it works

1. Scout commits `docs/reports/YYYY-MM-DD/data.json` to `main`
2. `.github/workflows/reports.yml` triggers on that path change
3. The workflow calls the [`build-reports` composite action](https://github.com/NoahWright87/repo-report/tree/main/.github/actions/build-reports) from `repo-report`, which builds the React app against this repo's data
4. The built site is deployed to this repo's GH Pages

## Setup

**New repos:** Scout creates `.github/workflows/reports.yml` automatically during onboarding. One manual step is required after merging the onboarding PR:

> In **Settings → Pages**, set the source to **"Deploy from a branch"**, branch `gh-pages`, folder `/ (root)`. The `gh-pages` branch is created automatically on the first workflow run.

**Existing repos (Scout already running):** If Scout was onboarded before this workflow existed, add `.github/workflows/reports.yml` manually — see the workflow file in any freshly onboarded repo for the template, or re-run onboarding by temporarily removing `.agents/scout/config.yaml`. Then apply the same Pages setting above.

## Customizing the workflow

The workflow has a few parameters you may want to adjust in `.github/workflows/reports.yml`:

| Parameter | Default | Notes |
|-----------|---------|-------|
| `reports_path` | `docs/reports` | Match `reports_dir` in `.agents/scout/config.yaml` |
| `base_url` | `/<repo-name>` | Change to `/` if publishing to a custom root domain |
| `additional_static_dirs` | _(empty)_ | Add `docs,specs` etc. to publish other site content alongside reports |

## Versioning

The workflow currently uses `@main`, which always resolves to the latest release. Once version tags are created in `repo-report`, you can pin to a specific version (e.g. `@v1`) for stability, and roll back to a previous tag if a release breaks your site.
