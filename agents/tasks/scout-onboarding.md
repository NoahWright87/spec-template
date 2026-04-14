# Scout Onboarding

## Purpose

Open a PR to initialize Scout for a repository. The startup script has already created `.agents/scout/` with default config, report templates, and notes. This task commits those files and adds review comments so the team can customize before the first report.

## Preconditions

- The startup script's `init.sh` has already run and created:
  - `.agents/scout/config.yaml` — default configuration
  - `.agents/scout/templates/` — report templates
  - `.agents/scout/NOTES.md` — starter notes
  - `.github/workflows/reports.yml` — GH Pages publishing workflow

## Steps

### Step 1 — Commit and open PR

Commit all of the following in a single commit, then open a PR targeting `main`:
- Everything under `.agents/scout/`
- `.github/workflows/reports.yml`

The PR description should briefly explain what Scout does, that the team should review the config and templates before the first report runs, and that reports will be published to GH Pages automatically once the workflow is active. Point to `.agents/scout/templates/README.md` for an overview of the available templates.

### Step 2 — Add inline review comments

After the PR is created, add **three** inline review comments using `gh api`:

1. On `.agents/scout/config.yaml`, on the `report_instructions` line:
   > See `.agents/scout/templates/` for available report formats. The default is `templates/report-technical.md` (detailed, for the dev team). Change to `templates/report-summary.md` for a high-level stakeholder format, or customize either file to match your needs.

2. On `.agents/scout/config.yaml`, on the `next_report_date` line:
   > When does your current sprint start and end? I'll align this date to your sprint cycle.

3. On `.github/workflows/reports.yml`, on the `base_url` line:
   > This is set to `/<repo-name>` which is correct for most GitHub Pages deployments. If this repo is published at the root of a custom domain (not a `/<repo>` subdirectory), change this to `/`.

### Step 3 — Stop

After opening the onboarding PR, **stop**. Do not proceed to report generation. The team needs to review and merge the config before the first report is generated.

## Outputs

- A PR containing `.agents/scout/` (config, templates, notes) and `.github/workflows/reports.yml`
- Three inline review comments covering template choice, sprint cadence, and GH Pages base URL
