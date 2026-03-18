# spec-template

Your AI writes code. This gives it a memory.

---

## Quick start

Paste this into your AI assistant from inside your repo:

```
Read the file at `https://github.com/NoahWright87/spec-template/blob/main/.claude/commands/lib/respec.md` and follow its instructions to apply the spec-template system to this repository.
```

The assistant fetches the `/respec` command, checks what already exists, and walks you through setup interactively. Nothing gets touched without your approval.

**Claude users:** After setup, run `/respec` any time to pull in updates.

**Other IDEs:** The same prompt works for updates too. The command files are plain markdown — paste them in or adapt them to your IDE's native format.

---

## What is this?

Specs are plain markdown files describing what your system does and what's planned. Your AI reads them before touching code. When work is done, it updates them. Everything stays in sync — without anyone manually maintaining anything.

No new tools. No process changes. Just files that live in your repo.

### Tried keeping specs up to date before?

It never sticks. Someone writes a spec, the code drifts, the spec rots.

This system sidesteps the problem: **your AI does the upkeep**. It updates specs after implementing TODOs. It flags when code changes don't have a matching spec update. It generates specs from existing code if you're starting late.

The specs stay current because the same thing writing the code is also writing the docs.

GitHub Issues plug right in too. File an issue the way you already do. Run `/intake` and it routes the work to the right spec file, labels the issue, and asks you if anything's unclear. When the work is done, it links back to close it.

### One person can add this today

No team meeting required. No process overhaul.

Teammates who don't use it won't notice it's there. Teammates who do get free context when they hand work to their AI. The specs accumulate quietly, and your whole team benefits over time.

If you tried SpecKit and it didn't stick, this is different. SpecKit asked everyone to adopt a new process. This slides in under the workflow you already have — one engineer, one afternoon.

---

## What you get

Commands that cover the whole loop:

| Command | What it does |
|---------|-------------|
| `/what-now` | **The only command you need to remember.** Assesses your repo and routes you to the right next step — all other commands are accessed through this one |
| `/respec` | Install or update the spec system in any repo |
| `/intake` | Sort ideas and GitHub Issues into the right TODO spec |
| `/refine` | Add detail and effort estimates to TODO items before implementing |
| `/knock-out-todos` | Implement open TODOs and keep specs current |
| `/pr-review` | Self-review your open PRs and respond to reviewer comments |
| `/spec-backfill` | Generate specs from an existing codebase |

See [.claude/commands/README.md](.claude/commands/README.md) for the full command guide with flow diagrams.

---

## What gets installed

| Path | Purpose |
|------|---------|
| `specs/` | Starter spec directory: templates, intake bucket, agent instructions |
| `.claude/commands/what-now.md` | Entry point — assesses repo status and recommends next step |
| `.claude/commands/lib/respec.md` | Install or update this template |
| `.claude/commands/lib/intake.md` | File ideas into the right spec |
| `.claude/commands/lib/refine.md` | Add detail and effort estimates to TODO items |
| `.claude/commands/lib/knock-out-todos.md` | Implement open TODOs |
| `.claude/commands/lib/pr-review.md` | Self-review open PRs and respond to comments |
| `.claude/commands/lib/spec-backfill.md` | Bootstrap specs from existing code |
| `.github/workflows/spec-check.yml` | PR check: warns when source changes lack spec updates |

---

## Opting out

Delete `specs/` and remove the command files from `.claude/commands/`. That's everything the template installed.

---

## Running on autopilot (optional)

The scaffold works on demand — you ask your AI, it helps. That's the simple path.

If you want fully **autonomous operation** — Claude continuously working on its own — this repo also provides a worker container. It runs as a cron job: wakes up, clones your repo, runs intake and TODO processing, and exits. No human in the loop required.

The worker supports a multi-agent architecture — each agent (intake, knock-out-todos) gets its own branch and PR, controlled by a `worker-config.yaml` in the target repo. Deploy with Docker Compose for local use or Kubernetes CronJobs for production.

See [`worker/README.md`](worker/README.md) for setup and deployment instructions, or [`k8s/README.md`](k8s/README.md) for Kubernetes-specific guidance.

---

Read [PHILOSOPHY.md](PHILOSOPHY.md) for the thinking behind the design choices.
