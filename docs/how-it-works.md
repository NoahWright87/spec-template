# How Spec Template Works

> *This page is for technical leaders and engineers who want to understand the system architecture. For the executive summary, see [Overview](overview.md).*

---

## Architecture: Two Independent Layers

Spec Template has two layers. A repo can use either one independently — Layer 1 is interactive (human-in-the-loop), Layer 2 is autonomous (agents run on their own).

```mermaid
flowchart TB
    subgraph layer1 ["Layer 1 — Claude Code Plugin"]
        direction TB
        User[Developer in IDE] -->|runs /what-now| Plugin[Claude Code Plugin]
        Plugin --> Intake["/what-now:intake\nRoute issues to specs"]
        Plugin --> Refine["/what-now:refine\nClarify TODOs, estimate effort"]
        Plugin --> Implement["/what-now:knock-out-todos\nImplement TODOs"]
        Plugin --> Review["/what-now:pr-review\nSelf-review & respond to comments"]
        Plugin --> Backfill["/what-now:spec-backfill\nGenerate specs from code"]
    end

    subgraph layer2 ["Layer 2 — Autonomous Worker"]
        direction TB
        Cron[K8s CronJob] -->|triggers| Worker[Worker Container]
        Worker -->|clones repo| Repo[(Target Repo)]
        Worker --> ScoutAgent[Scout Agent\nProgress reports]
        Worker --> RefineAgent[Refine Agent\nTriage issues, refine TODOs]
        Worker --> IntakeAgent[Intake Agent\nRoute issues to spec files]
        Worker --> KOTAgent[Knock-out-todos Agent\nImplement & open PRs]
    end

    layer1 -.- |"same spec files,\nsame workflows"| layer2

    style layer1 fill:#e8f4fd,stroke:#4A90D9
    style layer2 fill:#d4edda,stroke:#28a745
```

### Layer 1 — Claude Code Plugin (Interactive)

The plugin gives developers a set of commands accessible via `/what-now` in Claude Code. It's the on-ramp: install it, run the command, and the assistant walks you through what needs doing in your repo.

**Install:** `claude plugin install spec-template@NoahWright87/spec-template`

The plugin works with spec files that live in your repo's `specs/` directory. These are plain markdown — no special tooling, no database, no external service.

### Layer 2 — Autonomous Worker (Unattended)

The worker is a Docker container that runs on a schedule via Kubernetes CronJobs. It clones a target repo, checks what needs doing, runs the appropriate agents, and exits. Each agent gets its own branch and PR.

The worker is completely optional. Many teams start with Layer 1 (interactive) and add Layer 2 when they're ready for full automation.

---

## The Spec System

Specs are the backbone. They're plain markdown files that describe what the system does (current state) and what's planned (TODOs). The AI reads specs before writing code and updates them after.

```mermaid
flowchart LR
    subgraph specfiles ["specs/ directory"]
        Spec["feature.spec.md\n(current state)"]
        Todo["feature.todo.md\n(planned work)"]
        IssueTodo["feature.issue-42.todo.md\n(per-issue work)"]
    end

    subgraph lifecycle ["TODO Lifecycle"]
        direction TB
        New["❓ New\n(needs refinement)"] --> Refined["💎 Refined\n(ready to implement)"]
        Refined --> Implemented["Moved to spec.md\n(done)"]
    end

    Todo --> lifecycle
    IssueTodo --> lifecycle
    Implemented --> Spec

    style specfiles fill:#fff3cd,stroke:#ffc107
    style lifecycle fill:#e8f4fd,stroke:#4A90D9
```

### File types

| File | Purpose |
|------|---------|
| `specs/spec.md` | Root spec — what the system does today |
| `specs/feature.spec.md` | Feature-specific current state |
| `specs/feature.todo.md` | Planned work for a feature |
| `specs/feature.issue-N.todo.md` | Work tied to a specific GitHub issue (prevents merge conflicts between agents) |
| `specs/AGENTS.md` | Instructions for agents working in this repo's specs |
| `specs/INTAKE.md` | Intake bucket for raw ideas |

### TODO lifecycle

TODOs progress through two states:

1. **❓ (Unrefined)** — a raw idea or issue that needs clarification. The refine agent adds effort estimates, asks clarifying questions, and breaks down vague requests.
2. **💎 (Refined)** — clear, estimated, and ready to implement. The knock-out-todos agent picks these up and writes the code.

When a TODO is implemented, it's removed from the todo file and the corresponding spec.md is updated to reflect the new current state.

---

## The Agents

Four built-in agents ship with the worker. Each has a specific job and runs independently.

```mermaid
flowchart TD
    subgraph inputs ["Signals"]
        NewIssue["New GitHub Issue\n(no intake:* label)"]
        ReadyIssue["Issue labeled\nintake:ready"]
        UnrefinedTodo["❓ TODO in spec"]
        RefinedTodo["💎 TODO in spec"]
        ReportDue["Report date reached"]
        PRComment["Human comment\non a PR"]
    end

    subgraph agents ["Agents"]
        Refine["Refine Agent\nTriage issues, refine TODOs"]
        Intake["Intake Agent\nRoute issues → spec files"]
        KOT["Knock-out-todos Agent\nImplement changes"]
        Scout["Scout Agent\nProgress reports"]
    end

    NewIssue --> Refine
    UnrefinedTodo --> Refine
    ReadyIssue --> Intake
    RefinedTodo --> KOT
    ReportDue --> Scout
    PRComment --> KOT
    PRComment --> Intake
    PRComment --> Refine

    style inputs fill:#fff3cd,stroke:#ffc107
    style agents fill:#d4edda,stroke:#28a745
```

