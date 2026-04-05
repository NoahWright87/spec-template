# Fill from Source (Deep Mode)

## Purpose

Read source code for a specific module or area and fill the Contract and Behavior sections of its spec with what the code reveals. Only used when `$ARGUMENTS` explicitly requests a deep read.

## Preconditions

- `$ARGUMENTS` names a specific module or area (e.g., `go deep in the auth module`).
- The target spec file exists (with `> **TODO:**` sections to fill).

## Steps

For the area named in `$ARGUMENTS`:

1. **Read source files** in that area. Understand what the module accepts, produces, and guarantees.

2. **Fill the Contract** (Inputs, Outputs, Guarantees) with what the code reveals:
   - What parameters, configs, or events does it accept?
   - What does it return, emit, or persist?
   - What invariants does it maintain?

3. **Fill the Behavior section** with what the code reveals:
   - What's the happy path?
   - What alternate paths exist?
   - What error states are handled?
   - Any notable edge cases?

4. **Flag unclear intent:** Where the code's behavior is clear but the *intent* is unclear, note it:
   ```
   > **TODO:** Behavior observed, but intent unclear — verify with module owner.
   ```

5. **Scope limit:** Deep mode is scoped to the named area only. A full-repo deep read is too slow and token-heavy to be useful.

## Inputs

- Source files in the named area
- Existing spec file for that area

## Outputs

- Contract and Behavior sections filled from source.
- Intent-unclear flags where needed.
