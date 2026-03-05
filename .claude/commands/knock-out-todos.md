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

2. For each chosen item, check its context before doing anything else:

   **If the item is in `specs/deps/`** — "implementing" this item means opening a downstream GitHub issue, not writing product code. Follow the [Dep TODO flow](#dep-todo-flow) below instead of the standard steps.

   **If the item has dep sub-bullets** (indented lines in the form `  - [{repo}#{N}](url)`):
   - Check the status of each: `gh issue view N --repo {owner}/{repo} --json state,title`
   - Any sub-bullet issue still open → item is blocked. Note it and skip — report the blocker to the user.
   - All sub-bullet issues closed → item is unblocked. Proceed with implementation or validation.

   **If the item has a `[#N](url)` GitHub issue prefix** — fetch details:
   - Run `gh issue view N --json title,body,comments` using the Bash tool.
   - Read the body and any comments for additional context, acceptance criteria, or unresolved questions.
   - Meaningful detail or discussion → incorporate it into the implementation plan.
   - Sparse body with no comments → check with the user before proceeding.

3. Read the relevant source files for the items you've chosen using the Read tool.
4. Implement the changes using the Edit and Write tools.
5. Mark each completed item done by editing its `.todo.md` file directly — change `- [ ]` to `- [x]` using the Edit tool. If the item has a `[#N](url)` GitHub issue prefix, note the issue number — collect all of them for the wrap-up step.
6. When complete, move the completed item description from the relevant `.todo.md` file into the corresponding `spec.md` to reflect the current state of the codebase. Drop any dep sub-bullets when promoting — they are implementation history, not current state.
7. Update `CHANGELOG.md` under `## WIP` with a concise summary of what was done (max ~5 bullets, brief). If any completed items were GH-linked, output a ready-to-paste block at the end of your summary:

   ```
   To close linked issues on merge, add to your PR description:
   closes #42
   closes #17
   ```

8. Run the appropriate build or validation command for the project to confirm changes compile and pass checks.

---

## Dep TODO flow

When a chosen item lives in `specs/deps/{repo}.todo.md`, follow this flow instead of the standard implementation steps:

1. Draft a GitHub issue from the TODO description. Write the title and body so the target repo has enough context to act on it independently — don't assume they know this repo's internals.
2. Open the issue: `gh issue create --repo {owner}/{repo} --title "..." --body "..."`
3. Add a sub-bullet to the local TODO item:
   ```
   - [ ] [#local](url) Description
     - [{repo}#{N}]({url}) Downstream issue opened
   ```
4. Cross-link both issues with comments for traceability:
   - On the local issue: `gh issue comment {local-N} --body "Downstream issue opened in {repo}: [{repo}#{N}]({url})"`
   - On the downstream issue: `gh issue comment {dep-N} --repo {owner}/{repo} --body "Opened on behalf of [{this-repo}#{local-N}]({url})"`
5. Leave the TODO as `- [ ]` — it stays open until the downstream issue is closed. Sub-bullet reconciliation (step 2 above) will unblock it on the next run.

## Preferred tools and actions

- **Grep** — find TODO items and search source files for relevant code
- **Read** — read source files for the items you've chosen before implementing
- **Edit** and **Write** — make all code changes, mark TODOs as complete, move items to main spec, and update the CHANGELOG
- **Bash** — `gh` calls only (`gh issue view` to read context and check dep status, `gh issue create` to open downstream dep issues, `gh issue comment` to cross-link); use the file tools above for all file operations

## Style rules

- Follow existing code conventions and patterns already established in the codebase
- Avoid adding new dependencies unless explicitly required by the spec
- Keep changes minimal and focused — do not refactor surrounding code that was not part of the TODO

## Reminders

- `spec.md` = current state | `spec.todo.md` = future plans | INTAKE = entry point
- Completed work belongs in `spec.md`, not in todo files — checked items left behind are migration debt
- Items flow: INTAKE → `spec.todo.md` → `{feature}.todo.md` (if big) → `spec.md` (when done)
- GH-linked items (`[#N]`): include `closes #N` in your PR description — GitHub closes the issue on merge
