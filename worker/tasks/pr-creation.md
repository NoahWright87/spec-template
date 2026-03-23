# PR Creation

> Purpose: Create or update a pull request for the agent's work
> Scope: PR creation, PR updates, summary comments

## Create or update your PR

After pushing, check whether a PR already exists for this branch:

```bash
EXISTING_PR=$(gh pr list --head "$AGENT_BRANCH" --state open --json number --jq '.[0].number')
```

- **If a PR exists** (`EXISTING_PR` is non-empty): your new commits are already part of the PR. Use the existing PR number.

- **If no PR exists**: Create one targeting the default branch:
  ```bash
  PR_URL=$(gh pr create \
    --title "🤖 Claude ($AGENT_NAME): [brief title]" \
    --body "🤖 Claude ($AGENT_NAME): [description of work done]" \
    --base "${TARGET_BRANCH:-main}")
  EXISTING_PR=$(echo "$PR_URL" | grep -oE '[0-9]+$')
  ```

## Post a summary comment

Post a summary comment to the PR describing what was done:

```bash
gh pr comment "$EXISTING_PR" --body "🤖 Claude ($AGENT_NAME): [summary of work done in this run]"
```

## Reminders

- All PR titles and descriptions begin with `🤖 Claude ($AGENT_NAME):`
- Include `closes #N` in the PR body when work resolves a GitHub issue
