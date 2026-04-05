# Fill Incomplete Specs

## Purpose

Fill `> **TODO:**` placeholders in existing spec files where the source code provides clear answers. This is the highest-value backfill work — improving existing files is cheaper to review than creating new ones.

## Preconditions

- Existing spec files with `> **TODO:**` placeholders (identified in Phase 1 of the parent task).

## Steps

For each existing spec with `> **TODO:**` placeholders (highest priority first — most placeholders = most incomplete):

1. Read the spec file and identify all `> **TODO:**` sections.
2. Read the source code the spec documents.
3. Fill placeholders where the source code provides clear answers:
   - **Purpose** — what does the module do? Who depends on it?
   - **Inputs/Outputs** — what does it accept and produce?
   - **Behavior** — what's the happy path? Error states?
4. Leave `> **TODO:**` for anything that genuinely can't be determined from code alone.
5. A partial fill is better than no fill — even adding one sentence to a section is progress.

## Inputs

- Existing spec files with `> **TODO:**` placeholders
- Source files the specs document

## Outputs

- Spec files updated with filled sections.
- Remaining `> **TODO:**` count per file.
