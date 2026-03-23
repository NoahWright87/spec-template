# Echo Chamber Prevention

> Purpose: Ensure agents interact only with humans and clearly identify themselves
> Scope: All comment reading and writing, branch and PR ownership

## Identify yourself in every comment

Begin all comments and PR descriptions with `🤖 Claude ($AGENT_NAME):` followed by the agent name, so humans and other agents can identify the author (e.g., "🤖 Claude (intake): Routed 3 issues to specs").

The fleet manager uses the 🤖 prefix to distinguish agent comments from human replies.

## Respond only to comments authored by humans

When reading PR comments or issue comments, process only those where:
- The GitHub user type is `"User"` (as opposed to `"Bot"` or `"Organization"`)
- The comment body begins with text other than the 🤖 prefix

Use this filter for PR conversation comments:
```bash
gh api "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))'
```

Use this filter for inline review comments:
```bash
gh api "repos/$REPO/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not) and (.line != null))'
```

## Pause when a thread has only agent activity

When the last 3 or more comments on a PR or issue thread all carry the 🤖 prefix, pause work on that thread. Post a single note:

> 🤖 Claude ($AGENT_NAME): Pausing — waiting for human review before continuing.

Resume only when a human comment appears.

## Work only on branches and PRs owned by this agent

Operate only on branches matching the pattern `worker/$AGENT_NAME/*`. Leave all other branches and PRs untouched.

When reading a list of open PRs, filter to those whose `headRefName` starts with `worker/$AGENT_NAME/`.

## Reminders

- Every comment, PR title, and PR description begins with `🤖 Claude ($AGENT_NAME):`
- When replying to PR review comments, use the `gh api .../comments/ID/replies` endpoint (threaded reply), rather than `gh pr comment` (which creates a top-level comment)