| Agent | Trigger | What it does |
|-------|---------|-------------|
| **Refine** | New issue without `intake:*` label, or ❓ TODOs in specs | Assesses issues, asks clarifying questions, labels `intake:ready` when clear. Refines TODOs with effort estimates. |
| **Intake** | Issue labeled `intake:ready` | Routes the issue into the correct spec TODO file. Creates per-issue files to prevent merge conflicts. |
| **Knock-out-todos** | 💎 TODOs in specs, or human comments on PR | Implements the TODO, writes code, updates specs, opens a PR. Responds to reviewer feedback. |
| **Scout** | Report interval reached | Generates periodic progress reports summarizing what agents have accomplished. |

### How agents avoid stepping on each other

- Each agent gets its **own branch** (`worker/{agent-name}/YYYY-MM-DD`) and its **own PR**
- Per-issue TODO files (`feature.issue-42.todo.md`) prevent agents from editing the same file
- **Dual PR cap** — per-agent and fleet-wide limits prevent runaway PR creation
- Agents only run when their specific **activity signal** fires (no wasted cycles)

---

## Worker Execution Flow

When the worker container starts, it follows a deterministic sequence:

```mermaid
flowchart TD
    Start([CronJob fires]) --> Auth[Authenticate\nGitHub App or PAT]
    Auth --> Clone[Clone target repo]
    Clone --> Check{Scaffold\ninstalled?}
    Check -->|No| Install["Install mode\nCopy templates, open bootstrap PR"]
    Check -->|Yes| Config[Read .agents/config.yaml]
    Config --> Loop["For each declared agent:"]
    Loop --> Signal{"Activity\nsignal?"}
    Signal -->|No signal| Skip[Skip agent]
    Signal -->|Yes| PRCheck{Existing\nPR?}
    PRCheck -->|Yes, has comments| Run1[Run agent\nto respond]
    PRCheck -->|Yes, has conflicts| Run2[Run agent\nto resolve]
    PRCheck -->|No PR| Run3[Run agent\nfor new work]
    PRCheck -->|Yes, no action needed| Skip
    Run1 --> Next[Next agent]
    Run2 --> Next
    Run3 --> Next
    Skip --> Next
    Next --> Loop
    Loop -->|all agents done| Notify[Slack notification]
    Notify --> Exit([Exit])

    style Start fill:#4A90D9,color:#fff
    style Exit fill:#4A90D9,color:#fff
```

Key details:
- **Scaffold detection** — if the repo hasn't been set up yet, the worker auto-installs the scaffold via a bootstrap PR
- **Activity signals** — each agent only runs when there's actual work to do (new issues, unrefined TODOs, etc.)
- **Situation report** — before each agent runs, the entrypoint pre-fetches PR state, comments, and conflict status so the agent starts with full context
- **Comment deduplication** — agents only see comments that still need a response, preventing duplicate replies across runs
- **Slack notifications** — optional per-run summaries sent to team channels

---

## Multi-Repo Deployment

The worker image is repo-agnostic. Repo-specific configuration is injected via environment variables at deploy time.

```mermaid
flowchart LR
    subgraph k8s ["Kubernetes"]
        Base["Kustomize Base\n(shared CronJob template)"]
        Base --> O1["Overlay: repo-a"]
        Base --> O2["Overlay: repo-b"]
        Base --> O3["Overlay: repo-c"]
    end

    O1 --> R1[(repo-a)]
    O2 --> R2[(repo-b)]
    O3 --> R3[(repo-c)]

    style k8s fill:#e8f4fd,stroke:#4A90D9
```

**Adding a new repo** takes three steps:
1. Create a Kustomize overlay with the repo's `TARGET_REPO` env var
2. Add it to the top-level `kustomization.yaml`
3. Deploy — the worker auto-detects whether the repo needs scaffolding

Each repo configures its own agents via `.agents/config.yaml`:

```yaml
version: 2
agents:
  - scout
  - refine
  - intake
  - knock-out-todos
settings:
  max_open_prs: 3        # max simultaneous agent PRs
  specs_dir: specs
```

---

## Safety & Guardrails

Spec Template includes several safety mechanisms:

- **Agent audit workflow** — PRs from agent branches are automatically scanned for suspicious patterns (external network calls, dynamic eval, hardcoded credentials, prompt injection markers). Findings block merge until a human reviews.
- **Auto-merge with escape hatch** — agent PRs enable auto-merge after checks pass, but this is skipped when the agent has posted a clarifying question that needs human input.
- **Zero-change abandonment** — if a PR ends up with no net file changes (e.g., after resolving a merge conflict by accepting the target branch), the agent closes the PR and reports the abandonment rather than merging an empty diff.
- **PR focus guard** — when a PR is already open, agents don't pile on unrelated changes. Large or out-of-scope reviewer requests are pushed back with a comment and tracked as a new issue.
- **Bot comment prefix** — all agent comments use a bot prefix so humans can instantly distinguish agent activity from human discussion.

---

## Further Reading

| Document | What it covers |
|----------|---------------|
| [Executive Overview](overview.md) | High-level pitch, impact stats, vision |
| [Worker README](../worker/README.md) | Deployment, authentication options, troubleshooting |
| [Kubernetes Guide](../k8s/README.md) | K8s CronJobs, Kustomize overlays, Vault integration, monitoring |
| [Philosophy](../PHILOSOPHY.md) | Design principles (affirmative language, minimalism, proximity-shaped behavior) |
| [Contributing](../CONTRIBUTING.md) | Codebase layout, plugin vs. worker editing conventions |
| [Specs Directory](../specs/README.md) | Spec file structure and conventions |
