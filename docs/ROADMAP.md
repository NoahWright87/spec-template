<!-- AUTO-GENERATED — do not edit directly.
     Source: specs/**/*.todo.md
     Regenerate: run scripts/generate-roadmap.sh from the repo root. -->

# Roadmap

Open TODO items across all spec files, grouped by area.
Generated 2026-03-10 from the [spec files](../specs/).

## [Spec Template — Roadmap](../specs/spec.todo.md)

- [#3](https://github.com/NoahWright87/spec-template/issues/3) Add `/refine` command: middle step between `/intake` and `/knock-out-todos` that clarifies vague TODOs by asking the user questions interactively (or posting to GH issue comments in headless mode); opens a PR with updated spec/todo docs, added technical detail, effort estimates (XS/S/M/L/XL/Unknown), and any priority adjustments
- [#4](https://github.com/NoahWright87/spec-template/issues/4) Separate human-facing docs from AI-facing docs; make README the clear entrypoint for humans with the onboarding command surfaced first
- [#4](https://github.com/NoahWright87/spec-template/issues/4) Audit commands and consider combining or routing via a meta `/help` command so humans have less to remember
- [#5](https://github.com/NoahWright87/spec-template/issues/5) Auto-create GH issues for INTAKE items that aren't linked to one yet (optional, opt-in via config — not everyone will want this)
- [#6](https://github.com/NoahWright87/spec-template/issues/6) GitHub Action that publishes both `/docs` and `/specs` to a single GH Pages site
- [#13](https://github.com/NoahWright87/spec-template/issues/13) Auto-generate a human-readable roadmap from TODO spec files and place it in `/docs` for easy GH Pages publishing; roadmap view should link back to individual spec files
- When `/respec` runs in Update mode, compare the `dist/specs/spec.todo.md` template against the local TODO files. If the format differs (e.g. checkboxes vs plain bullets), offer to migrate existing TODO items to the current format. Apply only with user approval.

## [Autonomous Worker Runtime — TODOs](../specs/worker.todo.md)

- [#14](https://github.com/NoahWright87/spec-template/issues/14) Reduce token usage for no-op and low-activity runs: pre-compute things deterministically (e.g. open PR count, zero comments) before invoking Claude so the model doesn't have to run shell commands itself; document a "pre-flight" phase for the worker entrypoint

