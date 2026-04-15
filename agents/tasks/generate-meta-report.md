# Generate Meta-Report

## Purpose

Generate a single progress report that aggregates activity across the meta repo and one or more subordinate repos. The report is saved as `{reports_dir}/{date}/data.json` in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format, with `meta.repos` covering all repos. After generating the report, advance `next_report_date` in `.agents/scout/config.yaml`.

## Preconditions

- `gh` CLI is authenticated and available.
- The startup script has run and populated:
  - `/tmp/scout-data/` — meta repo activity data
  - `/tmp/scout-data/repos/{owner}/{repo}/` — per-subordinate-repo activity data

## Steps

### Step 1 — Read pre-gathered data

Read the **Situation Report** for the report date, reports directory, and list of subordinate repos. Then read all data files:

**Meta repo (`/tmp/scout-data/`):**
- `git-log.txt` — commit log since baseline
- `git-stat.txt` — diff stats since baseline
- `merged-prs.json` — recently merged PRs with descriptions
- `closed-issues.json` — recently closed issues
- `open-prs.json` — currently open PRs
- `open-issues.json` — currently open issues

**Each subordinate repo (`/tmp/scout-data/repos/{owner}/{repo}/`):**
- Same file structure as the meta repo

### Step 2 — Create output directory

```bash
mkdir -p {reports_dir}/{date}
```

### Step 3 — Build the JSON report

Construct a JSON object matching the `SprintReport` schema. Use the template file referenced in `.agents/scout/config.yaml` under `report_instructions` for structure guidance.

#### `meta` object

| Field | Value |
|-------|-------|
| `title` | `"Progress Report — {date}"` |
| `team` | Org or team name (extract org from `TARGET_REPO`, e.g. `"myorg"`) |
| `dateRange` | `{ "start": "{baseline_date}", "end": "{date}" }` |
| `repos` | Array with one entry per repo (meta repo first, then subordinates) |
| `generatedAt` | Current ISO 8601 timestamp |

Build the `repos` array from the Situation Report's repo list. Each entry:
```json
{ "name": "{repo-name}", "url": "https://github.com/{owner}/{repo-name}" }
```

#### `summary` slide

- **`type`**: `"summary"`
- **`slug`**: `"summary"`
- **`title`**: `"Summary"`
- **`stats`**: Aggregate counts across **all** repos:
  - PRs merged — sum of `merged-prs.json` lengths across all repos
  - Issues closed — sum of `closed-issues.json` lengths across all repos
  - Open PRs — sum of `open-prs.json` lengths across all repos
  - Open `intake:filed` issues — sum of filtered `open-issues.json` across all repos
- **`highlights`**: Write a 3–5 sentence narrative covering all repos — what shipped, what's active, notable cross-repo patterns.
- **`detailBlocks`**: One `contributor-list` block aggregating contributors across all repos:
  - Group merged PRs by `author.login` across all repos to get `prsMerged` per contributor
  - Count commits per author from all `git-log.txt` files
  - Include `name`, `username`, `commits`, `prsMerged`

#### `themes` array

Organize themes by repo. For each repo with activity, produce a theme group labeled with the repo name.

**Completed work per repo** — for each repo that has merged PRs, group them by theme and produce theme slides:

```json
{
  "type": "theme",
  "slug": "{repo-slug}-{theme-slug}",
  "title": "{owner}/{repo} — {Group Name}",
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

Omit the repo prefix in `title` if there is only one repo with activity (keeps the report clean for near-single-repo cases).

**In Progress** — one combined theme for all open PRs across repos:

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
          "description": "<repo name — branch name or brief status note>"
        }
      ]
    }
  ]
}
```

Omit this theme if there are no open PRs across any repo.

**Upcoming** — one combined theme for all `intake:filed` issues across repos:

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
          "description": "<repo name — size label if present>"
        }
      ]
    }
  ]
}
```

Omit this theme if there are no `intake:filed` issues across any repo.

### Step 4 — Write the report

Save the complete JSON object to `{reports_dir}/{date}/data.json`.

Validate that the JSON is well-formed before writing (use the Bash tool to pipe through `jq .` if needed).

### Step 5 — Advance next_report_date

The next report date is shown in the Situation Report. Update `.agents/scout/config.yaml` with the new `next_report_date`.

**IMPORTANT:** Commit the report and the config update in the same commit.

## Preferred tools

- **Read** — read data files from `/tmp/scout-data/` and `/tmp/scout-data/repos/`, report template, config
- **Write** — create `{reports_dir}/{date}/data.json`
- **Edit** — update `.agents/scout/config.yaml`
- **Bash** — `mkdir`, `jq` (for JSON validation), `ls /tmp/scout-data/repos/` (to enumerate subordinate repos)

## Inputs

- `/tmp/scout-data/` — meta repo activity data (git-log.txt, merged-prs.json, etc.)
- `/tmp/scout-data/repos/{owner}/{repo}/` — per-subordinate-repo activity data (same structure)
- Situation Report — report date, reports directory, next report date, repo list
- `.agents/scout/config.yaml` — report template path, reports directory, interval settings
- `.agents/scout/templates/` — JSON example template (schema reference and guidance)

## Outputs

- `{reports_dir}/{date}/data.json` — the generated meta progress report in SprintReport JSON format
- `.agents/scout/config.yaml` — updated `next_report_date`
