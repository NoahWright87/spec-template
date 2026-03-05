# Change Log

This file lists the current and previous versions, along with the features that changed in each.

# Versions

## WIP

- *Add current progress here.*

## v0.6.2

- Rewrite `README.md` — human-friendly pitch, SpecKit comparison, commands overview, updated "What gets installed" table (adds `spec-backfill.md` and `spec-check.yml`)

## v0.6.1

- Add `.claude/commands/README.md` — human-friendly guide to the commands with Mermaid flow diagrams; not installed into target repos

## v0.6

- Add `specs/deps/` directory — dep specs (outsider knowledge) + outbound TODO files for cross-repo work
- Add 3-way intake routing to `/intake`: Routed / Duplicate+boost / Needs more info
- Add Step 0 to `/intake`: check waiting items (date-annotated), re-process on new comments, re-surface stale items after 7 days (configurable), support snooze annotations
- Add comment-as-question escape hatch: `/intake` posts to GH issues when it can't route, clearly marked as from Claude
- Update `/knock-out-todos` with dep TODO flow: opening downstream GH issues + cross-linking
- Update `/knock-out-todos` with dep sub-bullet reconciliation: checks downstream issue status before implementing
- Add `specs/deps/README.md` to managed files in `/respec`
- Issue #1 labeled `intake:filed`

## v0.5

- Add `.github/workflows/spec-check.yml` — PR check that warns when source files change without a corresponding spec update; informational only, never blocks merging
- Add `spec-check.yml` to managed files in `/respec`

## v0.4

- Add `/spec-backfill` command — bootstrap or improve specs mirroring the codebase; idempotent re-runs act as a completeness check
- Add `> **TODO:**` placeholder convention — greppable, renders visibly in GitHub, tracked by `/spec-backfill`
- Document placeholder convention in `specs/AGENTS.md`
- Add `/spec-backfill` to managed files in `/respec`

## v0.3

- Add GitHub Issues integration to `/intake` — pulls open issues, applies `intake:filed/rejected/ignore` labels
- Add `/knock-out-todos` GH integration — reads issue details/comments before implementing, closes issues on completion
- Add `PHILOSOPHY.md` repetition principle — important rules stated in multiple files; `## Reminders` sections throughout
- Add `{feature}.todo.md` file type — elaborated plans / PRDs that live in-repo; split rules apply to TODO specs too
- Add evolving conventions pattern — repeated user corrections become new bullets in `specs/AGENTS.md`

## v0.2

- Add `/respec` command — one command that handles fresh install, adaptation, and update
- Add `PHILOSOPHY.md` — principles doc covering affirmative language, minimalism, and specs as source of truth
- Add `specs/AGENTS.md` — spec-scoped agent instructions, installed into target repos by `/respec`
- Update `README.md` — lead with quick start, copy/paste install prompt, opt-out instructions
- Reformat `AGENTS.md` — same content, clearer structure, affirmative language throughout

## v0.1

- Initial version.