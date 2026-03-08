# Installable Scaffold — Current State

## Related

- [`scaffold.todo.md`](scaffold.todo.md) — future scaffold and dist/ work

## Purpose

Layer 1 of the spec-template system. A small set of files that downstream repos copy in to adopt the spec / intake / TODO workflow. The scaffold gives any repo a `specs/` directory, four AI slash commands, and a PR check — with no runtime dependencies.

## Inputs

- Developer copies scaffold files (from `dist/` or via `/respec`) into a target repo
- AI reads spec files and command files when doing work in that repo

## Outputs

- `specs/` directory in the target repo with current-state and roadmap markdown files
- `.claude/commands/` with four slash commands
- `.github/workflows/spec-check.yml` — PR check that warns when source changes lack spec updates

## Behavior

### Installed files

| Source | Installed path | Purpose |
|--------|---------------|---------|
| `.claude/commands/respec.md` | `.claude/commands/respec.md` | Install or update the spec system |
| `.claude/commands/intake.md` | `.claude/commands/intake.md` | Route ideas and GitHub Issues into spec files |
| `.claude/commands/knock-out-todos.md` | `.claude/commands/knock-out-todos.md` | Implement open TODOs and update specs |
| `.claude/commands/spec-backfill.md` | `.claude/commands/spec-backfill.md` | Bootstrap specs from existing code |
| `scaffold/specs/spec.md` | `specs/spec.md` | Current-state spec template |
| `scaffold/specs/spec.todo.md` | `specs/spec.todo.md` | Roadmap template |
| `scaffold/specs/INTAKE.md` | `specs/INTAKE.md` | Ideas intake bucket |
| `scaffold/specs/AGENTS.md` | `specs/AGENTS.md` | Agent instructions for the specs directory |
| `scaffold/specs/README.md` | `specs/README.md` | Human-readable guide to the specs directory |
| `scaffold/specs/deps/README.md` | `specs/deps/README.md` | Templates for dep specs and outbound TODOs |
| `.github/workflows/spec-check.yml` | `.github/workflows/spec-check.yml` | PR check for spec coverage |

### dist/ generation

`scripts/generate-dist.sh` copies scaffold source files into `dist/` with auto-generated do-not-edit headers. The `dist/` directory is the committed output — downstream users and the worker container consume it directly without running the generator.

Run after any source change, then commit the result.

## User Experience

Scaffold consumers run `/respec` from their AI assistant, or copy files from `dist/` manually. The `/respec` command handles fresh install, re-install, and updates.

## Acceptance

- `dist/` contains all scaffold files with auto-generated headers
- Re-running `generate-dist.sh` produces identical output for unchanged sources
