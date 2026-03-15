# What Now?

Not sure which command to run? Use this as your starting point.

---

## Step 0 — Check assessment preference

Read `specs/.meta.json`. Look for the key `"what_now_assess"`.

**If the key is missing or the file doesn't exist:**
Use AskUserQuestion to ask the user:

> Should I check the repo's status before showing options?
> - **Always assess** — check for open PRs, waiting items, unprocessed intake, etc. each time, then recommend the most relevant option
> - **Only when I ask** — show the menu immediately; I'll choose "Assess status" when I want it

Save their answer to `specs/.meta.json`:
- "Always assess" → `"what_now_assess": "auto"`
- "Only when I ask" → `"what_now_assess": "on_demand"`

Create the file with just that key if it doesn't exist. Then proceed based on what they chose.

**If the key is `"auto"`:** Run Step 1, then Step 2.

**If the key is `"on_demand"`:** Skip to Step 2. Add "🔍 Assess repo status" as the last option in the menu; if the user picks it, run Step 1 and re-present the menu with recommendations.

---

## Step 1 — Assess repo status

Run these checks quickly. Use `gh` CLI for GH queries and Grep for local file scans. Do not read entire files — scan for the signals listed.

| Check | Command / method | Finding |
|-------|-----------------|---------|
| Open PRs (yours) with unresolved comments | `gh pr list --author @me --state open --json number,title` then `gh pr view N --json reviewThreads` for each | ⭐ Highly recommended: PR Review |
| Waiting items older than 7 days | Grep `\*\(waiting for response, asked` in `specs/**/*.todo.md`; parse the date and compare to today | ⭐ Highly recommended: Refine or Intake |
| INTAKE.md has unprocessed content | Read `specs/INTAKE.md`; check whether the Submissions section has entries | Recommended: File ideas |
| Open GH Issues not yet filed in any TODO | `gh issue list --state open --json number`; Grep each issue number (`\[#N\]`) in `specs/**/*.todo.md` | Recommended: File ideas |
| TODO items with no effort estimate | Grep `^- ` in `specs/**/*.todo.md`; filter out lines containing `*(effort:` | Recommended: Add detail |
| TODO items refined and ready to implement | Grep `\*(effort: (XS|S)` in `specs/**/*.todo.md` | Recommended: Implement |

Build a findings list: which options are **⭐ Highly recommended**, which are **Recommended**, and which have nothing relevant. Keep the summary short — one line per finding. This will be shown above the menu.

---

## Step 2 — Present the menu

Use the AskUserQuestion tool. If Step 1 ran, prefix the question with the findings summary and order options by priority (most pressing first). Label each option using the findings:

- **⭐ Highly recommended** — something pressing was found
- **Recommended** — relevant items exist
- *(no label)* — always valid, nothing specific found
- Move irrelevant options toward the bottom with a softened description

If Step 1 did not run (on_demand mode), present the static menu in default order.

### Options and routing

| Option label | Description | File to read |
|-------------|-------------|--------------|
| Review an open PR | Self-review your diff, leave explanatory comments, respond to Copilot and reviewer comments | `.claude/commands/lib/pr-review.md` |
| File ideas and GitHub Issues | Sort new ideas, feature requests, and open GH Issues into the right TODO spec files | `.claude/commands/lib/intake.md` |
| Add detail to TODO items | Clarify vague TODOs, add effort estimates (XS–XL), and open a PR with proposed spec updates | `.claude/commands/lib/refine.md` |
| Implement TODO items | Pick the easiest open TODO items and implement them | `.claude/commands/lib/knock-out-todos.md` |
| Backfill specs from existing code | Generate spec files from an existing codebase; mark gaps with `> **TODO:**` for later | `.claude/commands/lib/spec-backfill.md` |
| Install or update the spec system | Set up this template in a new repo or pull in upstream updates | `.claude/commands/lib/respec.md` |
| 🔍 Assess repo status *(on_demand mode only)* | Run a status check and re-present this menu with recommendations | *(run Step 1, then Step 2 again)* |

Once the user selects an option, read the corresponding command file and follow it exactly. Do not load any command file until the user has made their choice — only read the one they pick.

Do not summarize or paraphrase the command file — it is the instruction set.

---

## Reminders

- Only read one command file per session — the one the user chose
- In on_demand mode, "🔍 Assess repo status" triggers Step 1 then re-runs Step 2 with labels — it is not a dead end
- Save the assessment preference on first use; do not ask again on subsequent runs
- The assessment should be fast — if GH queries are slow, parallelize where possible
