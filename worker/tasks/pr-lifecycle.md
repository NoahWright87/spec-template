# PR Lifecycle

> Purpose: Handle existing PR comments and self-review before starting new work
> Scope: PR comment reading, responding, and self-review

## Step 0 — Review your open PR (do this first)

**When `WORKER_PR_NUMBER` is set**, you have an existing open PR that needs attention before any new work.

### Respond to PR review comments (inline code comments)

1. **Get the repository name:**
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   ```

2. **Read ALL review comments (inline code comments on Files Changed tab):**
   ```bash
   gh api "repos/$REPO/pulls/$WORKER_PR_NUMBER/comments" \
     --jq '.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not) and (.line != null)) |
     "ID: \(.id)\nUser: @\(.user.login)\nFile: \(.path)\nComment: \(.body)\n---"'
   ```

3. **For EACH review comment found, reply IN THE SAME THREAD:**

   Use the review comment reply API with the comment ID from step 2:
   ```bash
   gh api "repos/$REPO/pulls/$WORKER_PR_NUMBER/comments/COMMENT_ID/replies" \
     -X POST \
     -f body="🤖 Claude ($AGENT_NAME): [your response here]"
   ```

   If the API call fails, use `gh pr comment` as a fallback, but prefix your comment with a note that you were unable to reply in-thread.

### Respond to PR conversation comments

4. **Read main PR conversation comments:**
   ```bash
   gh pr view $WORKER_PR_NUMBER --comments
   ```
   For these, use `gh pr comment` to reply.

### Act on the comments

5. **Address each comment:**
   - Answer questions
   - Clarify decisions
   - When a comment says "worth noting" or "you should document this" — update the relevant spec file
   - Make any requested code changes

Address all comments before starting any new work. The worker ran because there are unresponded human comments — the goal is a PR that humans can review and hit merge with ease.

When `WORKER_PR_NUMBER` is not set, skip ahead to the agent-specific work.

## Self-review

Before requesting human review on any PR you create or update:

1. **Read the full diff** — look for logic errors, unreadable code, missing spec/CHANGELOG updates
2. **Batch all fixes into one commit** — each push re-triggers auto-reviewers, so minimize push count
3. **Leave explanatory PR comments** for changes that may confuse reviewers — explain WHY a change looks the way it does (prefix with `🤖 Claude ($AGENT_NAME):`)
4. **Respond to any auto-reviewer comments** — fix if valid, push back if inapplicable, reply explaining action taken

## Reminders

- Address all human comments before starting new work — this is the highest priority
- Batch self-review fixes into one commit before pushing
- When replying to review comments, use the `gh api .../comments/ID/replies` endpoint for threaded replies
