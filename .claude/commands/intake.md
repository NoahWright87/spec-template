# Intake

Process ideas from `specs/INTAKE.md` — and from open GitHub Issues — and file them into the appropriate TODO spec files.

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

## Step 2 — Pull from GitHub Issues

1. Run `gh auth status` using the Bash tool.
   - If `gh` is not installed or the user is not authenticated: skip the rest of this step, make a note for the report, and continue to Step 3.
2. Run: `gh issue list --state open --json number,title,url,labels --limit 100`
3. Filter out any issues that already carry one of these labels: `intake:filed`, `intake:rejected`, `intake:ignore`.
4. For each remaining issue, append a bullet to the `## Submissions` section of `specs/INTAKE.md`:
   ```
   [#N](url) Issue title
   ```
5. If no unprocessed issues are found, note it and continue.

## Step 3 — Read the Submissions

Read `specs/INTAKE.md`. Extract every bullet under `## Submissions`, ignoring the placeholder `*Add your ideas here*` bullet. If the Submissions section is empty (only the placeholder), tell the user there is nothing to process and stop.

## Step 4 — Survey existing TODO spec files

Use Grep to find all `*.todo.md` files under `specs/`. Read their headings so you understand what components/areas each file covers. Do not read every line — just enough to map file → component/area.

## Step 5 — Process each item

For each submission item:

1. **Determine the target spec file.** Match the item to the most relevant `*.todo.md` based on the component or area it describes. If the item spans multiple components, split it into one entry per relevant spec file.

2. **Check for duplicates.** Grep the target spec file for similar wording. If a near-identical item exists:
   - Tell the user: "This item already exists in `<file>`: `<existing text>`."
   - Ask if they want to add details or move it higher in priority before continuing.

3. **Clarify vague items.** If the item's intent is ambiguous — you cannot confidently determine what component it targets, what behavior is wanted, or which spec file it belongs in — ask the user a specific clarifying question before filing it. Always ask if intent is ambiguous!

4. **Determine placement.** Append new items to the end of the relevant spec file's unchecked TODO list. If the item seems high-priority based on context, add it higher in the file. Use your judgment.

5. **Format the TODO entry.** Write it as a `- [ ]` checkbox. For GH-sourced items (those with a `[#N](url)` prefix), preserve the link as a prefix to the description:
   ```
   - [ ] [#42](url) Description of what needs to happen
   ```
   For manual items, write a concise, actionable description. Expand vague language into clear implementation intent. If the original submission contains multiple sub-bullets, preserve them as indented sub-bullets under the main checkbox.

6. **Create the spec file if missing.** If no suitable `*.todo.md` exists for the item, create one at an appropriate path under `specs/` (mirroring the code hierarchy if it already exists). Use this minimal template:

```markdown
# <Component/Area/Page/Class Name> — TODOs

- [ ] <first item>
```

7. **Apply a GitHub label** if the item has a `[#N](url)` prefix:
   - **Filed successfully:** `gh issue edit N --add-label "intake:filed"`
   - **User rejects the idea:** `gh issue edit N --add-label "intake:rejected"` — skip filing, do not write it to any spec file
   - **User says leave it alone (by-human-for-human):** `gh issue edit N --add-label "intake:ignore"` — skip filing

## Step 6 — Clear INTAKE.md

After all items are filed, update `specs/INTAKE.md` so the Submissions section contains only the placeholder:

```markdown
## Submissions

- *Add your ideas here*.
```

## Step 7 — Report

Give the user a brief summary:
- Which items were filed and where.
- Any items that were split across multiple spec files.
- Any duplicates found.
- Any spec files that were newly created.
- **GitHub:** which issues were labeled and how. If `gh` was unavailable, note it here.

## Preferred tools

- **Read** — read INTAKE.md and existing spec files
- **Grep** — find existing TODO spec files and check for duplicate entries
- **Edit** — update spec files and clear INTAKE.md
- **Write** — create new spec files or INTAKE.md if missing
- **Bash** — `gh` CLI calls only (auth check, issue list, issue edit); use the file tools above for all file operations
