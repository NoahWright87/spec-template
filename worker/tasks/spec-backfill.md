# Spec Backfill

> Purpose: Generate or improve specs that mirror the codebase
> Scope: Source code discovery, spec gap detection, placeholder creation, test-driven filling

## Execute the spec backfill workflow

Read `/worker/commands/lib/spec-backfill.md` and execute its full workflow.

Discover source and test roots, identify spec gaps, create placeholder specs with `> **TODO:**` markers, and fill sections from tests and source code.

## Operating context

- You are running headless — report findings and proceed with best judgment rather than waiting for interactive input.
- This workflow is idempotent — it can be re-run at any time to check remaining gaps.
- Prefer creating accurate partial specs over speculative complete specs.
