# Generate Report

## Purpose

Generate a progress report from pre-gathered repository activity data. The report is saved as `{reports_dir}/{date}/data.json` — a JSON file in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format. After generating the report, advance `next_report_date` in `.agents/scout/config.yaml`.

## Preconditions

- `gh` CLI is authenticated and available.
- The startup script has run and populated `/tmp/scout-data/` with activity data.

## Steps

### Step 1 — Read pre-gathered data

The startup script has already gathered all repository activity data. Read the **Situation Report** for summary metrics, file paths, the **report date**, and the **reports directory** (use these for the output path — do not compute or guess them). Then read the data files from `/tmp/scout-data/` for full details:

- `/tmp/scout-data/git-log.txt` — commit log since baseline
- `/tmp/scout-data/git-stat.txt` — diff stats since baseline
- `/tmp/scout-data/merged-prs.json` — recently merged PRs with descriptions
- `/tmp/scout-data/closed-issues.json` — recently closed issues
- `/tmp/scout-data/open-prs.json` — currently open PRs
- `/tmp/scout-data/open-issues.json` — currently open issues

### Step 2 — Create output directory

```bash
mkdir -p {reports_dir}/{date}
```

### Step 3 — Build the JSON report

Construct a JSON object matching the `SprintReport` schema. Use the template file referenced in `.agents/scout/config.yaml` under `report_instructions` (e.g., `.agents/scout/templates/report-technical.md`) as a reference for structure and field guidance — it shows an annotated example of the full schema.

#### `meta` object

| Field | Value |
|-------|-------|
| `title` | `"Progress Report — {date}"` |
| `team` | Repo name (from `TARGET_REPO` or git remote) |
| `dateRange` | `{ "start": "{baseline_date}", "end": "{date}" }` |
| `repos` | Array with one entry: `{ "name": "<repo>", "url": "https://github.com/<owner>/<repo>" }` |
| `generatedAt` | Current ISO 8601 timestamp |

#### `summary` slide

- **`type`**: `"summary"`
- **`slug`**: `"summary"`
- **`title`**: `"Summary"`
- **`stats`**: Pull from Situation Report metrics:
  - PRs merged (value from `merged-prs.json` count)
  - Issues closed (value from `closed-issues.json` count)
  - Open PRs (value from `open-prs.json` count)
  - Open `intake:filed` issues (value from intake count in Situation Report)
- **`highlights`**: Write a 3-5 sentence narrative summarizing the period — what shipped, what's active, notable patterns. Let the data speak; avoid speculation.
- **`detailBlocks`**: One `contributor-list` block:
  - Group `merged-prs.json` entries by `author.login` to get `prsMerged` per contributor
  - Count commits per author from `git-log.txt`
  - Include `name` (from PR author display name if available, else username), `username`, `commits`, `prsMerged`

#### `themes` array

**Completed work** — group merged PRs by theme:

Analyze `merged-prs.json` and identify natural groupings (e.g., "Auth improvements", "CI/CD", "Bug fixes"). For each group, create a theme slide:

```json
{
  "type": "theme",
  "slug": "<kebab-case-title>",
  "title": "<Group Name>",
  "status": "completed",
  "description": "<one sentence summary of what this group accomplished>",
  "detailBlocks": [
    {
      "type": "link-list",
      "title": "Merged PRs",
      "links": [
        {
          "label": "<PR title>",
          "url": "<PR url>",
          "type": "pr",
          "description": "<one sentence from PR body — what problem it solved>"
        }
      ]
    }
  ]
}
```

**In Progress** — open PRs from `open-prs.json`:

```json
{
  "type": "theme",
  "slug": "in-progress",
  "title": "In Progress",
  "status": "in-progress",
  "detailBlocks": [
    {
      "type": "link-list",
      "title": "Open PRs",
      "links": [
        {
          "label": "<PR title>",
          "url": "<PR url>",
          "type": "pr",
          "description": "<branch name or brief status note>"
        }
      ]
    }
  ]
}
```

Omit this theme if there are no open PRs.

**Upcoming** — open issues labeled `intake:filed` from `open-issues.json`:

Filter `open-issues.json` for issues where `labels` contains an entry with `name == "intake:filed"`. For each issue, include the `size:*` label value (S, M, L, XL) in the description if present.

```json
{
  "type": "theme",
  "slug": "upcoming",
  "title": "Upcoming",
  "status": "in-progress",
  "detailBlocks": [
    {
      "type": "link-list",
      "title": "Filed Issues",
      "links": [
        {
          "label": "<issue title>",
          "url": "<issue url>",
          "type": "issue",
          "description": "<size label if present, e.g. 'size: M'>"
        }
      ]
    }
  ]
}
```

Omit this theme if there are no `intake:filed` issues.

### Step 4 — Write the report

Save the complete JSON object to `{reports_dir}/{date}/data.json`.

Validate that the JSON is well-formed before writing (use the Bash tool to pipe through `jq .` if needed).

### Step 5 — Advance next_report_date

The next report date has been pre-computed by the startup script and is shown in the Situation Report. Read that value and update `.agents/scout/config.yaml` with the new `next_report_date`.

**IMPORTANT:** Commit the report and the config update in the same commit. This ensures that if the commit is reverted or the PR is closed, both the report and the date advancement are rolled back together — preventing duplicate reports.

## Preferred tools

- **Read** — read data files from `/tmp/scout-data/`, report template, config
- **Write** — create `{reports_dir}/{date}/data.json`
- **Edit** — update `.agents/scout/config.yaml`
- **Bash** — `mkdir`, `jq` (for JSON validation), `gh` (if additional queries are needed)

## Inputs

- `/tmp/scout-data/` files — pre-gathered activity data from startup script
- Situation Report — summary metrics, report date, reports directory, and pre-computed next report date
- `.agents/scout/config.yaml` — report template path, reports directory, and interval settings
- `.agents/scout/templates/` — JSON example template (schema reference and guidance)

## Outputs

- `{reports_dir}/{date}/data.json` — the generated progress report in SprintReport JSON format
- `.agents/scout/config.yaml` — updated `next_report_date`
