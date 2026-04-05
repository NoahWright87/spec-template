# Spec Template — Current State

## Purpose

A multi-layer system for spec-driven development: an installable scaffold that gives AI a persistent memory in any repo, composable agent definitions that break work into reusable tasks, a plugin for Claude Code distribution, and an optional autonomous worker container that runs agents on a schedule.

## Related

- [`scaffold.md`](scaffold.md) — Layer 1 current state (scaffold files, templates)
- [`worker.md`](worker.md) — Layer 2 current state (worker container, modes, CI/CD)
- [`scaffold.todo.md`](scaffold.todo.md) — future scaffold work
- [`worker.todo.md`](worker.todo.md) — future worker runtime work
- [`spec.todo.md`](spec.todo.md) — meta-tooling improvements (commands, UX)

## System Overview

The system has three independent layers. A repo can use Layer 1 without ever running Layer 2 or 3.

**Layer 1 — Installable scaffold:** a small set of files (spec templates, AI slash commands, a PR check workflow, agent config) that the worker installs into target repos or that users install via the plugin. Gives AI a persistent spec memory in the target repo. See [`scaffold.md`](scaffold.md).

**Layer 2 — Composable agents:** four agent definitions (intake, refine, knock-out-todos, scout) in `agents/` with reusable task files in `agents/tasks/`. Each agent follows a common pattern: check out branch → handle existing PR → core workflow → wrap up. See agent definitions in `agents/*.md`.

**Layer 3 — Autonomous worker:** a Docker container that clones a target repo, detects whether the scaffold is installed, and either bootstraps it (install mode) or runs agents (operate mode) on a cron schedule. See [`worker.md`](worker.md).

## Commands

- `/what-now`: Thin interactive entrypoint — presents a menu via AskUserQuestion and delegates to the chosen command by reading and following that command file. Lazy-loads only the selected command; no other files enter context. Intended for supervised use; the worker and autonomous agents use `specs/AGENTS.md` directly.
  - **Status assessment:** reads `specs/.meta.json` for the `"what_now_assess"` key (`"auto"` or `"on_demand"`); prompts and saves preference on first use. In auto mode, runs a pre-flight check before showing the menu and labels options ⭐ Highly recommended / Recommended based on findings.
  - `pr-review` (Steps 1–5): Self-review the PR diff → batch-fix all issues in one commit → leave explanatory PR comments on the diff → respond to Copilot/auto-review comments → respond to human review comments. All AI comments start with 🤖.
  - `intake` (Steps 1–8): Route ideas from INTAKE.md and GitHub Issues into TODO spec files.
  - `refine` (Steps 1–6): Refine GitHub issues and TODO items — add effort estimates, technical detail.
  - `knock-out-todos` (Steps 1–9): Implement the easiest open TODO items.
  - `spec-backfill`: Generate spec files from an existing codebase.

## Agents

Four autonomous agents, each with its own branch and PR:

- **intake** — routes GitHub Issues and INTAKE.md submissions into TODO spec files
- **refine** — assesses issue clarity, labels `intake:ready`, adds effort estimates to TODOs
- **knock-out-todos** — implements the easiest refined TODO items
- **scout** — generates periodic progress reports

Agent definitions live in `agents/*.md`. Reusable tasks in `agents/tasks/*.md`. Templates for scaffold installation in `agents/templates/`.

## Plugin

The plugin system (`plugin/commands/`, `.claude-plugin/plugin.json`) enables distribution via `claude plugin install spec-template@NoahWright87/spec-template`. Plugin commands mirror `.claude/commands/` for the same functionality.

## Scripts

- `scripts/generate-roadmap.sh` — generates `docs/ROADMAP.md` from all `specs/**/*.todo.md` files; groups open items by area with links back to individual spec files; suitable for GH Pages publishing
- `.github/workflows/pages.yml` — publishes `docs/` and `specs/` to GitHub Pages on push to main

## Human-Facing Docs

- `README.md` is the human entrypoint; Quick Start (plugin install) appears first before any background explanation
- AI-facing instructions live in `.claude/commands/`, `plugin/commands/`, and `specs/AGENTS.md` — not in the README

## Guarantees / Constraints

- Scaffold templates live in `agents/templates/` — the worker copies them directly into target repos during install mode
- Worker supports two auth modes: Claude Code subscription (mount `~/.claude`) or Anthropic API key (`ANTHROPIC_API_KEY`); never bake credentials into the image
- GitHub auth supports GitHub App (recommended) or PAT (GH_TOKEN)
- Worker state volume is a supporting cache; GitHub and the target repo are the primary system of record
