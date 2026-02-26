# spec-template
Template repo for spec-driven development.

## What this repo is for
This repo is a starting point for projects that keep **specs as the source of truth**.
Specs describe current behavior; code implements the specs.

## Spec structure
- Specs live in `specs/` and mirror the source tree.
- Every directory in `specs/` must include:
	- `spec.md` (current, shippable spec)
	- `spec.todo.md` (roadmap for that spec)
- Additional specs in a directory are named `{feature}.spec.md` and use the same template.
- Specs must include a **Related** section that links only to other specs (no TODO links).

## Split rule
- If a spec grows beyond **300 lines**, it should be split.
- If a spec reaches **500 lines**, it must be split.

See [AGENTS.md](AGENTS.md) and [specs/README.md](specs/README.md) for details.
