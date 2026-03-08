# Contributing

## Two-layer architecture

This repo has two layers. Keep them clearly separated as you work.

### Layer 1 — Installable scaffold

The small set of files that downstream repos copy in to adopt the spec-template system.

**Source locations (edit these):**

| Source | Destination in dist/ | Notes |
|--------|---------------------|-------|
| `.claude/commands/respec.md` | `.claude/commands/respec.md` | Also used by this repo |
| `.claude/commands/intake.md` | `.claude/commands/intake.md` | Also used by this repo |
| `.claude/commands/knock-out-todos.md` | `.claude/commands/knock-out-todos.md` | Also used by this repo |
| `.claude/commands/spec-backfill.md` | `.claude/commands/spec-backfill.md` | Also used by this repo |
| `scaffold/specs/spec.md` | `specs/spec.md` | Template only — not this repo's live spec |
| `scaffold/specs/spec.todo.md` | `specs/spec.todo.md` | Template only |
| `scaffold/specs/INTAKE.md` | `specs/INTAKE.md` | Template only |
| `scaffold/specs/AGENTS.md` | `specs/AGENTS.md` | Template only |
| `scaffold/specs/README.md` | `specs/README.md` | Template only |
| `scaffold/specs/deps/README.md` | `specs/deps/README.md` | Template only |
| `.github/workflows/spec-check.yml` | `.github/workflows/spec-check.yml` | Also used by this repo |

> **Note:** `.claude/commands/README.md` is intentionally not included in `dist/` — it is a guide for humans exploring this repo, not a file for downstream repos.

### Layer 2 — Autonomous worker

Files in `worker/` define the containerized runner. See [`worker/README.md`](worker/README.md) for operator docs.

---

## dist/ — generated scaffold payload

`dist/` is auto-generated. **Do not edit files in `dist/` directly** — your changes will be overwritten the next time the generator runs.

### When to regenerate

Regenerate `dist/` whenever you change any source file listed in the table above.

### How to regenerate

```bash
bash scripts/generate-dist.sh
```

Review the diff, then commit `dist/` alongside your source changes in the same commit.

The script adds an auto-generated header to every output file pointing back to its source location, so anyone who opens a `dist/` file knows exactly where to make changes.

---

## Manual scaffold installation (without /respec)

To copy the scaffold into a repo manually, without using the `/respec` command:

```bash
# From the spec-template repo root
cp -r dist/.claude      /path/to/your-repo/
cp -r dist/specs        /path/to/your-repo/
cp -r dist/.github      /path/to/your-repo/
```

Then commit the copied files. Run `/respec` afterward to confirm the install is complete and to customise the templates for your project.

**Do not edit the copied files directly.** To update them, make changes to the source files in this repo, regenerate `dist/`, and re-run `/respec` in the target repo to pull in the update.
