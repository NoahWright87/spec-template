# Philosophy

Good engineering didn't change when AI arrived. DORA metrics, lean systems, clear communication, single sources of truth — all still apply. This file explains why this system is built the way it is.

---

## Engineering practices

### More code = more risk

Every file in this system earns its place. Adoption friction is the enemy of good tooling — the more you ask someone to install, the less likely they are to actually use it. When in doubt, leave it out.

**In practice:**
- Ship the smallest thing that works
- Add files only when there is a clear, felt need
- Prefer prose over structure, and add structure only when it genuinely helps

### Specs are comments at scale

The best comments don't describe what the code does — any competent reader can see that. They explain *why*: why this approach over another, why this constraint exists, what the business rule is. They guide the next developer who couldn't ask the original author.

Specs work the same way, but at a higher level. The code describes *what* it does. The spec describes *why* the system is built the way it is — intent, acceptance criteria, business rules, expectations. The stuff that isn't obvious from reading the code.

This isn't a new idea. It's how good documentation has always worked. AI makes it more important, not different.

**In practice:**
- Write `# WHY: forcing LF here prevents obscure container failures from CRLF in YAML` rather than `# Enforce LF line endings`
- When code is self-explanatory, add no comment — restating it is noise
- Specs describe behavior and intent, not implementation — implementation detail belongs in the code
- If something is already clear from context, don't restate it

### Small and fast

Constant, tiny, incremental change has always been the safest and fastest way to build software. This isn't new — it's why DORA metrics correlate deployment frequency with stability. A 10-line PR can be reviewed, understood, and merged with confidence. A 100-file PR will be skimmed, misunderstood, or left to rot.

Agents aren't different. They're modelled after us. The more a developer has to hold in their head at once, the more likely they forget a constraint, reverse a decision, or miss something obvious. Agents work the same way — the bigger the task, the more likely something slips. Small tasks let the agent focus. Small tasks let the agent finish.

DORA metrics — deployment frequency, lead time, change failure rate, time to restore — describe what good looks like. They apply at least as strongly to agent-driven development as to team-driven development, possibly more so.

**In practice:**
- One logical change per PR — one command, one feature, one fix
- Write PRs that could be explained in a single sentence
- Prefer merging a partial implementation and iterating over holding out for "complete"
- If a PR is growing large, stop and ask whether it should be split before finishing
- Design commands and worker runs to produce one small PR per run, not one large one

### Be your own first reviewer

Before asking anyone else to review your work, review it yourself. Go through the diff as if it were a stranger's PR — look for bugs, unclear changes, missing context. Fix what you find. Then, for any change that might confuse a reviewer, leave a comment explaining it. Not in the code — in the PR. Code comments explain the code; PR comments explain the change.

This is standard advice for engineers, and the same expectation applies here. The goal is to hand over a PR that a reviewer can move through quickly, not one they have to puzzle over.

**Why it matters:** A reviewer who opens a PR full of obvious fixes, unexplained large diffs, and unacknowledged Copilot comments will slow down or check out entirely. A self-reviewed PR with explanatory context is faster to review, faster to merge, and more likely to get useful feedback instead of just surface-level cleanup notes.

**In practice:**
- Review your own diff before anyone else does — treat it like someone else's code
- Batch all self-review fixes into one commit before pushing; each push re-triggers auto-reviewers
- Leave PR comments to explain *why a change looks the way it does*, not to document *what the code does*
- Respond to every review comment — unacknowledged comments signal the feedback was ignored
- When you resolve a comment, say why in your reply before resolving it

### Specs as source of truth

Specs lean toward PRD — they describe what the system should do, why it works the way it does, and what matters to users. They define intent, acceptance criteria, and business rules. The stuff that isn't obvious from reading the code.

Todo files lean toward HLD — they describe how a change will be made: technical decisions, dependencies, implementation approach. Once the work is done, that detail lives in the code. The spec records the outcome, not the path.

**Why it matters:** Without a single authoritative source, decisions scatter across PRs, comments, and memory. The spec makes intent visible, reviewable, and durable across agent runs and team members.

**In practice:**
- Keep specs in sync with the code — if the spec says the system does something, the code better do it
- If something isn't implemented yet, it belongs in the todo file, not the spec
- When code and spec diverge, treat it as a bug in one or the other
- A spec without an implementation is a plan; an implementation without a spec is a guess

---

## Communication and writing practices

### Affirmative language

Instructions in this system are written in the affirmative wherever possible. Say what to do — pair any constraint with its positive form.

**Why it matters:** Words like "don't" and "never" are *load-bearing* — they carry enormous meaning with minimal visible bulk. When an agent (human or AI) skims past a negation, the instruction inverts. "Don't overwrite user files" becomes "overwrite user files." The cost of a missed negation is disproportionate to its size on the page.

**In practice:**
- Write "leave existing files in place" rather than "don't overwrite existing files"
- Write "confirm with the user before writing" rather than "never write without asking"
- When a negative is necessary, pair it with the positive alternative: "prefer X over Y," "do X instead of Y"

### Repetition

Important things should be stated in multiple places. This is intentional, not sloppiness.

LLMs and humans alike benefit from reinforcement. A rule seen once can be skimmed past and forgotten. A rule that appears in every relevant file — restated briefly, in context — tends to stick. Yes, this creates redundancy across files. That redundancy is the point.

*If it's important, it bears repeating.*

### Proximity shapes behavior

Context is subtly powerful. The format, structure, and visual affordances of a document actively shape what an agent does next — often more powerfully than instructions written elsewhere on the page.

The clearest example: this system's TODO files originally used `- [ ]` checkboxes. The instructions said, in multiple places, that completed items should be *removed from the todo file and promoted to `spec.md`*. The instructions were correct. They were repeated. They were even in `## Reminders` sections inside the todo files themselves.

None of that mattered. A checkbox is a checkbox. The closest identifiable pattern — "this is a task, tasks get checked off" — dominated over the textual instructions. `- [ ]` became `- [x]` and the item stayed in the file. The format communicated louder than the words.

The fix was to remove the checkbox entirely. Plain bullets have no "checked" state. There is no affordance for half-done. An item either exists (to do) or it doesn't (done, promoted). The instruction and the format now agree, and the behavior followed.

**In practice:**
- When a format or structure suggests an action, it will be taken — even if instructions say otherwise
- Affordances are instructions. A checkbox says "check me." A delete-only format says "remove me."
- Prefer formats that make the *right* action the *obvious* action, rather than relying on instruction text to override visual instinct
- When instructions and format conflict, the format usually wins — fix the format
