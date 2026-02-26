# Intake

Process the ideas in `specs/INTAKE.md` and file them into the appropriate TODO spec files.

## Step 1 — Ensure INTAKE.md exists

Check whether `specs/INTAKE.md` exists.

If it **does not exist**:
1. Create the `specs/` directory if needed.
2. Create `specs/INTAKE.md` with this exact content:

```markdown
# Ideas intake

Too lazy to search for the right spec to update?  Throw your idea here and let the LLMs put it in the right place(s) later!

## AGENTS Instructions

When asked to, take any items listed below and organize put them into the appropriate TODO spec file.  Ideas may be vague, rambling, or half-baked.  If necessary, ask clarifying questions to determine what the user's intent was.  If a single item refers to multiple components or is a particularly large/complex idea, it can be broken into multiple separate TODOs in the relevant `*.todo.spec`.

Use your best judgement to determine the priority of each item.  If a requested item already exists in the TODO spec, that implies a higher priority.  If a high priority item is lacking details, always ask the user for more information.  If priority is not very clear, ask the user.

When you have emptied the submissions section below, leave behind a single bullet:

- *Add your ideas here*.

## Submissions

- *Add your ideas here*.
```

Then tell the user the file has been created and stop — there is nothing to process yet.

## Step 2 — Read the Submissions

Read `specs/INTAKE.md`. Extract every bullet under `## Submissions`, ignoring the placeholder `*Add your ideas here*` bullet. If the Submissions section is empty (only the placeholder), tell the user there is nothing to process and stop.

## Step 3 — Survey existing TODO spec files

Use Grep to find all `*.todo.md` files under `specs/`. Read their headings so you understand what components/areas each file covers. Do not read every line — just enough to map file → component/area.

## Step 4 — Process each item

For each submission item:

1. **Determine the target spec file.** Match the item to the most relevant `*.todo.md` based on the component or area it describes. If the item spans multiple components, split it into one entry per relevant spec file.

2. **Check for duplicates.** Grep the target spec file for similar wording. If a near-identical item exists:
   - Tell the user: "This item already exists in `<file>`: `<existing text>`."
   - Ask if they want to add details or move it higher in priority before continuing.

3. **Clarify vague items.** If the item's intent is ambiguous — you cannot confidently determine what component it targets, what behavior is wanted, or which spec file it belongs in — ask the user a specific clarifying question before filing it. Always ask if intent is ambiguous!

4. **Determine placement.** Append new items to the end of the relevant spec file's unchecked TODO list.  If the item seems high-priority based on context, add it higher in the file. Use your judgment.

5. **Format the TODO entry.** Write it as a `- [ ]` checkbox with a concise, actionable description. Expand vague language into clear implementation intent. If the original submission contains multiple sub-bullets, preserve them as indented sub-bullets under the main checkbox.

6. **Create the spec file if missing.** If no suitable `*.todo.md` exists for the item, create one at an appropriate path under `specs/` (mirroring the code hierarchy if it already exists). Use this minimal template:

```markdown
# <Component/Area/Page/Class Name> — TODOs

- [ ] <first item>
```

## Step 5 — Clear INTAKE.md

After all items are filed, update `specs/INTAKE.md` so the Submissions section contains only the placeholder:

```markdown
## Submissions

- *Add your ideas here*.
```

## Step 6 — Report

Give the user a brief summary:
- Which items were filed and where.
- Any items that were split across multiple spec files.
- Any duplicates found.
- Any spec files that were newly created.

## Preferred tools

- **Read** — read INTAKE.md and existing spec files
- **Grep** — find existing TODO spec files and check for duplicate entries
- **Edit** — update spec files and clear INTAKE.md
- **Write** — create new spec files or INTAKE.md if missing

Do not use Bash for any file operations — use Read, Write, Grep, and Edit instead.
