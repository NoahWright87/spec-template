# Autonomous Worker Runtime — TODOs

## Summary
Work to build the reusable containerized worker (Layer 2): the autonomous runner that clones a target repo, loads worker instructions, and executes the intake / TODO workflow via Claude CLI. Runs as a cron job — spins up, does its work, persists memory to a Docker volume, and shuts down.

## Sooner

### Container setup
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Write worker `Dockerfile` (Claude CLI + `gh` CLI + runtime scripts; base image: node:20-slim)
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Write worker entrypoint script: init → clone/pull target repo → load built-in worker instructions → run intake/TODO workflow → exit

### Cron job execution model
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Support cron job execution model: spin up, clone/pull, run workflow, persist state to Docker volume, shut down; designed for repeated scheduled runs
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Set up Docker volume for persistent worker state / Claude memory across cron runs (GitHub and target repo remain primary system of record; volume is supporting cache)

### Runtime contract
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Define runtime secret injection: `ANTHROPIC_API_KEY`, `GITHUB_TOKEN` (do not bake into image)
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Define runtime parameter injection: `TARGET_REPO`, `TARGET_BRANCH`, execution mode flag, optional repo-specific config path

### CI/CD and publishing
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) GitHub Actions workflow: build and publish worker image to container registry when worker source files change; sensible version tagging for iterative development

### Documentation (Sooner)
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Document how to pull and run the image locally in Docker Desktop (example `docker run` command with all required secrets and parameters)

## Later

### Kubernetes support
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Kubernetes deployment readiness: document how to deploy the same image in K8s with runtime secret and parameter injection; support horizontal scaling by running one worker per target repo

### Extensibility
- [x] [#7](https://github.com/NoahWright87/spec-template/issues/7) Document how to extend the worker with additional scripts and behaviors over time (per-repo worker-instructions.md override)

### Onboarding via worker (depends on scaffold dist/ work)
- [ ] [#8](https://github.com/NoahWright87/spec-template/issues/8) Implement scaffold detection: check for expected marker files to determine install mode vs operate mode before doing any deeper workflow processing
- [ ] [#8](https://github.com/NoahWright87/spec-template/issues/8) Implement worker **install mode**: clone target repo → detect missing scaffold → copy files from `dist/` payload → create branch → commit → open bootstrap PR with clear description (what was installed, what to do next)
- [ ] [#8](https://github.com/NoahWright87/spec-template/issues/8) Implement worker **operate mode**: proceed with normal intake / refinement / TODO workflow when scaffold is already detected
- [ ] [#8](https://github.com/NoahWright87/spec-template/issues/8) Document detection mechanism, install PR format, and how to adopt the system by pointing the worker at an unscaffolded repo

## Reminders

- Move completed items to `spec.md` — this file is for future plans, not current state
- Items flow: INTAKE → `spec.todo.md` → `worker.todo.md` (worker-specific) → `spec.md` (when done)
- If a TODO item links to a GH issue (`[#N](...)`), include `closes #N` in your PR description — GitHub closes the issue on merge
- #8 onboarding items depend on `scaffold.todo.md`'s `dist/` generation work being done first
