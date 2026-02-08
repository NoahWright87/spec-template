# AGENTS

Keep this repo aligned with spec-driven development.

## Rules
- Specs live in `.specs/` and mirror the source tree.
- Every directory in `.specs/` must include `.spec.md` and `.spec.todo.md`.
- Additional specs are named `{feature}.spec.md` and use the same template.
- Specs describe current behavior; TODO specs are for future work.
- Specs must include a **Related** section with links to other specs only (no TODO links).

## Split rule
- If a spec grows beyond **300 lines**, it should be split.
- If a spec reaches **500 lines**, it must be split.

## Workflow
- Start new work in `.spec.todo.md`.
- Once refined and committed, promote it into `.spec.md`.
- Keep code and specs in sync.
