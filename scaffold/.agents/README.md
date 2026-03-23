# Agent Configuration

This directory configures the [spec-template](https://github.com/NoahWright87/spec-template) autonomous worker fleet.

## Quick reference

| File | Purpose |
|------|---------|
| `config.json` | Fleet-level settings (max PRs, global preferences) |
| `coordination.json` | Cross-agent state (auto-managed, do not edit) |
| `{agent}/config.json` | Per-agent settings — **edit these** to customize behavior |
| `{agent}/AGENTS.md` | Per-agent instructions — **edit these** to add repo-specific guidance |
| `{agent}/state.json` | Agent state (auto-managed, do not edit) |

## Customizing agent behavior

Edit `{agent}/config.json` to change settings like labels to ignore or max items per run.

Edit `{agent}/AGENTS.md` to add repo-specific instructions (e.g., "always route auth issues to `specs/auth/`").

## More information

- [spec-template source repo](https://github.com/NoahWright87/spec-template)
- [PHILOSOPHY.md](https://github.com/NoahWright87/spec-template/blob/main/PHILOSOPHY.md) — design principles
