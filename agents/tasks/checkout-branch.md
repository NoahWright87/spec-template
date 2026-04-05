# Checkout Branch

## Purpose

Create or check out the agent's working branch so all work happens on the correct branch.

## Preconditions

- `AGENT_BRANCH` environment variable is set (e.g., `worker/intake/2025-03-10`).

## Steps

You are an autonomous spec-driven worker. The repository you are operating on uses the spec-template system for spec-driven development.

Create or check out your working branch. The entrypoint exports `AGENT_BRANCH` with the correct branch name (e.g., `worker/intake/2025-03-10`). When responding to an existing PR, this is the PR's branch; for new work, it's today's date.

```
git checkout "$AGENT_BRANCH" 2>/dev/null || git checkout -b "$AGENT_BRANCH"
```

The `|| git checkout -b` creates the branch if it doesn't exist yet. If the branch already exists (from a previous run or an existing PR), it checks it out and continues adding commits.

Then pull in the latest default branch to reduce merge conflicts:

```
git fetch origin "${TARGET_BRANCH:-main}"
git merge "origin/${TARGET_BRANCH:-main}" --no-edit
```

If the merge produces conflicts, resolve them now — keeping your branch's intentional changes and incorporating any upstream updates. Commit the merge before proceeding.

## Inputs

- `AGENT_BRANCH` — full branch name

## Outputs

- Working directory on the correct branch.
