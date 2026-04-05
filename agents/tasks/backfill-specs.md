# Backfill Specs

## Purpose

Bootstrap or improve specs that mirror the codebase. Works for greenfield repos with no specs, brownfield repos with partial coverage, and already-spec'd repos that need a completeness check.

## Preconditions

- Repository exists with source code to document.

## Steps

**`$ARGUMENTS`** — optional plain-language scope or depth hint. Examples:
- *(no arguments)* — scan for gaps and incomplete specs, fill what you can
- `go deep in the auth module` — read source + tests for that area and fill specs
- `just map the top level` — create top-level placeholders only, skip submodules
- `check completeness` — report placeholder counts without creating anything

Re-running this task at any time is the completeness check. It is idempotent.

---

### Phase 1 — Assess the repo

Use Glob and Grep to build a picture of the current state:

**Incomplete specs** — use Grep to find TODO markers across all `specs/**/*.md` files. Search for both `> **TODO:**` (bolded) and `> TODO:` (unbolded) — either format signals an unfilled section. Count placeholders per file. These are higher priority than creating new files — filling existing gaps is cheaper to review.

**Existing specs coverage** — map what already exists under `specs/`. Note which source modules already have corresponding spec files.

**Source roots** — use Glob to discover: `src/`, `app/`, `lib/`, `packages/*/src/`, `services/*/src/`. Note all that exist.

**Test roots** — look for: `test/`, `tests/`, `__tests__/`, `spec/` (non-spec-template), `cypress/`, `playwright/`, `e2e/`, `integration/`. Note all that exist.

**Gaps** — source modules with no corresponding spec file.

If `$ARGUMENTS` names a specific module or area, note it — that area gets priority.

---

### Phase 2 — Decide what to do (mode-dependent)

**Headless / unsupervised mode** (running as a worker agent):

Do not wait for user input. Use conservative defaults:
- Fill incomplete specs (Phase 3) before creating new ones (Phase 4)
- Limit scope: create at most **3 new spec files per run** (keep PRs small and reviewable)
- Skip deep reads unless `$ARGUMENTS` explicitly requests one
- Note remaining gaps in your summary so nothing gets lost

**Interactive mode** (running via `/what-now` or similar):

Present a concise summary before writing anything:

1. **Incomplete specs** — existing spec files with `> **TODO:**` placeholders. List: file path → placeholder count.
2. **Gaps** — source modules with no corresponding spec file. List: source path → proposed spec path.

Then ask the user what to do. Write nothing until the user approves.

---

### Phase 3 — Fill incomplete specs

Read and follow [backfill-specs/fill-incomplete.md](backfill-specs/fill-incomplete.md).

---

### Phase 4 — Create placeholder specs

Read and follow [backfill-specs/create-placeholders.md](backfill-specs/create-placeholders.md).

---

### Phase 5 — Fill from tests (if approved or in scope)

Read and follow [backfill-specs/fill-from-tests.md](backfill-specs/fill-from-tests.md).

---

### Phase 6 — Fill from source (deep mode)

Only when `$ARGUMENTS` explicitly requests a deep read for a specific area.

Read and follow [backfill-specs/fill-from-source.md](backfill-specs/fill-from-source.md).

---

### Phase 7 — Report

After each run, give the user:

- Files created (paths)
- Files updated (paths + what changed)
- Total `> **TODO:**` placeholders remaining across all specs in `specs/`
- Remaining unmapped modules (if the per-run limit was reached)
- Suggested next steps:
  - Re-run spec-backfill at any time to check remaining gaps
  - Run spec-backfill with `go deep in [area]` to fill a specific module
  - Run intake to file any new ideas that surfaced during this review

---

## Placeholder convention

Unfilled spec sections use `> **TODO:** description`. This format:
- Renders visibly in GitHub (blockquote, bold label)
- Is greppable: `> \*\*TODO\*\*`
- Signals clearly that a section needs attention

Filling a placeholder means replacing the `> **TODO:**` line with real content. Partial fills are fine — leave `> **TODO:**` for the parts that remain unknown.

---

## Preferred tools

- **Glob** — discover source roots, test roots, and existing spec coverage
- **Read** — read source files, test files, and existing specs before proposing changes
- **Grep** — find `> **TODO:**` placeholders across existing specs; find test files by path/name pattern
- **Write** — create new spec files after approval (or in headless mode, within scope limits)
- **Edit** — update existing spec files (fill placeholders, add new sections)

## Inputs

- Source tree structure and files
- Test files (if approved)
- Existing `specs/` directory

## Outputs

- Incomplete specs filled where source provides answers.
- Placeholder spec files created for unmapped modules (up to per-run limit).
- Acceptance sections filled from tests (if approved).
- Contract and Behavior sections filled from source (deep mode only).
- Summary report with placeholder counts and remaining gaps.
