# Specs

This directory contains **spec-driven source-of-truth documents** for this repository.
Specs mirror the source tree and describe *what the system is and how it behaves*, not how it is implemented.

## Core rules
- `.spec.md` is the **root spec** for each directory.
- Every `.spec.md` must have a neighboring `.spec.todo.md`.
- Additional specs are named `{feature}.spec.md` and use the same template.
- Specs must include a **Related** section that links only to other specs (not TODOs).

## File types

### `.spec.md`
Primary specification for a page, feature, system, or module.
Describes the **current, shippable contract**.

### `{feature}.spec.md`
Focused spec for a sub-feature or component.
Same structure as `.spec.md`, just smaller in scope.

### `.spec.todo.md`
Roadmap for future work related to its neighboring spec.
Prioritized from top to bottom.

## Writing guidelines
- Prefer **behavior over implementation**
- Be explicit where ambiguity could cause bugs
- Keep specs short, readable, and skimmable
- If it's not current behavior, it belongs in `.spec.todo.md`
