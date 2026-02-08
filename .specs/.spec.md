# <Name> Spec

## Purpose
Briefly describe what this thing is and why it exists.
Focus on intent, not implementation.

## Related
Links to other **specs only** (no TODO links).

## Contract
Required in every spec. Describe the inputs and outputs.

### Inputs
- Requests, parameters, events, config, environment, user actions, etc.

### Outputs
- Responses, rendered UI, side effects, persisted data, emitted events, etc.

### Guarantees / Constraints
- Invariants, ordering, idempotency, auth expectations, performance expectations, etc.

## Behavior
Describe how this behaves in practice.

- Happy path
- Alternate paths
- Empty / error states
- Edge cases worth explicitly calling out

Avoid implementation details; focus on observable behavior.

## User Experience (UX)
How will the end users / consumers interact with this?

For front end, this includes layout, content, animation, etc.
For backend / libs, this includes comments, instructions, developer ergonomics, etc.

## Acceptance
Define what "done" means in testable terms.

- Acceptance criteria (user- or system-observable)
- Test notes (unit / integration / e2e as appropriate)
- Any required logging, metrics, or signals
