# Autonomous Worker Runtime — TODOs

## Summary
Work to build the reusable containerized worker (Layer 2): the autonomous runner that clones a target repo, loads worker instructions, and executes the intake / TODO workflow via Claude CLI. Runs as a cron job — spins up, does its work, persists memory to a Docker volume, and shuts down.

## Backlog


## Reminders

* Move completed items to `worker.md` — this file is for future plans, not current state
* Items flow: INTAKE → `spec.todo.md` → `worker.todo.md` (worker-specific) → `worker.md` (when done)
* If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
