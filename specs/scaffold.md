# Installable Scaffold — Current State

## Related

- [`scaffold.todo.md`](scaffold.todo.md) — future scaffold work

## Purpose

Layer 1 of the spec-template system. A small set of files that downstream repos copy in to adopt the spec / intake / TODO workflow. The scaffold gives any repo a `specs/` directory, AI slash commands, agent config, and a PR check — with no runtime dependencies.

## Inputs

- Worker install mode copies scaffold templates from `agents/templates/` into a target repo
- Plugin install via `claude plugin install spec-template@NoahWright87/spec-template`
- AI reads spec files and command files when doing work in that repo

## Outputs

- `specs/` directory in the target repo with current-state and roadmap markdown files
- `.agents/config.yaml` — agent configuration (which agents to run, settings)
- `.claude/commands/` with slash commands (via scaffold) or `plugin/commands/` (via plugin)
- `.github/workflows/spec-check.yml` — PR check that warns when source changes lack spec updates

## Behavior

### Installed files

| Source | Installed path | Purpose |
|--------|---------------|---------|
| `agents/templates/spec.md` | `specs/spec.md` | Current-state spec template |
| `agents/templates/spec.todo.md` | `specs/spec.todo.md` | Roadmap template |
| `agents/templates/INTAKE.md` | `specs/INTAKE.md` | Ideas intake bucket |
| `agents/templates/AGENTS.md` | `specs/AGENTS.md` | Agent instructions for the specs directory |
| `agents/templates/README.md` | `specs/README.md` | Human-readable guide to the specs directory |
| `agents/templates/deps-README.md` | `specs/deps/README.md` | Templates for dep specs and outbound TODOs |
| `agents/templates/config.yaml` | `.agents/config.yaml` | Agent configuration v2 |
| `agents/templates/spec-check.yml` | `.github/workflows/spec-check.yml` | PR check for spec coverage |

### Installation methods

1. **Worker install mode** — the worker detects the scaffold is missing, copies templates from `agents/templates/` directly, opens a bootstrap PR
2. **Plugin** — `claude plugin install spec-template@NoahWright87/spec-template`, then `/what-now`

## User Experience

Scaffold consumers install the plugin and run `/what-now`. The worker can also auto-install into repos that don't have the scaffold yet.

## Acceptance

- All scaffold templates live in `agents/templates/`
- Worker install mode copies templates non-destructively (preserves existing files)
- Plugin commands mirror `.claude/commands/` functionality
