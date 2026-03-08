# Change Log

This file lists the current and previous versions, along with the features that changed in each.

# Versions

## WIP

- TBD

## v0.7.0

- Add `worker/` — autonomous containerized runner (Dockerfile, entrypoint.sh, worker-instructions.md, README.md); cron job model with Docker volume state persistence, GHCR publishing
- Add scaffold detection + install mode + operate mode to worker: checks for `specs/AGENTS.md`; missing → copies `dist/` payload, opens bootstrap PR; present → runs intake + knock-out-todos via Claude CLI
- Add `scaffold/specs/` — template source files for the installable scaffold payload
- Add `scripts/generate-dist.sh` — generates `dist/` from scaffold sources + command files with auto-generated do-not-edit headers; commit dist/ for downstream consumption
- Add `dist/` — generated installable scaffold payload committed to repo for direct consumption
- Add `.github/workflows/build-worker.yml` — builds and publishes worker image to GHCR on pushes to `worker/` or `scripts/` on main
- Add `CONTRIBUTING.md` — scaffold source structure, dist/ regeneration workflow, manual installation without /respec
- Update `README.md` — add "Running on autopilot" section linking to worker runtime
- Fill in `specs/spec.md` with current two-layer system state
- Switch TODO item format from `- [ ]` checkboxes to plain `- ` bullets; update `/knock-out-todos` accordingly (remove Step 0 orphan scan, new grep pattern, remove → promote flow instead of check-then-move)
- Add `PHILOSOPHY.md` proximity section — explains how format affords behavior and the checkbox incident as a concrete example
- Add `/respec` Update step 5 — detects TODO format changes and offers to migrate existing TODO files; applies only with user approval
- Fix bootstrap PR deduplication: use deterministic branch name `scaffold/bootstrap`; check for open PR before creating a new one
- Fix install mode file copy: use `rsync --ignore-existing` so existing repo files are never overwritten
- Fix `/intake` Path 1 entry format: plain `- ` bullets instead of `- [ ]` checkboxes
- Fix dep TODO template: plain bullets in `scaffold/specs/deps/README.md`
- Pin `@anthropic-ai/claude-code` to `2.1.71` in Dockerfile to reduce supply chain risk; add `rsync` to system deps
- Remove undocumented/unimplemented `EXECUTION_MODE` param from Dockerfile and spec

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