# Generate Meta-Report

## Purpose

Generate a combined progress report for the meta repo and its sub-scouts. The report covers:
1. The meta repo's own activity (from raw data in `/tmp/scout-data/`, same as a normal Scout run)
2. A summary section per sub-scout, drawn from each sub-scout's already-generated `data.json`

The output is saved as `{reports_dir}/{date}/data.json` in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format. After generating the report, advance `next_report_date` in `.agents/scout/config.yaml`.

## Preconditions

- The startup script has run and populated:
  - `/tmp/scout-data/` — meta repo activity (same files as a normal Scout run)
  - `/tmp/scout-data/meta-index.json` — repo index with stats, URLs, and `has_report` flags
  - `/tmp/scout-data/meta-stats.json` — fleet-wide aggregate totals
  - `/tmp/scout-data/subordinates/{owner}/{repo}/latest-report.json` — fetched sub-scout reports (when `has_report: true`)

## Steps

### Step 1 — Read pre-computed data

Read the **Situation Report** for the report date, reports directory, next report date, and the list of sub-scouts (including which have reports and which don't).

Read:
- `/tmp/scout-data/meta-index.json` — index of all repos
- `/tmp/scout-data/meta-stats.json` — aggregate totals
- `/tmp/scout-data/merged-prs.json`, `closed-issues.json`, `open-prs.json`, `open-issues.json`, `git-log.txt` — meta repo raw data
- For each sub-scout where `has_report: true`: read its `report_file` (the fetched `data.json`)

### Step 2 — Create output directory

```bash
mkdir -p {reports_dir}/{date}
```

### Step 3 — Build the JSON report

Use the template at `.agents/scout/config.yaml` → `report_instructions` for schema reference.

#### `meta` object

| Field | Value |
|-------|-------|
| `title` | `"Progress Report — {date}"` |
| `team` | Org name (owner portion of `TARGET_REPO`) |
| `dateRange` | `{ "start": "{baseline_date}", "end": "{date}" }` |
| `repos` | One entry per repo from `meta-index.json`; use `reports_url` as `url` for sub-scouts, `github_url` for the meta repo |
| `generatedAt` | Current ISO 8601 timestamp |

#### `summary` slide

- **`stats`**: Use values from `meta-stats.json` directly — `total_prs_merged`, `total_issues_closed`, `total_open_prs`, `total_intake_filed` (only counts repos where `has_report: true`)
- **`highlights`**: 3–5 sentence narrative covering the meta repo's own activity and any notable patterns across sub-scouts
- **`detailBlocks`**: One `contributor-list` block from the meta repo's own `merged-prs.json` and `git-log.txt` (same logic as `generate-report.md`)

#### `themes` array — meta repo own activity

Follow the same grouping logic as `generate-report.md` for the meta repo's own data:

- Completed work — group `merged-prs.json` entries into named themes; each theme slug prefixed `meta-` (e.g. `meta-auth-improvements`)
- In Progress — open PRs from `open-prs.json` (omit if none)
- Upcoming — `intake:filed` issues from `open-issues.json` (omit if none)

#### `themes` array — sub-scout summaries

For each sub-scout in `meta-index.json`, append one theme slide:

**Sub-scout with `has_report: true`** — read its `report_file` and extract:
- `summary.highlights` for the description
- Up to 3 top themes (by number of PRs) for detail

```json
{
  "type": "theme",
  "slug": "{sub-name}-summary",
  "title": "{owner}/{repo}",
  "status": "completed",
  "description": "<first sentence of sub-scout's summary.highlights>",
  "detailBlocks": [
    {
      "type": "link-list",
      "title": "Highlights",
      "links": [
        {
          "label": "<theme title from sub-scout report>",
          "url": "<reports_url from meta-index>",
          "type": "link",
          "description": "<theme description from sub-scout report>"
        }
        // repeat for up to 3 themes
      ]
    },
    {
      "type": "link-list",
      "title": "Full Report",
      "links": [
        {
          "label": "See full {owner}/{repo} Scout report →",
          "url": "<reports_url from meta-index>",
          "type": "link",
          "description": "Report from {report_date}"
        }
      ]
    }
  ]
}
```

**Sub-scout with `has_report: false`** — include a placeholder theme:

```json
{
  "type": "theme",
  "slug": "{sub-name}-pending",
  "title": "{owner}/{repo} — Report Pending",
  "status": "in-progress",
  "description": "Scout report has not run yet for this repo. Will be included in the next report cycle.",
  "detailBlocks": []
}
```

### Step 4 — Handle missing sub-scouts (PR comment)

If **any** sub-scouts have `has_report: false`:

After writing the report file, post a comment on the PR noting which sub-scout reports are not yet available:

```bash
gh pr comment "$WORKER_PR_NUMBER" --body "🤖 Claude ($AGENT_NAME): The following sub-scout reports were not available for this cycle and will be included once their Scout has run: <list repos>. This report will be updated automatically on the next scheduled run."
```

### Step 5 — Write the report

Save the complete JSON to `{reports_dir}/{date}/data.json` and validate:

```bash
jq . {reports_dir}/{date}/data.json > /dev/null
```

### Step 6 — Advance next_report_date

Update `.agents/scout/config.yaml` with the new `next_report_date` from the Situation Report.

**IMPORTANT:** Commit the report and config update in the same commit.

## Preferred tools

- **Read** — `meta-index.json`, `meta-stats.json`, sub-scout `report_file` paths, meta repo data files, template, config
- **Write** — `{reports_dir}/{date}/data.json`
- **Edit** — `.agents/scout/config.yaml`
- **Bash** — `mkdir`, `jq .` (validation), `gh pr comment` (missing sub-scout notice)

## Inputs

- `/tmp/scout-data/meta-index.json` — repo index with `has_report`, `report_file`, stats, URLs
- `/tmp/scout-data/meta-stats.json` — pre-computed fleet totals
- `/tmp/scout-data/` — meta repo raw activity data
- Sub-scout `report_file` paths (from `meta-index.json`) — already-processed SprintReport JSON
- Situation Report — report date, reports directory, next report date, missing sub-scouts list
- `.agents/scout/config.yaml` — template path, reports directory

## Outputs

- `{reports_dir}/{date}/data.json` — combined SprintReport
- `.agents/scout/config.yaml` — updated `next_report_date`
- PR comment (when sub-scouts are missing)
