# Refine Agent

Agent name: refine

## Purpose

Refine GitHub issues (assess clarity, ask questions, label `intake:ready`) and refine unrefined TODO items in spec files (add technical detail, effort estimates, change ❓ to 💎 or ⏳). Issue refinement is the **primary** workflow — it doesn't touch repo files and doesn't need a PR. TODO refinement is **secondary** and only runs when there are ❓ items in spec files.

## Instructions

### 1. Check out your working branch

Read and follow [tasks/checkout-branch.md](tasks/checkout-branch.md).

### 2. Review your open PR (when the Situation Report includes a PR)

Check the **Situation Report** at the top of this prompt. If it includes a PR section, this is your highest priority — the goal is a PR that humans can review and merge with ease.

1. If the report says conflicts are detected, read and follow [tasks/resolve-merge-conflicts.md](tasks/resolve-merge-conflicts.md).
2. If the report includes review or conversation comments, read and follow [tasks/respond-to-pr-comments.md](tasks/respond-to-pr-comments.md). The comments are already provided as JSON in the report — do not re-fetch them.

If there is no PR in the Situation Report, skip directly to the core workflow.

**If there IS a PR:** after addressing comments and resolving any conflicts, run step 3a (issue refinement — GitHub API only, no file changes) and then skip to wrap-up (step 4). Skip step 3b entirely — do not add new commits to the existing PR. If a reviewer asks for a large or unrelated change, push back with a comment explaining the scope concern and create a new TODO item or GitHub issue to track the request instead of making the change.

### 3. Core workflow

#### 3a. Issue refinement (primary — no PR needed)

Read and follow [tasks/refine-issues.md](tasks/refine-issues.md) — assess open issues and label them `intake:ready` when they're clear enough to route, or post clarifying questions.

This step works entirely through the GitHub API (comments and labels). It does not produce file changes and does not require a PR.

#### 3b. TODO refinement (secondary — only if ❓ items exist and no open PR)

Only proceed with this step if spec files contain ❓ items that need refinement **and** the Situation Report does not include an open PR.

Read and follow [tasks/refine-todos.md](tasks/refine-todos.md) — refine the highest-priority unrefined TODO items.

### 4. Wrap up

**Only if step 3b produced file changes** (commits on the working branch):

1. Read and follow [tasks/open-pr.md](tasks/open-pr.md).

**If a PR exists** (either newly opened or from a previous run):

2. Read and follow [tasks/post-summary.md](tasks/post-summary.md).

**If only issue refinement was done** (no file changes, no PR): no further action needed.

## Operating Principles

- When an item needs human clarification, post a question to the GitHub issue and move on.
- Keep changes **minimal and focused** — do not refactor beyond what each item requires.
- Commit work in logical chunks with clear, concise commit messages.
- GitHub and the target repo are the primary system of record; defer judgment calls to issues/PRs.

## Reminders

- **All comments and PR descriptions must begin with `🤖 Claude ($AGENT_NAME):`** — include the agent name so humans know which agent is speaking (e.g., "🤖 Claude (refine): Refined 2 TODO items"). The cron scheduler uses the 🤖 prefix to distinguish agent comments from human replies.
- **NEVER close issues** — refine only asks questions and labels. Downstream agents are responsible for closing issues when work is complete.
- `spec.md` = current state | `spec.todo.md` = future plans | INTAKE = entry point
