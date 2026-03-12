# Philosophy

Old software practices didn't stop being true when AI arrived. DORA metrics, lean systems, clear communication, and single sources of truth all apply — sometimes in familiar ways, sometimes in ways that feel strange. This file explains why this system is designed the way it is, through that lens.

---

## Engineering practices

### Minimal as hell

Every file in this system earns its place. Adoption friction is the enemy of good tooling — the more you ask someone to install, the less likely they are to actually use it. When in doubt, leave it out.

**In practice:**
- Ship the smallest thing that works
- Add files only when there is a clear, felt need
- Prefer prose over structure, and add structure only when it genuinely helps

### Context is prime real estate

Context is finite and valuable — for AI and humans alike. Everything loaded into context should earn its place by carrying signal. Anything that merely restates what's already clear wastes the budget.

This applies everywhere: comments that describe *what* the code does (the code already does that), specs that describe implementation rather than behavior, inline docs that repeat what the surrounding context already makes obvious. When context is full of noise, the signal gets lost.

**Why it matters:** An agent reading a large, noisy context will miss constraints, reverse decisions, and hallucinate. A human reviewer in the same position will skim and misunderstand. The cost is the same — just measured in different units.

**In practice:**
- Write `# WHY: forcing LF here prevents obscure container failures from CRLF in YAML` rather than `# Enforce LF line endings`
- When code is self-explanatory, add no comment — restating it is noise
- Specs describe behavior, not implementation — implementation detail belongs in the code
- If something is already clear from context, don't restate it

### Small and fast

Ship small changes frequently. Keep PRs reviewable by a human in a few minutes. This is not a new idea — it predates AI — but it matters *more* when agents are in the loop, not less.

**Why it matters:** A large PR is a large context window. The more code, spec, and history an agent must hold at once, the more likely something slips — a constraint forgotten, a decision reversed three files later, a hallucination that would have been caught earlier. Small changes let the agent focus. Small changes let the agent finish. And a small PR is a PR a human can actually read: a reviewer who can scan a diff in five minutes and say "yes, this is what I wanted" will merge with confidence. A reviewer who opens a 100-file PR from an AI will hesitate.

DORA metrics — deployment frequency, lead time, change failure rate, time to restore — describe what good looks like. They apply at least as strongly to agent-driven development as to team-driven development, possibly more so.

**In practice:**
- One logical change per PR — one command, one feature, one fix
- Write PRs that could be explained in a single sentence
- Prefer merging a partial implementation and iterating over holding out for "complete"
- If a PR is growing large, stop and ask whether it should be split before finishing
- Design commands and worker runs to produce one small PR per run, not one large one

### Specs as source of truth

Code implements specs. Specs describe what the system is and how it behaves. When they diverge, the spec is the authority — either the code needs fixing, or the spec needs updating.

**Why it matters:** Without a single authoritative source, decisions scatter across PRs, comments, and memory. The spec makes intent visible, reviewable, and durable across agent runs and team members.

**In practice:**
- When implementing, update the spec first — implementation follows the spec, not the reverse
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
