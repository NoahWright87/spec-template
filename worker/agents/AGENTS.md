# Agents Directory

Each `.md` file in this directory (other than this one and README.md) is an **agent manifest** — it declares which tasks the agent uses, what triggers it, and provides agent-specific mission and context.

## Manifest format

Agent manifests use `> ` header lines that the fleet manager parses:

```markdown
# Agent Name

> Tasks: task-a, task-b, task-c
> Primary: task-b
> Trigger: unprocessed-issues, human-comment-on-pr
> Workspace: .agents/agent-name
```

### Header fields

| Field | Required | Description |
|-------|----------|-------------|
| `Tasks` | Yes | Comma-separated, ordered list of task IDs (filenames without `.md` from `worker/tasks/`). Order matters — tasks listed earlier appear earlier in the assembled prompt and receive more emphasis. |
| `Primary` | Yes | The main task this agent performs (informational, used for logging). |
| `Trigger` | Yes | Activity signals that cause this agent to run. See trigger values below. |
| `Workspace` | Yes | Path in the target repo where this agent's config, state, and instructions live. |

### Trigger values

| Value | Fires when |
|-------|-----------|
| `unprocessed-issues` | Open GitHub issues exist with no intake label |
| `human-comment-on-pr` | A human commented on this agent's open PR |
| `human-comment-on-filed-issue` | A human commented on a `intake:filed` issue |
| `merge-conflict` | This agent's open PR has merge conflicts |
| `always` | Every scheduled run (use sparingly) |

### Body content

Everything below the `> ` header lines is agent-specific content. It is appended to the end of the assembled prompt, after all task files. This is where you define the agent's mission, personality, operating principles, and any context specific to its role.

## Adding a new agent

1. Create a new `.md` file in this directory
2. Add the `> Tasks:`, `> Primary:`, `> Trigger:`, and `> Workspace:` headers
3. Write the agent's mission and operating context
4. Create the corresponding `.agents/{name}/` directory in the scaffold (see `dist/`)
5. Add the agent name to `worker/fleet/defaults.json` agent catalog

## Conventions

- `echo-chamber-prevention` is always the first task — it ensures agents identify themselves and interact only with humans.
- `branch-management` comes second — agents set up their working branch before doing any work.
- `commit-and-push`, `pr-creation`, and `summary-reporting` come last — they handle output after work is done.
- The primary work task (intake-routing, todo-implementation, etc.) goes in the middle.
