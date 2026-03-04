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

## Specs as source of truth

Code implements specs. Specs describe what the system is and how it behaves. When they diverge, the spec is the authority — either the code needs fixing, or the spec needs updating.

This keeps decisions visible, reviewable, and separate from implementation noise.
