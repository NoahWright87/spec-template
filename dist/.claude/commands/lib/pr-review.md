<!-- AUTO-GENERATED — do not edit directly.
     Source: .claude/commands/lib/pr-review.md
     Regenerate: run scripts/generate-dist.sh from the repo root. -->

# PR Review

PR review expectations. Follow these any time you open or update a PR — whether arriving here from `/what-now` or routed here automatically by another command that just created one.

---

## PR Description

A good PR description guides reviewers and helps them feel confident approving. Before reviewing the diff, make sure the description is in good shape:

- **Keep it high-level** — focus on *what* changed and *why*, not implementation details. Reviewers care about what the software does, not how it does it.
- **Include screenshots** for any new or changed UI. Link or embed them directly in the description.
- **Keep it in sync** — as you respond to comments and make changes, re-read the description and update it if the PR has drifted from what it says.

---

## Step 1 — Self-review

First, check for merge conflicts:

```
gh pr view <number> --json mergeable -q .mergeable
```

If conflicts exist, resolve them before reviewing the diff:
```
git merge origin/<base-branch>
# resolve conflicts, keeping only this PR's intended changes
git add <files>
git commit -m "merge: sync with <base-branch>"
git push
```

Merging (rather than rebasing) keeps the commit history readable and avoids surfacing other branches' changes in this PR's diff.

Then read the full diff:

```
gh pr diff
```

Review it as you would a stranger's PR. Look for:
- Logic errors, edge cases, or missing error handling
- Code that is harder to read than it needs to be
- Missing or wrong spec/CHANGELOG updates
- `CHANGELOG.md` has a version number for this PR's work (not just `## WIP`)
- Anything that would make a reviewer pause or ask a question

**Collect all issues before fixing any.** Do not context-switch into fixing the first problem you find — finish the full review, write down every issue, then fix them all together in Step 2.

---

## Step 2 — Batch-fix and commit

Fix everything found in Step 1 in a single pass. Then commit and push as **one commit**.

Reason: each push re-triggers auto-reviewers like Copilot. Batching prevents a flood of redundant review runs.

```
git add <files>
git commit -m "self-review fixes: <brief summary>"
git push
```

If there is nothing to fix, skip this step.

---

## Step 3 — Leave explanatory PR comments

Walk through the diff again. For changes that may confuse a reviewer, add a comment to explain. The goal is context about **the change**, not documentation about the code.

**When a PR comment makes sense:**
- A large block of code "changed" but the only change was moving or renaming — explain that no logic changed
- Code was deleted — explain why it was safe to delete (last consumer gone, endpoint deprecated, etc.)
- A non-obvious fix — explain what was broken, why, and how the new code avoids it
- A decision was made during this PR that isn't captured anywhere else (e.g., "went with approach A over B because…")
- The change requires context about something external (traffic spike, deprecation schedule, upstream change)

**When a code comment makes sense instead:**
- The context will still matter to someone reading the code 6 months from now in isolation
- A business rule, API quirk, or non-obvious constraint future maintainers will trip over

**When no comment is needed:**
- The PR description already covers it
- The change is self-evident from the diff

**Placement:**
- File-level comment: use when the explanation applies to the whole file's change (e.g., file moved, file deleted)
- Line-level comment: use when the explanation is about a specific hunk
- PR-level comment: use for overall context that doesn't map to any single file

Post comments using:
```
# PR-level comment
gh pr comment <number> --body "🤖 ..."

# File/line-level review comment (inline on the diff)
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --method POST \
  -f commit_id="$(gh pr view <number> --json headRefOid -q .headRefOid)" \
  -f path="<file>" \
  -f line=<line> \
  -f side="RIGHT" \
  -f body="🤖 ..."
```

All comments must start with **🤖**. Default to: `🤖 Claude, self-reviewing:`

---

## Step 4 — Respond to auto-review comments (Copilot, bots)

Fetch all open review threads:

```
gh pr view <number> --json reviewThreads
```

For each unresolved thread from a bot reviewer:

1. **If the comment is valid:** Fix the issue (batch with any other pending fixes — see Step 2 note), then reply explaining what was done.
2. **If the comment is not applicable:** Reply explaining why (politely push back with reasoning).
3. After replying, resolve the thread.

Never leave a bot comment unacknowledged.

---

## Step 5 — Respond to human review comments

Same process as Step 4. For each unresolved human comment:

1. **Agree and fix:** Make the change, reply confirming what was done.
2. **Disagree:** Reply with your reasoning. Be direct but not defensive. If it is a matter of taste and the reviewer feels strongly, defer to their preference and say so.
3. **Need clarification:** Ask a follow-up question in a reply.

After responding to all comments, if you made additional fixes: commit and push them as a single batch (same reason as Step 2 — avoid re-triggering auto-review per push).

---

## Reminders

- **ALL comments you post must start with 🤖** — this identifies automated comments to human reviewers and lets you find your own comments easily
- If another command gave you a persona (e.g., "🤖 Spec Agent"), use that persona here too
- **Batch all code fixes into one commit before pushing** — never push fix-by-fix
- **Respond to every comment** — unacknowledged comments signal you ignored the feedback
- Resolve a thread only after your response is posted — not before
- In headless mode, if a human comment requires a judgment call you cannot make: post a 🤖 question to the PR thread and leave it open
