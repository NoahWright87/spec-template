# T-Shirt Sizing Guide

## Purpose

Standard effort labels for TODO items. Used by the refine and implement agents to assess and prioritize work.

## Size Definitions

| Size | Meaning | Typical scope |
|------|---------|---------------|
| **XS** | Trivial | Self-contained, no risk of side effects. A single file edit, a config change, a typo fix. |
| **S** | Small and well-understood | Clear scope, minimal coordination needed. A few file edits in one area. |
| **M** | Moderate | Spans a few files or touches non-trivial logic. May require reading existing code to understand impact. |
| **L** | Substantial | Crosses components or requires careful coordination. Multiple files, possibly multiple areas of the codebase. |
| **XL** | Large and complex | Must be broken down before implementation. If it keeps growing during refinement, split it into a new `.todo.md` file or chunk into smaller sequential items. |
| **Unknown** | Not enough context | Cannot assess complexity yet. Needs clarification before sizing. |

## Confidence Markers

Prefix `?` marks before the size to indicate how confident you are in the estimate:

| Annotation | Confidence | Meaning |
|------------|------------|---------|
| `*(effort: M)*` | High | You've read the relevant code and understand the scope. |
| `*(effort: ?M)*` | Medium | Probably Medium, but there are unknowns that could shift it. |
| `*(effort: ??M)*` | Low | Educated guess based on limited context. |
| `*(effort: ???M)*` | Very low | Rough guess — needs clarification before anyone should act on this. |

Use more `?`s when estimating from limited context. `???` is a signal to reviewers that this item needs discussion before implementation. Prefixing makes uncertain estimates greppable: `grep 'effort: \?'` finds all items with low confidence.

You can also prefix `?` on individual sub-bullets to flag specific guesses. The `?` goes right after `- ` so it's greppable with `grep '^\s*- \?'`:

```
- 💎 Add auth middleware *(effort: ?M)*
  - ? wrap Express routes with JWT validation
  - ??? auth service API — need to confirm endpoint format
```

## Usage in TODO Files

Refined items look like:
```
- 💎 [#42](url) Add user preferences page *(effort: M)*
  - Implementation: new React component + API endpoint for CRUD
  - Depends on: user service auth token flow (already in place)
```

Unrefined items have no sizing annotation:
```
- ❓ [#43](url) Improve error handling in checkout flow
```

The implement agent picks only 💎 items (refined and ready). ❓ (unrefined) and ⏳ (waiting) items are skipped.
