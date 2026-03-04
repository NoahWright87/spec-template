# spec-template

A minimal system for keeping specs as the source of truth in any repo. Works with Claude, Cursor, Copilot, or any LLM-powered IDE.

Read [PHILOSOPHY.md](PHILOSOPHY.md) for the thinking behind the design choices.

## Quick start

Paste this into your AI assistant from inside your repo:

```markdown
Read the file at `https://github.com/NoahWright87/spec-template/tree/main/.claude/commands/respec.md` and follow its instructions to apply the spec-template system to this repository.
```

The AI will fetch the `/respec` command, assess what already exists in your repo, and walk you through the setup interactively.

**Claude users:** After the initial setup, run `/respec` any time to pull in upstream updates.

**Other IDEs:** The same prompt works for updates too. The command file is plain markdown — paste it again or adapt it to your IDE's native format.

## What gets installed

| Path | Purpose |
|------|---------|
| `specs/` | Starter spec directory: templates, intake bucket, agent instructions |
| `.claude/commands/respec.md` | Apply or update this template |
| `.claude/commands/intake.md` | File ideas into the right spec |
| `.claude/commands/knock-out-todos.md` | Implement the easiest open TODOs |

See [specs/README.md](specs/README.md) and [AGENTS.md](AGENTS.md) for how the spec system works.

## Opting out

Delete `specs/` and remove `respec.md`, `intake.md`, and `knock-out-todos.md` from `.claude/commands/`. That's everything the template installed.
