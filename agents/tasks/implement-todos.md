# Implement TODOs

## Purpose

Identify and implement the easiest open TODO item in the repository. Default is 1 item per run — small, focused PRs are easier to review and ship faster.

## Preconditions

- Repository has `specs/**/*.todo.md` files with open TODO items.

## Steps

Number to tackle: `$MAX_TODOS_PER_RUN` environment variable (default: 1). Keep PRs small and focused — one item per PR is easier to review and ships faster.

### How to find TODOs

Use the Grep tool to search for `^- 💎` across all `specs/**/*.todo.md` files. The 💎 marker means "refined and ready to implement." Skip ❓ (unrefined) and ⏳ (waiting for response) items — they need refinement or human input first.

### How to choose which items to tackle

✅ **Pick items that:**
- ✅ Are marked 💎 (refined) — these have been through refinement and are ready
- ✅ Have clear, self-contained requirements
- ✅ Affect existing code (modifications or additions to existing modules)
- ✅ Can be done with file edits alone — focused, localized changes
- ✅ Are independent — they do not require user input or clarification to proceed
- ✅ Have a size estimate of S or smaller

❌ **DO NOT pick items that:**
- ❌ DO NOT pick ❓ items — these are unrefined and need the refine agent first
- ❌ DO NOT pick ⏳ items — these are waiting for human input
- ❌ DO NOT pick items that require building entirely new modules or major architectural changes
- ❌ DO NOT pick items that require external dependencies or third-party integrations not yet in place
- ❌ DO NOT pick items that would require asking the user a question before starting

For sizing definitions, see [../references/sizing-guide.md](../references/sizing-guide.md).

### Workflow

1. Read all open TODO items using Grep. Scan quickly — you do not need to read every spec file in full.

2. For each chosen item, check its context before doing anything else:

   **If the item is in `specs/deps/`** — this is a dependency item, not product code. Read and follow [implement-todos/dep-todo-flow.md](implement-todos/dep-todo-flow.md) instead of continuing with the steps below.

   **If the item has dep sub-bullets** (indented lines in the form `  - [{repo}#{N}](url)`):
   - Check the status of each: `gh issue view N --repo {owner}/{repo} --json state,stateReason,title`
   - Any sub-bullet issue still open → item is blocked. Note it and skip — report the blocker to the user.
   - All sub-bullet issues closed: check `stateReason` for each:
     - `stateReason == "completed"` → item is unblocked. Remove the sub-bullets and proceed with implementation or validation.
     - `stateReason == "not_planned"` → downstream work was intentionally abandoned. Post a comment on the upstream issue explaining the situation; leave the upstream TODO open (do not promote to spec) so a human can decide what to do next.
     - `stateReason == "duplicate"` → treat as still blocked (work exists elsewhere but not yet verified complete). Keep the sub-bullet in place and skip on next run.
     - `stateReason == null` or unknown → treat as still blocked. Keep the sub-bullet in place and skip.

   **If the item has a `[#N](url)` GitHub issue prefix** — fetch details:
   - Run `gh issue view N --json title,body,comments` using the Bash tool.
   - Read the body and any comments for additional context, acceptance criteria, or unresolved questions.
   - Meaningful detail or discussion → incorporate it into the implementation plan.
   - Sparse body with no comments → post a 🤖 clarification comment on the issue (do not respond to any existing 🤖 comment) and skip to the next item.

3. Read the relevant source files for the items you've chosen using the Read tool.
4. Implement the changes using the Edit and Write tools.
5. For each completed item: (a) remove it from its `.todo.md` file using the Edit tool; (b) if the file is a per-issue file (filename matches `*.issue-*.todo.md`) and only the header line(s) remain after removal, delete the file using `git rm` via the Bash tool so the deletion is staged; (c) add its description to the appropriate section of `spec.md` to reflect current state. Drop any dep sub-bullets when promoting — they are implementation history, not current state. If the item has a `[#N](url)` GitHub issue prefix, note the issue number — collect all of them for the wrap-up step.
6. Update `CHANGELOG.md` with the next semver version number (e.g., `## vX.Y.Z`) and a concise summary of what was done (max ~5 bullets, brief). Always write the actual next semver heading directly — add a new section at the top if one does not already exist for this release. If any completed items were GH-linked, output a ready-to-paste block at the end of your summary:

   ```
   To close linked issues on merge, add to your PR description:
   closes #42
   closes #17
   ```

   **When to use `closes #N` vs `Refs #N`:**
   - `closes #N` — only when this PR **directly implements** the work tracked by the issue (the issue is truly done when this merges).
   - `Refs #N` — when the PR is related to the issue but does not fully implement it (e.g., intake-only PRs, or when downstream dependency work is still pending).
   - For dependency-pending cases, leave the issue open and do not use any auto-closing keyword (`closes`/`fixes`/`resolves`); if you reference it, use `Refs #N` so the issue stays open.

7. Run the appropriate build or validation command for the project to confirm changes compile and pass checks.

## Preferred tools and actions

- **Grep** — find TODO items and search source files for relevant code
- **Read** — read source files for the items you've chosen before implementing
- **Edit** and **Write** — make all code changes, mark TODOs as complete, move items to main spec, and update the CHANGELOG
- **Bash** — `gh` calls only (`gh issue view` to read context and check dep status, `gh issue create` to open downstream dep issues, `gh issue comment` to cross-link); use the file tools above for all file operations

## Style rules

- Follow existing code conventions and patterns already established in the codebase
- Avoid adding new dependencies unless explicitly required by the spec
- Keep changes minimal and focused — do not refactor surrounding code that was not part of the TODO

## Inputs

- `specs/**/*.todo.md` — TODO spec files with open items
- Source files relevant to chosen items

## Outputs

- TODO items implemented in source code.
- Completed items removed from `.todo.md` and promoted to `spec.md`.
- `CHANGELOG.md` updated with version number.
- Build/validation passes.
