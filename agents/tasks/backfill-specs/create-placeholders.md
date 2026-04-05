# Create Placeholder Specs

## Purpose

Create spec files for source modules that don't have one yet. Uses a standard template with `> **TODO:**` markers for sections that need attention.

## Preconditions

- Unmapped source modules identified in Phase 1 of the parent task.
- In headless mode: limit to **3 new files per run** (keep PRs small and reviewable).

## Steps

For each unmapped source module (up to the per-run limit):

1. **For spec files** — use the template at [../../templates/spec-placeholder.md](../../templates/spec-placeholder.md). If the template file is not available, use the standard spec format with `> **TODO:**` markers for each section.

2. **For TODO files** — if the module doesn't have a `.todo.md` yet, create one using the template at [../../templates/todo-placeholder.md](../../templates/todo-placeholder.md). This gives the module a place to collect future work items.

3. Fill any section that can be reasonably inferred from the module's name, directory, or obvious purpose. Mark every section that cannot be determined with `> **TODO:**`.

4. **File placement:**
   - Small or simple module (few files, single clear purpose) → `specs/{module}.spec.md` + `specs/{module}.todo.md`
   - Larger or multi-concern module → `specs/{module}/spec.md` + `specs/{module}/spec.todo.md`, with optional `specs/{module}/{submodule}.spec.md` for distinct sub-concerns

5. Fill the Purpose section with whatever the module name and location suggest, even if brief. A partial answer is better than a placeholder that will sit forever.

## Inputs

- List of unmapped source modules
- Spec template at `agents/templates/spec-placeholder.md`
- TODO template at `agents/templates/todo-placeholder.md`

## Outputs

- New spec files created with placeholders.
- Files created count (for the report).
