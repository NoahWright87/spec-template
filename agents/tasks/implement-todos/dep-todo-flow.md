# Dep TODO Flow

## Purpose

Handle TODO items that live in `specs/deps/` — these represent work that needs to happen in a **downstream** repository, not in this one. "Implementing" a dep TODO means managing the cross-repo lifecycle, not writing product code.

## Preconditions

- A chosen TODO item lives in `specs/deps/{repo}.todo.md`.

## Full Lifecycle

A dep TODO goes through these stages across multiple agent runs:

1. **Open downstream issue** (this run, if no sub-bullet exists yet)
2. On subsequent runs, **check sub-bullet status** — is the downstream issue still open?
3. When the downstream repo closes its issue, check `stateReason`:
   - `stateReason == "completed"` → item is **unblocked** — proceed to step 4.
   - `stateReason == "not_planned"` → downstream work was intentionally abandoned. Post a comment on the upstream issue explaining the situation; leave the upstream TODO open so a human can decide what to do next. Do not promote to spec.
   - `stateReason == "duplicate"` → treat as still blocked (work exists elsewhere but not yet verified complete). Keep the sub-bullet in place; skip on next run.
   - `stateReason == null` or unknown → treat as still blocked. Keep the sub-bullet in place; skip.
4. If the unblocked work requires local changes → **implement or validate locally**
5. When local work is done → **close the original issue** (if GH-linked)

The key insight: opening a downstream issue is NOT enough to call it done. The item stays open in your TODO file until the full chain completes — downstream issue closed with `stateReason == "completed"`, any local follow-up done, original issue closeable.

### Example: multi-hop dependency chain

1. User requests a feature, opening Issue #10 in the team repo.
2. Team repo agent puts it in `specs/deps/frontend-repo.todo.md`, opens Issue #20 in frontend-repo.
3. Frontend-repo agent pulls Issue #20, realizes it needs backend work, opens Issue #30 in backend-repo.
4. Backend change is implemented, Issue #30 closes.
5. Frontend-repo agent sees backend work is done, implements frontend changes, closes Issue #20.
6. Team repo agent sees Issue #20 is closed, closes the user's original Issue #10.

The user sees the work was done and doesn't know (or care) that it took a few hops behind the scenes.

## Steps (for a new dep TODO with no sub-bullets)

### 1. Draft the downstream issue

Write the title and body so the target repo has enough context to act on it independently — don't assume they know this repo's internals.

The issue title **must start with** `🤖` and the body **must start with** `🤖 Claude ($AGENT_NAME):` so it is clearly identified as bot-created.

Example body opening:
```
🤖 Claude ($AGENT_NAME): This issue was opened on behalf of {this-repo}#{local-N}. <description of the work needed>
```

### 2. Open the issue

```bash
gh issue create --repo {owner}/{repo} --title "🤖 ..." --body "🤖 Claude ($AGENT_NAME): ..."
```

### 3. Add a sub-bullet

```
- [#local](url) Description
  - [{repo}#{N}]({url}) Downstream issue opened
```

### 4. Cross-link for traceability

```bash
# On the local issue
gh issue comment {local-N} --body "🤖 Claude ($AGENT_NAME): Downstream issue opened in {repo}: [{repo}#{N}]({url})"

# On the downstream issue
gh issue comment {dep-N} --repo {owner}/{repo} --body "🤖 Claude ($AGENT_NAME): Opened on behalf of [{this-repo}#{local-N}]({url})"
```

### 5. Leave the item open

The TODO item stays in place — it stays open until the downstream issue is closed. Sub-bullet reconciliation will unblock it on the next run. Remove sub-bullets only when promoting a completed item to `spec.md`.

## Inputs

- A dep TODO item from `specs/deps/{repo}.todo.md`
- Target repo for the downstream issue

## Outputs

- Downstream GitHub issue opened.
- Local TODO item annotated with sub-bullet linking to downstream issue.
- Cross-link comments on both issues.
