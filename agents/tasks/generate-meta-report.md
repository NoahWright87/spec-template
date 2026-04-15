# Generate Meta-Report

## Purpose

Generate a single progress report that aggregates activity across the meta repo and its subordinate repos. The report is saved as `{reports_dir}/{date}/data.json` in the [repo-report](https://github.com/NoahWright87/repo-report) `SprintReport` format. After generating the report, advance `next_report_date` in `.agents/scout/config.yaml`.

The startup script has done all the data-gathering and arithmetic. Your job is synthesis: write narratives, group PRs into themes, and assemble the final JSON.

## Preconditions

- The startup script has run and populated:
  - `/tmp/scout-data/` — meta repo activity data
  - `/tmp/scout-data/repos/{owner}/{repo}/` — per-subordinate-repo activity data
  - `/tmp/scout-data/meta-index.json` — pre-built repo index with stats and URLs
  - `/tmp/scout-data/meta-stats.json` — pre-computed fleet-wide totals

## Steps

### Step 1 — Read pre-computed data

Read the **Situation Report** for the report date, reports directory, and next report date.

Then read these pre-computed files (do not re-fetch from GitHub):

- `/tmp/scout-data/meta-index.json` — array of repo objects, each with:
  - `repo` — full `owner/repo` slug
  - `name` — repo name only
  - `github_url` — `https://github.com/owner/repo`
  - `reports_url` — `https://owner.github.io/repo/` (this repo's Scout reports page)
  - `data_dir` — local path to this repo's data files
  - `is_meta` — `true` for the meta repo, `false` for subordinates
  - `prs_merged`, `issues_closed`, `open_prs`, `open_issues`, `intake_filed` — pre-counted

- `/tmp/scout-data/meta-stats.json` — fleet totals:
  - `total_prs_merged`, `total_issues_closed`, `total_open_prs`, `total_intake_filed`

For each repo in the index, read its `data_dir` files for full detail:
- `merged-prs.json` — merged PRs with titles, URLs, authors, and body
- `open-prs.json` — open PRs
- `open-issues.json` — open issues (filter for `intake:filed` label)
- `git-log.txt` — commits since baseline (for contributor counts)

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
| `team` | Org name (the owner portion of `TARGET_REPO`, e.g. `"myorg"`) |
| `dateRange` | `{ "start": "{baseline_date}", "end": "{date}" }` |
| `repos` | One entry per repo from `meta-index.json` — use `reports_url` as `url` for subordinate repos so readers can navigate to their full Scout reports; use `github_url` for the meta repo |
| `generatedAt` | Current ISO 8601 timestamp |

#### `summary` slide

- **`stats`**: Use values from `meta-stats.json` directly — no arithmetic needed:
  - PRs Merged → `total_prs_merged`
  - Issues Closed → `total_issues_closed`
  - Open PRs → `total_open_prs`
  - Filed Issues → `total_intake_filed`
- **`highlights`**: 3–5 sentence narrative covering all repos — what shipped, what's active, notable cross-repo patterns.
- **`detailBlocks`**: One `contributor-list` block. Aggregate contributors across all repos:
  - For each repo, read `merged-prs.json` and count `prsMerged` per `author.login`
  - For each repo, parse `git-log.txt` lines (`<sha> <message>`) and count commits per author prefix (use the author field from the PR list, not git log, for accuracy — git-log.txt is for volume reference)
  - Merge counts by `username` across repos
  - Include `name`, `username`, `commits`, `prsMerged`

#### `themes` array

**Completed work** — for each repo that has merged PRs, read its `merged-prs.json` and group PRs into natural themes. For each theme, produce a slide:

```json
{
  "type": "theme",
  "slug": "{repo-name}-{theme-slug}",
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
    },
    {
      "type": "link-list",
      "title": "Full Report",
      "links": [
        {
          "label": "See all {owner}/{repo} activity →",
          "url": "<reports_url from meta-index.json for this repo>",
          "type": "link",
          "description": "Detailed Scout report for this repo"
        }
      ]
    }
  ]
}
```

Use the `reports_url` from `meta-index.json` for the "Full Report" link. This lets readers drill into a single repo's Scout reports for more detail.

If only one repo has merged PRs, omit the `{owner}/{repo} —` prefix in the theme title to keep the report clean.

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
          "description": "<owner/repo — branch name or brief status note>"
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
          "description": "<owner/repo — size label if present, e.g. 'size: M'>"
        }
      ]
    }
  ]
}
```

Omit this theme if there are no `intake:filed` issues across any repo.

### Step 4 — Write the report

Save the complete JSON object to `{reports_dir}/{date}/data.json`.

Validate that the JSON is well-formed before writing:
```bash
cat {reports_dir}/{date}/data.json | jq . > /dev/null
```

### Step 5 — Advance next_report_date

The next report date is in the Situation Report. Update `.agents/scout/config.yaml`:

```yaml
next_report_date: "{next_report_date}"
```

**IMPORTANT:** Commit the report and the config update in the same commit.

## Preferred tools

- **Read** — read `meta-index.json`, `meta-stats.json`, per-repo data files, template, config
- **Write** — create `{reports_dir}/{date}/data.json`
- **Edit** — update `.agents/scout/config.yaml`
- **Bash** — `mkdir`, `jq .` (validation only)

## Inputs

- `/tmp/scout-data/meta-index.json` — pre-built repo index with stats and URLs
- `/tmp/scout-data/meta-stats.json` — pre-computed fleet-wide totals
- `/tmp/scout-data/` and `/tmp/scout-data/repos/{owner}/{repo}/` — per-repo activity files
- Situation Report — report date, reports directory, next report date
- `.agents/scout/config.yaml` — report template path, reports directory
- `.agents/scout/templates/` — JSON example template (schema reference)

## Outputs

- `{reports_dir}/{date}/data.json` — meta progress report in SprintReport JSON format
- `.agents/scout/config.yaml` — updated `next_report_date`
