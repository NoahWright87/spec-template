# Refine TODOs

## Purpose

Add technical detail, effort estimates, and priority adjustments to the highest-priority open TODO items — the middle step between intake and implementation. Changes item markers from ❓ (unrefined) to 💎 (refined and ready) or ⏳ (waiting for human input).

## Preconditions

- Repository has `specs/**/*.todo.md` files with open TODO items.

## Steps

Number to refine: `$MAX_REFINE_PER_RUN` environment variable (default: 1). One item refined well is better than three refined superficially.

### 1. Re-check waiting and snoozed items

Read and follow [refine-todos/check-waiting-items.md](refine-todos/check-waiting-items.md). This surfaces items that got answers since the last run and flags stale items.

### 2. Find and prioritize candidates

Use Grep to search for `^- ❓` across all `specs/**/*.todo.md` files. The ❓ marker means "unrefined" — these are your candidates.

**Skip items that are:**
- Already refined: prefixed with `💎`
- Waiting for response: prefixed with `⏳`
- Snoozed: annotated `*(snoozed until YYYY-MM-DD)*` where the date is still in the future
- Reminders or section headings (lines not starting with `- `)

**Prioritize candidates:**
1. Items in "Sooner" sections before "Later" before "Backlog" within each file
2. Higher position in the file (earlier = higher priority)
3. Items with a `[#N](url)` GH issue prefix (proxy for stakeholder interest)

Select the top N items (per `$MAX_REFINE_PER_RUN`).

### 3. Assess and refine each item

Read and follow [refine-todos/assess-and-refine.md](refine-todos/assess-and-refine.md) for each selected item. This loads context, checks clarity, and produces an effort estimate.

For sizing definitions, see [../references/sizing-guide.md](../references/sizing-guide.md).

### 4. Write updates

Read and follow [refine-todos/write-updates.md](refine-todos/write-updates.md) to persist refinement results to spec and TODO files.

### 5. Report

Give the user (or include in the PR description) a brief summary:
- **Refined:** each item, its new effort estimate, and the key technical decision or clarification added
- **Waiting:** items where a GH comment was posted asking for more info (with issue link)
- **Stale:** items that have been waiting longer than 7 days with no reply

## Preferred tools

- **Grep** — find TODO items across spec files
- **Read** — read spec files, GH issue details, source files for context
- **Edit** — update TODO items and spec files
- **Bash** — `gh` CLI calls only (issue view, issue comment); use the file tools above for all file operations

## Inputs

- `specs/**/*.todo.md` — TODO spec files with open items
- GitHub issues (via `gh` CLI) for linked items

## Outputs

- TODO items annotated with effort estimates and technical sub-bullets.
- GH comments posted for items needing clarification.
- Stale items surfaced in report.
