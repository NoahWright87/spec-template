# Branch Management

> Purpose: Set up the working branch for an agent run and handle merge conflicts
> Scope: Git operations only — branching, fetching, conflict resolution

## Set up your working branch

The fleet manager exports `AGENT_BRANCH` with the correct branch name (e.g., `worker/intake/2026-03-10`). When responding to an existing PR, this is the PR's branch; for new work, it's today's date.

Create or check out your working branch:

```bash
git fetch origin
git checkout "$AGENT_BRANCH" 2>/dev/null \
  || git checkout --track "origin/$AGENT_BRANCH" 2>/dev/null \
  || git checkout -b "$AGENT_BRANCH"
```

The fetch ensures remote branches are visible. The fallback order: check out an existing local branch, track the remote branch if it exists, create a new branch from HEAD. This correctly handles fresh clones where the PR branch exists only on the remote.

## Resolve merge conflicts

When `WORKER_PR_NUMBER` is set, check whether the PR can be merged cleanly:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
MERGEABLE=$(gh api "repos/$REPO/pulls/$WORKER_PR_NUMBER" --jq '.mergeable')
echo "PR #$WORKER_PR_NUMBER mergeable: $MERGEABLE"
```

If `MERGEABLE` is `false`:
1. Confirm you are on your agent branch (`$AGENT_BRANCH`)
2. Merge the target branch into your branch — use merge to preserve history for reviewers:
   ```bash
   git fetch origin
   git merge "origin/${TARGET_BRANCH:-main}" --no-edit
   ```
3. Resolve any conflicts. Keep your changes where they are correct; accept upstream changes where main has moved on. The goal is a clean merge commit — keep the PR diff focused on your work only.
4. Commit and push immediately so the PR is unblocked for reviewers.

Only after the PR is conflict-free should you continue to the next step.
