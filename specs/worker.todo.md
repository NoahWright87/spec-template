# Autonomous Worker Runtime — TODOs

## Summary
Work to build the reusable containerized worker (Layer 2): the autonomous runner that clones a target repo, loads worker instructions, and executes the intake / TODO workflow via Claude CLI. Runs as a cron job — spins up, does its work, persists memory to a Docker volume, and shuts down.

## Backlog

- [#14](https://github.com/NoahWright87/spec-template/issues/14) Reduce token usage for no-op and low-activity runs: pre-compute things deterministically (e.g. open PR count, zero comments) before invoking Claude so the model doesn't have to run shell commands itself; document a "pre-flight" phase for the worker entrypoint

## Reminders

* Move completed items to `worker.md` — this file is for future plans, not current state
* Items flow: INTAKE → `spec.todo.md` → `worker.todo.md` (worker-specific) → `worker.md` (when done)
* If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
