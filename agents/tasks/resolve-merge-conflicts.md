# Resolve Merge Conflicts

## Purpose

Ensure the agent's open PR can be merged cleanly before doing any new work.

## Preconditions

- The **Situation Report** at the top of your prompt indicates merge conflicts on the PR.
- You are on the agent branch (`$AGENT_BRANCH`).

## Steps

The Situation Report has already confirmed that merge conflicts exist — you do not need to check the GitHub API for mergeable status.

1. Make sure you are on your agent branch (`$AGENT_BRANCH`)
2. Merge the repo's base branch into your branch — do NOT rebase (rebase rewrites history and confuses reviewers):
   ```bash
   BASE_BRANCH="${TARGET_BRANCH:-main}"
   git fetch origin "$BASE_BRANCH"
   git merge "origin/$BASE_BRANCH" --no-edit
   ```
3. Resolve any conflicts. Keep your changes where they are correct; accept upstream changes where the base branch has moved on. The goal is a clean merge commit — no extra unrelated changes should appear in the PR diff.
4. Commit and push immediately so the PR is unblocked for reviewers.

Only after the PR is conflict-free should you continue to the next task.

## Inputs

- Situation Report (at the top of your prompt) — confirms conflicts exist
- `AGENT_BRANCH` — the current working branch
- `TARGET_BRANCH` — the base branch to merge from (default: `main`)

## Outputs

- PR is conflict-free and ready for review.
