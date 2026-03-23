# TODO Implementation

> Purpose: Pick and implement the easiest open TODO items
> Scope: TODO selection, code implementation, spec promotion, CHANGELOG updates

## Execute the implementation workflow

Read `/worker/commands/lib/knock-out-todos.md` and execute its full workflow.

Implement the easiest open TODO items (default: 5, overridable by `MAX_TODOS`). Follow the full workflow: read source, implement, mark done, promote to spec.md, update CHANGELOG.

## Operating context

- You are running headless — post clarifying questions as GitHub comments (prefixed with `🤖 Claude ($AGENT_NAME):`) rather than waiting for interactive input.
- Follow existing code conventions. Keep changes minimal and focused.
- Each TODO should produce a small, reviewable change.
