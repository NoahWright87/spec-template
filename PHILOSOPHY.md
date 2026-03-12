# Philosophy

These are the principles behind this template system. They inform how commands, specs, and documentation are written, and how the system is designed to evolve.

## Affirmative language

Instructions in this system are written in the affirmative wherever possible. Say what to do — pair any constraint with its positive form.

**Why it matters:** Words like "don't" and "never" are *load-bearing* — they carry enormous meaning with minimal visible bulk. When an agent (human or AI) skims past a negation, the instruction inverts. "Don't overwrite user files" becomes "overwrite user files." The cost of a missed negation is disproportionate to its size on the page.

**In practice:**
- Write "leave existing files in place" rather than "don't overwrite existing files"
- Write "confirm with the user before writing" rather than "never write without asking"
- When a negative is necessary, pair it with the positive alternative: "prefer X over Y," "do X instead of Y"

## Minimal as hell

Every file in this system earns its place. Adoption friction is the enemy of good tooling — the more you ask someone to install, the less likely they are to actually use it. When in doubt, leave it out.

In practice:
- Ship the smallest thing that works
- Add files only when there is a clear, felt need
- Prefer prose over structure, and add structure only when it genuinely helps

## Repetition

Important things should be stated in multiple places. This is intentional, not sloppiness.

LLMs and humans alike benefit from reinforcement. A rule seen once can be skimmed past and forgotten. A rule that appears in every relevant file — restated briefly, in context — tends to stick. Markdown files in this system should include a `## Reminders` section at the bottom that restates the most critical rules in brief. Yes, this creates redundancy across files. That redundancy is the point.

*If it's important, it bears repeating.*

## Proximity shapes behavior

Context is subtly powerful. The format, structure, and visual affordances of a document actively shape what an agent does next — often more powerfully than instructions written elsewhere on the page.

The clearest example: this system's TODO files originally used `- [ ]` checkboxes. The instructions said, in multiple places, that completed items should be *removed from the todo file and promoted to `spec.md`*. The instructions were correct. They were repeated. They were even in `## Reminders` sections inside the todo files themselves.

None of that mattered. A checkbox is a checkbox. The closest identifiable pattern — "this is a task, tasks get checked off" — dominated over the textual instructions. `- [ ]` became `- [x]` and the item stayed in the file. The format communicated louder than the words.

The fix was to remove the checkbox entirely. Plain bullets have no "checked" state. There is no affordance for half-done. An item either exists (to do) or it doesn't (done, promoted). The instruction and the format now agree, and the behavior followed.

**In practice:**
- When a format or structure suggests an action, it will be taken — even if instructions say otherwise
- Affordances are instructions. A checkbox says "check me." A delete-only format says "remove me."
- Prefer formats that make the *right* action the *obvious* action, rather than relying on instruction text to override visual instinct
- When instructions and format conflict, the format usually wins — fix the format

## Comments explain why, not what

Code already says what it does. Comments exist to explain why — the context, the constraint, the history that isn't visible in the code itself.

**Why it matters:** A comment that restates code is noise that must be maintained in sync with the code or it becomes a lie. A comment that explains the *reason* for a choice remains useful even as the code evolves — it's the "load-bearing" information that would otherwise be lost.

**In practice:**
- Write `# WHY: forcing LF here prevents obscure container failures from CRLF in YAML` rather than `# Enforce LF line endings`
- Write `# WHY: test() matches any leading whitespace; ltrimstr(" ") strips only one character` rather than `# regex instead of ltrimstr`
- When code is self-explanatory, add no comment — a comment that merely restates the code is noise
- Use `# WHY:` as a prefix for standalone explanatory comments (optional convention, but makes them greppable)

## Small and fast

Ship small changes frequently. Keep PRs reviewable by a human in a few minutes. This is not a new idea — it predates AI — but it matters *more* when agents are in the loop, not less.

**Why it matters for agents:** A large PR is a large context window. The more code, spec, and history an agent must hold at once, the more likely something slips — a constraint forgotten, a decision reversed three files later, a hallucination that would have been caught earlier. Small changes let the agent focus. Small changes let the agent finish.

Large PRs also slow down the feedback loop between a human reviewer (or Copilot) and the agent running the next iteration. Every round-trip on a 200-file PR costs more tokens, more time, and more risk than three round-trips on three focused PRs. DORA metrics — deployment frequency, lead time, change failure rate, time to restore — describe what good looks like. They apply at least as strongly to agent-driven development as to team-driven development, possibly more so.

**Why it matters for humans:** A small PR is a PR a human can actually read. Adoption follows trust, and trust follows comprehension. A reviewer who can scan a diff in five minutes, check a preview deployment, and say "yes, this is what I wanted" will merge with confidence. A reviewer who opens a 100-file PR from an AI and has no idea where to start will hesitate, request changes, or close it.

**In practice:**
- One logical change per PR — one command, one feature, one fix
- Write PRs that could be explained in a single sentence
- Prefer merging a partial implementation and iterating over holding out for "complete"
- If a PR is growing large, stop and ask whether it should be split before finishing
- Design commands and worker runs to produce one small PR per run, not one large one

## Specs as source of truth

Code implements specs. Specs describe what the system is and how it behaves. When they diverge, the spec is the authority — either the code needs fixing, or the spec needs updating.

This keeps decisions visible, reviewable, and separate from implementation noise.
