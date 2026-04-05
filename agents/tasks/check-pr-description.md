# Check PR Description

## Purpose

Verify the PR description is accurate and up to date before wrapping up. If it is stale or missing key sections, regenerate it from the current run's commits and diff.

## Preconditions

- `EXISTING_PR` is set and non-empty (a PR was created or found in `open-pr.md`).
- `AGENT_NAME` is set.

## Steps

### 1 — Fetch the current description

```bash
CURRENT_BODY=$(gh pr view "$EXISTING_PR" --json body --jq '.body // ""')
```

### 2 — Gather current-run context

```bash
TARGET_BRANCH="${TARGET_BRANCH:-main}"
COMMITS=$(git log "origin/$TARGET_BRANCH"..HEAD --oneline)
CHANGED_FILES=$(git diff "origin/$TARGET_BRANCH"...HEAD --name-only)
```

### 3 — Assess freshness

The description is **stale or missing** if any of these are true:

- It is empty or contains only the template placeholder text.
- **Issue references are inconsistent:** From `COMMITS`, extract all issue numbers mentioned in patterns like `(closes|fixes|resolves) #[0-9]+` (for example, using `grep -Eo '(closes|fixes|resolves) #[0-9]+'`). For each issue number `#N` found this way, `CURRENT_BODY` must contain either `#N` or a full `closes #N` / `fixes #N` / `resolves #N` line. If any such `#N` from `COMMITS` is missing from `CURRENT_BODY`, the description is stale.
- **Changed files are not represented:** Take `CHANGED_FILES` and derive the distinct top-level paths with `cut -d/ -f1 | sort -u`. For each of these paths (e.g., `src`, `tests`, `docs`, `scripts`, or a single file at the repo root), there must be at least one bullet in the **"Files changed"** section of the PR body that either mentions that path directly or groups it under a clearly labeled category bullet (e.g., `- Tests` for anything under `tests/` or `- Documentation` for anything under `docs/`). If any top-level path is neither mentioned directly nor covered by a category bullet, the description is stale.
- **Commits are not covered by "What I did":** For each non-merge commit in `COMMITS`, its subject line must be represented by at least one bullet in the **"What I did"** section — either by including the full subject, or by a bullet that clearly summarizes a group of commits sharing a common prefix or topic. If any commit subject is not obviously covered, the description is stale.

If the description passes all of the checks above and looks accurate and complete, **skip step 4** — do not update a good description for its own sake.

### 4 — Regenerate and update (only if stale)

Write an updated description using this format:

```
🤖 Claude ($AGENT_NAME): [one-sentence summary of what this PR does]

## What I did
- [bullet per logical change, referencing issue numbers where applicable]

## Files changed
- [key files touched, grouped by purpose if helpful]

[closes #N lines for any GH-linked issues fully implemented in this PR]
```

Then push the update:

```bash
gh pr edit "$EXISTING_PR" --body "$UPDATED_BODY"
```

## Inputs

- `EXISTING_PR` — PR number from `open-pr.md`
- `AGENT_NAME` — agent display name
- `TARGET_BRANCH` — base branch (default: `main`)
- `RUN_DATE` — today's date in `YYYY-MM-DD` format

## Outputs

- PR description is accurate and reflects the current run's changes.
