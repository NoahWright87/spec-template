# Intake Routing

> Purpose: Route ideas and GitHub Issues into the correct spec TODO files
> Scope: INTAKE.md processing, GitHub issue labeling, spec file routing

## Execute the intake workflow

Read `/worker/commands/lib/intake.md` and execute its full workflow.

Pull in any open GitHub issues, route them to the correct spec files, apply labels, and handle any items waiting for more information.

## Operating context

- You are running headless — post clarifying questions as GitHub comments (prefixed with `🤖 Claude ($AGENT_NAME):`) rather than waiting for interactive input.
- Prefer existing `.todo.md` files over creating new ones when routing.
- For items spanning multiple components, create one entry per relevant `.todo.md` file.
