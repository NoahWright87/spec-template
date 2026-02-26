# Knock Out TODOs

Identify and implement the easiest open TODO items in this repository. The user may specify how many to tackle — default is 5 if not stated.

Number to tackle: $ARGUMENTS (default 5 if blank)

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
2. Read the relevant source files for the items you've chosen using the Read tool.
3. Implement the changes using the Edit and Write tools.
4. Mark each completed item done by editing its `.todo.md` file directly — change `- [ ]` to `- [x]` using the Edit tool.
5. When complete, move the completed item description from `spec.todo.md` into the corresponding `spec.md` to reflect the current state of the codebase.
6. Update `CHANGELOG.md` under `## WIP` with a concise summary of what was done (max ~5 bullets, brief).
7. Run the appropriate build or validation command for the project to confirm changes compile and pass checks.

## Preferred tools and actions

- **Grep** — find TODO items and search source files for relevant code
- **Read** — read source files for the items you've chosen before implementing
- **Edit** and **Write** — make all code changes, mark TODOs as complete, move items to main spec, and update the CHANGELOG

Avoid using shell commands to check off boxes, list files, or search for patterns — use Grep and Read instead.

## Style rules

- Follow existing code conventions and patterns already established in the codebase
- Avoid adding new dependencies unless explicitly required by the spec
- Keep changes minimal and focused — do not refactor surrounding code that was not part of the TODO
