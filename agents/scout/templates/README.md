# Scout Report Templates

Pre-made report templates that Scout copies into target repos during onboarding. Each template is an annotated JSON example showing the `SprintReport` schema consumed by [repo-report](https://github.com/NoahWright87/repo-report). Scout uses these as a structural reference when generating reports.

## Available Templates

- **report-technical.md** — Detailed, for the development team. Includes contributor breakdown, per-area PR grouping, and upcoming filed issues with size labels.
- **report-summary.md** — High-level stakeholder summary. Focuses on outcomes with fewer themes and no contributor detail.

## How It Works

During onboarding, Scout copies these templates into `.agents/scout/templates/` in the target repo. The `report_instructions` field in `.agents/scout/config.yaml` points to the active template (default: `templates/report-technical.md`).

When generating a report, Scout reads the template to understand the expected JSON structure, then builds a `{reports_dir}/{date}/data.json` file populated with real data from `/tmp/scout-data/`.

## Customization

Teams can:
- Edit either template to adjust which slides, stats, or detail blocks are included
- Create a new template following the same `jsonc` format
- Change `report_instructions` in `.agents/scout/config.yaml` to point to a different template

## Template Format

Each template is a markdown file containing a `jsonc` code block — JSON with `//` comments explaining each field. Scout reads the structure and guidance, then produces a clean JSON file (no comments) as output.

The output path is always `{reports_dir}/{date}/data.json` regardless of which template is used.
