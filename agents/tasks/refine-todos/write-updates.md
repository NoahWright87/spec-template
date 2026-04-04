# Write Updates

## Purpose

Persist refinement results to spec and TODO files after assessment is complete.

## Preconditions

- One or more TODO items have been assessed and refined (effort estimate, technical detail, clarity check).

## Steps

### 1. Update .todo.md files

Change the item's marker from ❓ to 💎 and add an inline effort estimate with technical sub-bullets:

```
- 💎 [#N](url) Description of the item *(effort: M)*
  - Implementation: [brief technical approach — how it will be built]
  - Depends on: [prerequisites or blockers, if any]
```

If no GH issue prefix exists:
```
- 💎 Description of the item *(effort: S)*
  - Implementation: [brief technical approach]
```

Prefix `?` marks before the size to reflect confidence: `*(effort: ?M)*` = probably Medium; `*(effort: ???S)*` = rough guess. On sub-bullets, prefix `?` right after `- ` to flag guesses (e.g., `- ? wrap Express routes` or `- ??? auth service API`). This keeps them greppable with `grep '^\s*- \?'`.

**Additional rules:**
- If priority was adjusted during assessment, move the item to the appropriate section (Sooner / Later / Backlog).
- If a GH comment was posted in headless mode, change the marker to ⏳ instead of 💎, and append `*(waiting for response, asked YYYY-MM-DD)*`:
  ```
  - ⏳ [#N](url) Description *(effort: ?M)* *(waiting for response, asked 2026-03-23)*
  ```
- Do not add speculative or unconfirmed details — only what was agreed or clearly inferable.

### 2. Update related spec files (only when warranted)

If the purpose or approach genuinely improved during refinement:
- Add or update the feature description in `spec.md` or the relevant component spec.
- Do not add unconfirmed design decisions.

## Inputs

- Refinement results from the assessment step
- `.todo.md` files to update
- Related spec files (if refinement improved understanding)

## Outputs

- TODO items annotated with effort estimates and technical sub-bullets.
- Spec files updated where warranted.
