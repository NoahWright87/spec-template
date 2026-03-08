# Spec Template — Current State

## Purpose

A two-product system for spec-driven development: an installable scaffold that gives AI a persistent memory in any repo, and an optional autonomous worker container that runs the intake/TODO workflow on a schedule.

## Related

- [`scaffold.md`](scaffold.md) — Layer 1 current state (scaffold files, dist/ generation)
- [`worker.md`](worker.md) — Layer 2 current state (worker container, modes, CI/CD)
- [`scaffold.todo.md`](scaffold.todo.md) — future scaffold and dist/ work
- [`worker.todo.md`](worker.todo.md) — future worker runtime work
- [`spec.todo.md`](spec.todo.md) — meta-tooling improvements (commands, UX)

## System Overview

The system has two independent layers. A repo can use Layer 1 without ever running Layer 2.

**Layer 1 — Installable scaffold:** a small set of files (spec templates, AI slash commands, a PR check workflow) that downstream repos copy in via `/respec` or from `dist/`. Gives AI a persistent spec memory in the target repo. See [`scaffold.md`](scaffold.md).

**Layer 2 — Autonomous worker:** a Docker container that clones a target repo, detects whether the scaffold is installed, and either bootstraps it (install mode) or runs the intake/TODO workflow (operate mode) on a cron schedule. See [`worker.md`](worker.md).

## Guarantees / Constraints

- Scaffold files in `dist/` are auto-generated from source — edit sources, run `scripts/generate-dist.sh`, commit result
- Worker supports two auth modes: Claude Code subscription (mount `~/.claude`) or Anthropic API key (`ANTHROPIC_API_KEY`); never bake credentials into the image
- Worker state volume is a supporting cache; GitHub and the target repo are the primary system of record
