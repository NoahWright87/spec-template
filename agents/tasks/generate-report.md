# Generate Report

## Purpose

Generate a progress report from pre-gathered repository activity data. The report is saved to `{reports_dir}/{date}.md` where `{reports_dir}` comes from `.agents/scout/config.yaml` (default: `docs/reports`) and `{date}` is the report date from the Situation Report. After generating the report, advance `next_report_date` in `.agents/scout/config.yaml`.

## Preconditions

- `gh` CLI is authenticated and available.
- The startup script has run and populated `/tmp/scout-data/` with activity data.

## Steps

### Step 1 — Read pre-gathered data

The startup script has already gathered all repository activity data. Read the **Situation Report** for summary metrics, file paths, the **report date**, and the **reports directory** (use these for the output path — do not compute or guess them). Then read the data files from `/tmp/scout-data/` for full details:

- `/tmp/scout-data/git-log.txt` — commit log since baseline
- `/tmp/scout-data/merged-prs.json` — recently merged PRs with descriptions
- `/tmp/scout-data/closed-issues.json` — recently closed issues
- `/tmp/scout-data/open-prs.json` — currently open PRs
- `/tmp/scout-data/open-issues.json` — currently open issues
- `/tmp/scout-data/todo-counts.txt` — TODO marker counts

### Step 2 — Create reports directory

Use the reports directory from the Situation Report:

```bash
mkdir -p {reports_dir}
```

### Step 3 — Generate report

Read the report template specified in `.agents/scout/config.yaml` under `report_instructions` (e.g., `.agents/scout/templates/report-technical.md`). This is a report skeleton with HTML comment guidance in each section. Copy it, replace `{date}` and `{baseline}` with actual values from the Situation Report, and fill in each section using the pre-gathered data.

Save to `{reports_dir}/{date}.md`.

### Step 4 — Advance next_report_date

The next report date has been pre-computed by the startup script and is shown in the Situation Report. Read that value and update `.agents/scout/config.yaml` with the new `next_report_date`.

**IMPORTANT:** Commit the report and the config update in the same commit. This ensures that if the commit is reverted or the PR is closed, both the report and the date advancement are rolled back together — preventing duplicate reports.

## Preferred tools

- **Read** — read data files from `/tmp/scout-data/`, report template, previous reports, config
- **Write** — create the report file
- **Edit** — update `.agents/scout/config.yaml`
- **Bash** — `mkdir`, `gh` (if additional queries are needed)

## Inputs

- `/tmp/scout-data/` files — pre-gathered activity data from startup script
- Situation Report — summary metrics, report date, reports directory, and pre-computed next report date
- `.agents/scout/config.yaml` — report template path, reports directory, and interval settings
- `.agents/scout/templates/` — report templates (skeleton with embedded guidance)
- `{reports_dir}/` — previous reports (for context)

## Outputs

- `{reports_dir}/{date}.md` — the generated progress report
- `.agents/scout/config.yaml` — updated `next_report_date`
