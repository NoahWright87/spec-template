# Respond to PR Comments

## Purpose

Address all non-agent comments on the agent's open PR before doing any new work. This is the highest priority when an open PR exists.

## Preconditions

- The **Situation Report** at the top of your prompt includes review comments, conversation comments, or both.
- `WORKER_PR_NUMBER` environment variable is set.

## How comments are provided

The Situation Report tells you how many comments exist and where to find them. Comments are stored in JSON files on disk — **read them using the Read tool** rather than re-fetching from the GitHub API. Agent comments (those starting with 🤖) have been filtered out before the files were written, so everything in the JSON needs a response.

**🤖 Self-talk prevention:** Your own comments start with 🤖. The JSON files contain ONLY comments from others — everything in them needs a response. If you somehow see a comment starting with 🤖, you wrote it — **DO NOT respond to it**.

There are two types of comments:

### Review comments (inline on Files Changed)

**Read the file** at `/tmp/pr-review-comments.json` — JSON array with fields:
- `id` — the comment ID (use this for threaded replies)
- `user` — who wrote the comment
- `path` — which file the comment is on
- `line` — which line number
- `body` — the comment text
- `in_reply_to_id` — if non-null, this comment is part of a thread (the parent comment's ID)

**Reply to each review comment IN THE SAME THREAD:**

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# Replace COMMENT_ID with the actual id from the JSON
gh api "repos/$REPO/pulls/$WORKER_PR_NUMBER/comments/COMMENT_ID/replies" \
  -X POST \
  -f body="🤖 Claude ($AGENT_NAME): [your response here]"
```

**CRITICAL:** Use the `/comments/ID/replies` endpoint above. Do NOT use `gh pr comment` for review comments — that creates a top-level comment instead of a threaded reply.

### Conversation comments (top-level PR discussion)

**Read the file** at `/tmp/pr-conversation-comments.json` — JSON array with fields:
- `id` — the comment ID
- `user` — who wrote the comment
- `body` — the comment text

**Reply to conversation comments** using:
```bash
gh pr comment $WORKER_PR_NUMBER --body "🤖 Claude ($AGENT_NAME): [your response here]"
```

## How to act on comments

For each comment, do what's appropriate:
- **Answer questions** — provide clear, concise answers
- **Clarify decisions** — explain why you made a particular choice
- **Make requested code changes** — if someone asks you to change something, do it and commit
- **Update specs** — if a comment says "worth noting" or "you should document this", update the relevant spec file
- **Acknowledge feedback** — even if no action is needed, acknowledge that you've read it

## Inputs

- Situation Report (at the top of your prompt) — tells you where to find the comment JSON files
- `/tmp/pr-review-comments.json` — inline review comments (if any)
- `/tmp/pr-conversation-comments.json` — top-level conversation comments (if any)
- `WORKER_PR_NUMBER` — the PR number
- `AGENT_NAME` — your agent name (used in the 🤖 prefix)

## Reminders

- 🤖 **Always prefix your replies with `🤖 Claude ($AGENT_NAME):`** — this is how the system identifies your comments and filters them out on the next run.
- 🤖 **If a comment starts with 🤖, you wrote it — DO NOT respond to it.** Only respond to comments from humans and non-agent bots.
- After making code changes requested by a reviewer, mention what you changed in your reply so they can verify.

## Updating Copilot PR instructions

When a human reviewer overrides a Copilot suggestion and you update the code to match the human's preference, consider whether the preference is a reusable standing rule:

- **General rule (add it):** The preference applies broadly — e.g., "always use X" or "prefer Y over Z". Append a positive instruction to `.github/copilot-instructions.md` in the target repo (create the file if absent). Keep instructions positive: state what Copilot *should* do, not a laundry list of things to avoid.
- **Context-specific (skip it):** The override was a one-off decision tied to this PR's specific circumstances. Do not update the instructions file.

If you update `.github/copilot-instructions.md`, include it in the same commit as any other code changes from this comment-response pass.

## Outputs

- All review comments have threaded replies.
- All conversation comments have responses.
- Any requested code changes are committed.
- `.github/copilot-instructions.md` updated when a human-vs-Copilot override reveals a reusable rule.
