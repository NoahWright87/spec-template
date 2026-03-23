# Agents

Agent manifests for the spec-template fleet.

Each `.md` file defines a specialized agent that does one thing well. The fleet manager reads the manifest, assembles a prompt from the referenced tasks, and invokes Claude CLI.

## Current agents

| Agent | Primary task | Description |
|-------|-------------|-------------|
| `intake` | intake-routing | Routes ideas and GitHub Issues into spec TODO files |
| `knock-out-todos` | todo-implementation | Implements the easiest open TODO items |

## How it works

See `AGENTS.md` in this directory for the full manifest format, trigger values, and conventions.

## Adding a new agent

1. Create `{name}.md` in this directory with the manifest headers and agent-specific content
2. Create a matching `.agents/{name}/` directory structure in `dist/` (scaffold payload)
3. Add the agent to `worker/fleet/defaults.json`
