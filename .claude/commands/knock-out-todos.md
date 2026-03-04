# Knock Out TODOs

Identify and implement the easiest open TODO items in this repository. The user may specify how many to tackle — default is 5 if not stated.

Number to tackle: $ARGUMENTS (default 5 if blank)

## Step 0 — Rescue orphaned completed items

Before finding new work, scan all `*.todo.md` files for already-checked items (`- [x]`) that are still sitting in the TODO file instead of having been moved to `spec.md`.

For each one found:
1. Check whether the described work actually exists — look for it in the codebase or in the corresponding `spec.md`.
2. If confirmed done: move the item's description into the appropriate section of `spec.md` and remove it from the todo file.
3. If the work is unclear or you cannot verify it: flag it for the user with a brief note and leave it in place.

## How to find TODOs

Use the Grep tool to search for `^\- \[ \]` across all `specs/**/*.todo.md` files. Read the results and assess relative difficulty. Skip items that are TBD placeholders or that clearly require decisions from the user (e.g. "open questions", "TBD", or items requiring new full components with no spec yet).

## How to choose which items to tackle

Prefer items that:
- Have clear, self-contained requirements
- Affect existing code (modifications or additions to existing modules)
- Can be done with file edits alone — focused, localized changes
- Are independent and do not require user input or clarification to proceed

Avoid items that:
- Say "TBD" or leave requirements unresolved
- Require building entirely new modules or major architectural changes
- Require external dependencies or third-party integrations not yet in place
- Would require asking the user a question before starting

## Workflow

1. Read all unchecked TODOs using Grep. Scan quickly — you do not need to read every spec file in full.
2. For each chosen item that has a `[#N](url)` GitHub issue prefix, fetch the issue details before doing anything else:
   - Run `gh issue view N --json title,body,comments` using the Bash tool.
   - Read the body and any comments for additional context, acceptance criteria, design decisions, or unresolved questions left by other contributors.
   - If the issue has meaningful detail or discussion: incorporate that context into the implementation plan.
   - If the issue body is sparse and has no comments: check with the user before proceeding — ask if there is additional context or requirements to know about before starting.
3. Read the relevant source files for the items you've chosen using the Read tool.
4. Implement the changes using the Edit and Write tools.
5. Mark each completed item done by editing its `.todo.md` file directly — change `- [ ]` to `- [x]` using the Edit tool. Then check whether the item has a `[#N](url)` GitHub issue prefix:
   - If yes and work is confirmed done: run `gh issue close N --comment "Implemented — see spec.md"` using the Bash tool.
   - If `gh` is unavailable or the close fails: note the issue number for the user to close manually.
6. When complete, move the completed item description from `spec.todo.md` into the corresponding `spec.md` to reflect the current state of the codebase.
7. Update `CHANGELOG.md` under `## WIP` with a concise summary of what was done (max ~5 bullets, brief).
8. Run the appropriate build or validation command for the project to confirm changes compile and pass checks.

## Preferred tools and actions

- **Grep** — find TODO items and search source files for relevant code
- **Read** — read source files for the items you've chosen before implementing
- **Edit** and **Write** — make all code changes, mark TODOs as complete, move items to main spec, and update the CHANGELOG
- **Bash** — `gh` calls only (`gh issue view` to read context, `gh issue close` when done); use the file tools above for all file operations

## Style rules

- Follow existing code conventions and patterns already established in the codebase
- Avoid adding new dependencies unless explicitly required by the spec
- Keep changes minimal and focused — do not refactor surrounding code that was not part of the TODO

## Reminders

- `spec.md` = current state | `spec.todo.md` = future plans | INTAKE = entry point
- Completed work belongs in `spec.md`, not in todo files — checked items left behind are migration debt
- Items flow: INTAKE → `spec.todo.md` → `{feature}.todo.md` (if big) → `spec.md` (when done)
