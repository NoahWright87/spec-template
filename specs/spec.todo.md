# Spec Template — Roadmap

## Summary
This repo provides two products: (1) an installable spec / intake / TODO scaffold for other repos, and (2) a reusable autonomous worker runtime that runs Claude CLI in a container. See `scaffold.todo.md` and `worker.todo.md` for the large feature work. This file tracks improvements to the template system itself (commands, UX, meta-tooling).

## Sooner

## Later

### /refine command
- [#3](https://github.com/NoahWright87/spec-template/issues/3) Add `/refine` command: middle step between `/intake` and `/knock-out-todos` that clarifies vague TODOs by asking the user questions interactively (or posting to GH issue comments in headless mode); opens a PR with updated spec/todo docs, added technical detail, effort estimates (XS/S/M/L/XL/Unknown), and any priority adjustments
  - Focus on higher-priority items first (higher in the TODO doc, more linked issues, etc.)
  - Ask user (or GH comments) when intent or product decisions are unclear — do not assume

### Reduce cognitive load for humans
- [#4](https://github.com/NoahWright87/spec-template/issues/4) Separate human-facing docs from AI-facing docs; make README the clear entrypoint for humans with the onboarding command surfaced first
- [#4](https://github.com/NoahWright87/spec-template/issues/4) Audit commands and consider combining or routing via a meta `/help` command so humans have less to remember

### Shell scripts for deterministic tasks
- [#2](https://github.com/NoahWright87/spec-template/issues/2) Create shell script(s) for deterministic repo setup: copying scaffold files, creating empty spec/todo docs from templates; reduces token usage and speeds onboarding vs doing it all with Claude CLI

## Backlog

- [#5](https://github.com/NoahWright87/spec-template/issues/5) Auto-create GH issues for INTAKE items that aren't linked to one yet (optional, opt-in via config — not everyone will want this)
- [#6](https://github.com/NoahWright87/spec-template/issues/6) GitHub Action that publishes both `/docs` and `/specs` to a single GH Pages site

## Ideas (Uncommitted)

- When `/respec` runs in Update mode, compare the `dist/specs/spec.todo.md` template against the local TODO files. If the format differs (e.g. checkboxes vs plain bullets), offer to migrate existing TODO items to the current format. Apply only with user approval.

## Reminders

- Move completed items to `spec.md` — this file is for future plans, not current state
- Large or complex ideas belong in their own `{feature}.todo.md`, not buried here
- Items flow: INTAKE → `spec.todo.md` → `{feature}.todo.md` (if big) → `spec.md` (when done)
- If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
