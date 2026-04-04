# Assess and Refine

## Purpose

Load context for a TODO item, assess its clarity and scope, and produce an effort estimate with technical detail.

## Preconditions

- A TODO item has been selected for refinement.

## Steps

### 1. Load context

For the selected item:

1. **GH issue details:** If the item has a `[#N](url)` prefix, run `gh issue view N --json title,body,comments`. Read the body and all comments — these may contain requirements, constraints, or previous discussion. **Always check for new comments** since the issue was last refined — users often provide clarifications that make refinement easier.
2. **Spec file context:** Read the containing `.todo.md` file to understand the area and neighboring items.
3. **Current state:** Read the relevant component spec (`specs/spec.md`, `specs/scaffold.md`, `specs/worker.md`, etc.) to understand what already exists.
4. **Source scan:** If relevant source files exist and are small, do a light scan to understand the implementation surface.

### 2. Assess clarity

Work through these questions:

- Is the **what** (deliverable, behavior, interface) clear enough to implement without guessing?
- Is the **why** (purpose, user value, problem being solved) clear?
- Are there **implementation decisions** that need to be made before work can start?
- Are there known **dependencies** or **risks**?

### 3. Estimate effort

Use the sizing definitions in [../../references/sizing-guide.md](../../references/sizing-guide.md).

Prefix 0–3 `?` marks before the size to indicate confidence: `*(effort: XL)*` = high confidence; `*(effort: ?M)*` = probably Medium; `*(effort: ???S)*` = rough guess. Use more `?`s when estimating from limited context.

### 4. Handle ambiguity (mode-dependent)

**If supervised (user present in chat):**

- Ask questions directly in chat. Work iteratively — do not write anything to files until key ambiguities are resolved.
- Confirm the effort estimate with the user.
- If the user adjusts scope, priority, or approach during discussion, note it before writing.

**If headless (no user in chat):**

- Make a best-effort assessment using available context (GH issue body/comments, spec files, source).
- For questions about **product decisions or intent** (the "why" or "what") that cannot be answered from context, post a clarifying comment on the GH issue:

  ```
  🤖 Spec Agent, reporting for refinement duty! 🫡

  I'm preparing this item for implementation and have some questions:
  [1–3 specific, answerable questions]

  My current understanding: [brief summary of what will be built and how]
  Estimated effort: [XS/S/M/L/XL — one-line reasoning focused on complexity and scope]

  Once you clarify things for me, I'll get these todos refined and ready! 💎 🫡
  ```

- Mark the item with ⏳ and annotate as `*(waiting for response, asked YYYY-MM-DD)*` if key product decisions remain unanswered.
- Still add an effort estimate and whatever technical detail can be inferred from context — do not leave the item completely unrefined just because some questions remain. Make your best guess and use more `?` marks where confidence is low.
- Where clarity is low, prefix up to 3 `?` marks at the start of individual sub-bullets (right after `- `) to flag guesses. This keeps them greppable with `grep '^\s*- \?'`.

## Inputs

- A selected TODO item
- GitHub issues (via `gh` CLI) for linked items
- Relevant spec and source files

## Outputs

- Effort estimate with confidence markers.
- Technical sub-bullets (implementation approach, dependencies).
- GH comments posted if clarification needed (headless mode).
