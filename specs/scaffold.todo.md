# Installable Scaffold — TODOs

## Summary
Work to build and maintain the installable scaffold payload (Layer 1): the small, friendly set of files that downstream repos copy in to adopt the spec / intake / TODO system. Includes the `dist/` generation pipeline that keeps the published output consistent.

## Sooner

### Repo restructuring
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Restructure repo to clearly separate Layer 1 (installable scaffold) and Layer 2 (worker runtime) in directory layout and docs

### Scaffold payload definition
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Identify and finalize which files belong in the installable scaffold payload (spec templates, INTAKE.md, commands, AGENTS.md, etc.)

### dist/ generation pipeline
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Create `dist/` generation script that copies scaffold source files into `dist/` with auto-generated headers on each file (do-not-edit warning + source location)
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Commit generated `dist/` output to repo so downstream users and tools can consume it without running the generator

## Later

### Scaffold documentation
- [ ] [#7](https://github.com/NoahWright87/spec-template/issues/7) Document how downstream repos should consume the `dist/` payload without /respec (manual copy path, what not to edit, where source of truth lives)
- [ ] [#7](https://github.com/NoahWright87/spec-template/issues/7) Document how to regenerate `dist/` after modifying scaffold source files (beyond the inline script comment)

## Reminders

- Move completed items to `spec.md` — this file is for future plans, not current state
- Items flow: INTAKE → `spec.todo.md` → `scaffold.todo.md` (scaffold-specific) → `spec.md` (when done)
- If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
