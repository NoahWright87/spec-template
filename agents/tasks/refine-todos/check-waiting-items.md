# Check Waiting and Snoozed Items

## Purpose

Re-check items that were previously blocked on human input. Surface items that got answers and flag stale ones.

## Preconditions

- `specs/**/*.todo.md` files exist.

## Steps

Scan all `.todo.md` files for items with date annotations.

### Waiting items

Scan for items prefixed with ⏳ (or annotated `*(waiting for response, asked YYYY-MM-DD)*`):

1. If the item has a `[#N](url)` prefix, run `gh issue view N --json comments` and check for comments posted after the asked date.
2. New comments found → change the marker from ⏳ to ❓, strip the waiting annotation, and add the item to the candidate pool (treat as high priority — the user has responded).
3. No new comments and older than **7 days** → add to the stale list for the final report.
4. No new comments and within 7 days → skip silently.

### Snoozed items

For each item annotated `*(snoozed until YYYY-MM-DD)*`:

- Snooze date is in the future → skip entirely.
- Snooze date has passed → strip the annotation and re-add to the candidate pool.

### Defer requests

During the run, if the user says to defer a stale item ("we'll get to it in May", "ignore this for now"):
- Update its annotation to `*(snoozed until YYYY-MM-DD)*` based on what they said.
- Move on without posting to GH.

## Inputs

- `specs/**/*.todo.md` files with date annotations

## Outputs

- Un-waiting items added back to candidate pool.
- Stale items flagged for the report.
- Snoozed items un-snoozed if their date has passed.
