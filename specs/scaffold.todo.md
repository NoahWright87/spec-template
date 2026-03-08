# Installable Scaffold — TODOs

## Summary
Work to build and maintain the installable scaffold payload (Layer 1): the small, friendly set of files that downstream repos copy in to adopt the spec / intake / TODO system. Includes the `dist/` generation pipeline that keeps the published output consistent.

## Reminders

- Move completed items to `spec.md` — this file is for future plans, not current state
- Items flow: INTAKE → `spec.todo.md` → `scaffold.todo.md` (scaffold-specific) → `spec.md` (when done)
- If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
