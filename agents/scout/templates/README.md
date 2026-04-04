# Scout Report Templates

Pre-made report templates that Scout copies into target repos during onboarding. Each template is a report skeleton — Scout fills in the sections using pre-gathered data.

## Available Templates

- **report-technical.md** — Detailed, for the development team. Includes commit-level changes, architectural decisions, and technical debt observations.
- **report-summary.md** — High-level progress summary. Focuses on outcomes, feature progress, and blockers.

## How It Works

During onboarding, Scout copies these templates into `.agents/scout/templates/` in the target repo. The scout config's `report_instructions` field points to one of them (default: `templates/report-technical.md`).

## Customization

Teams can:
- Edit either template to match their needs
- Create entirely new templates following the same pattern
- Change `report_instructions` in `.agents/scout/config.yaml` to point to a different template

## Template Format

Each template is a markdown skeleton with HTML comments guiding what to write in each section. Scout copies the template, replaces `{date}` and `{baseline}` with actual values, and fills in each section based on the pre-gathered data.
