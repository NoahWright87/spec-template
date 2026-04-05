# Scout Onboarding

## Purpose

Open a PR to initialize Scout for a repository. The startup script has already created `.agents/scout/` with default config, report templates, and notes. This task commits those files and adds review comments so the team can customize before the first report.

## Preconditions

- The startup script's `init.sh` has already run and created `.agents/scout/` with:
  - `config.yaml` — default configuration
  - `templates/` — report templates (technical and stakeholder)
  - `NOTES.md` — starter notes

## Steps

### Step 1 — Commit and open PR

Commit all files under `.agents/scout/` in a single commit, then open a PR targeting `main`.

The PR description should briefly explain what Scout does and that the team should review the config and report templates before the first report runs. Point to `.agents/scout/templates/README.md` for an overview of the available templates.

### Step 2 — Add inline review comments

After the PR is created, add **two** inline review comments using `gh api`:

1. On `.agents/scout/config.yaml`, on the `report_instructions` line:
   > See `.agents/scout/templates/` for available report formats. The default is `templates/report-technical.md` (detailed, for the dev team). Change to `templates/report-stakeholder.md` for a high-level stakeholder format, or customize either file to match your needs.

2. On `.agents/scout/config.yaml`, on the `next_report_date` line:
   > When does your current sprint start and end? I'll align this date to your sprint cycle.

### Step 3 — Stop

After opening the onboarding PR, **stop**. Do not proceed to report generation. The team needs to review and merge the config before the first report is generated.

## Outputs

- A PR containing `.agents/scout/` with config, templates, and notes
- Two inline review comments asking about template preference and sprint cadence
