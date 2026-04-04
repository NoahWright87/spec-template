# Refine Issues

## Purpose

Assess open GitHub issues for clarity and completeness. Issues that are clear enough to route get labeled `intake:ready`. Issues that need more information get a clarifying comment. This workflow does NOT modify repository files — all work happens via GitHub API (comments and labels).

## Preconditions

- `gh` CLI is authenticated and available.
- The startup script has written candidate issues to `/tmp/refine-candidate-issues.json`.

## Steps

### Step 1 — Read candidate issues

Read `/tmp/refine-candidate-issues.json`. The startup script has already:
- Fetched open issues that are candidates for refinement: issues with no `intake:*` label at all, **plus** issues labeled `intake:filed` without `intake:ready` (filed before the refinement agent existed).
- Filtered out self-talk issues (where the last comment is from an agent with no human reply since).
- Limited the list to the configured number of issues per run.

Each entry contains: `number`, `title`, `url`, `labels`, `body`, and `comments`.

**Note on `intake:filed` issues:** Issues that already have `intake:filed` but lack `intake:ready` were filed into the backlog before the refinement agent existed. Treat them exactly like unlabeled issues — run the same assessment, then swap the label:
```bash
gh issue edit NUMBER --remove-label "intake:filed" --add-label "intake:ready"
```
After swapping, post a comment noting the issue was previously filed without a refinement pass:
```bash
gh issue comment NUMBER --body "🤖 Claude ($AGENT_NAME): This issue was previously filed without a refinement pass. I've now assessed it and labeled it \`intake:ready\`."
```

### Step 2 — Assess each candidate

For each candidate, assess clarity — can this issue be routed to a spec file? Consider:
- Is the **what** clear? (What needs to happen)
- Is the **why** clear? (Why it matters)
- Is the **how** clear? (What approach or solution is agreed upon)
- Is there enough context to determine the target component/spec?
- Could a developer start implementation without further clarification?

If the issue describes a problem but leaves the solution approach open or ambiguous, post clarifying questions and **do not** label it `intake:ready` — wait for human direction on the approach first. Only label `intake:ready` once the what, why, and how are all agreed on.

If the issue has prior comments (a back-and-forth conversation), read the full conversation to understand context before deciding.

**Decide and act:**

**Only label `intake:ready` when the issue is clear and actionable.** When doing so:

First, ensure the size/confidence labels exist in the repo (idempotent — safe to run on every assessment):
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh label create "size:XS(2)"      --repo "$REPO" --color "0075ca" --description "Effort: XS = 2 points" --force
gh label create "size:S(3)"       --repo "$REPO" --color "0075ca" --description "Effort: S = 3 points" --force
gh label create "size:M(5)"       --repo "$REPO" --color "0075ca" --description "Effort: M = 5 points" --force
gh label create "size:L(8)"       --repo "$REPO" --color "0075ca" --description "Effort: L = 8 points" --force
gh label create "size:XL(13)"     --repo "$REPO" --color "0075ca" --description "Effort: XL = 13 points" --force
gh label create "confidence:high" --repo "$REPO" --color "2ea44f" --description "High confidence in size estimate" --force
gh label create "confidence:med"  --repo "$REPO" --color "e4a60a" --description "Medium confidence in size estimate" --force
gh label create "confidence:low"  --repo "$REPO" --color "d93f0b" --description "Low confidence in size estimate" --force
```

Then remove any stale size/confidence labels (ensures exactly one of each):
```bash
gh issue view NUMBER --json labels -q '.labels[].name | select(startswith("size:") or startswith("confidence:"))' |
  while IFS= read -r lbl; do
    gh issue edit NUMBER --remove-label "$lbl"
  done
```

Apply size and confidence labels based on your assessment (replace the values as appropriate):
- Size mapping: `XS` → `size:XS(2)`, `S` → `size:S(3)`, `M` → `size:M(5)`, `L` → `size:L(8)`, `XL` → `size:XL(13)`
- Confidence mapping: 0 `?` prefixes → `confidence:high`, 1 `?` → `confidence:med`, 2+ `?` → `confidence:low`
```bash
gh issue edit NUMBER --add-label "size:M(5)" --add-label "confidence:high"
# (replace label names based on your size and confidence assessment)
```

Then apply the `intake:ready` label:
```bash
gh issue edit NUMBER --add-label "intake:ready"
```
Post a brief confirmation comment:
```bash
gh issue comment NUMBER --body "🤖 Claude ($AGENT_NAME): This issue is clear and ready for intake routing. Labeled \`intake:ready\`."
```
Then **append** a refinement assessment section to the issue description (leave the original description intact). If a `🤖 Refinement Assessment` section already exists, update it in place instead of appending a duplicate. Use the [sizing guide](../references/sizing-guide.md) to estimate effort:
```bash
# Read existing body first, then append:
gh issue edit NUMBER --body "$EXISTING_BODY

---
## 🤖 Refinement Assessment
**Size estimate:** ?M
**Remaining questions:** (none)
"
```
Use t-shirt sizes from the [sizing guide](../references/sizing-guide.md): XS, S, M, L, XL. Prefix `?` for uncertain estimates (e.g., `?M`, `??L`). The `?` count maps to the confidence label: no `?` → `confidence:high`, one `?` → `confidence:med`, two or more `?` → `confidence:low`.

**Only post clarifying questions when the issue genuinely lacks information.** Post a comment with 1-3 specific questions:
```
🤖 Claude ($AGENT_NAME): To route this issue, I need a bit more information:

1. [Specific question about scope/target/intent]
2. [Specific question if needed]

Reply here and I'll reassess on the next run.
```
Do NOT add any label — the issue stays unlabeled until it's ready.

### Step 3 — Summary

Summarize what was done for the run log:
- Issues labeled `intake:ready` (with links).
- Issues where clarifying questions were posted (with links).
- Issues skipped (already waiting for human reply).

This summary goes into the agent's post-summary output. Issue refinement does not produce a PR.

## Safety reminder

> **🛑 NEVER post two 🤖 comments in a row on the same issue — this causes self-talk loops. The startup script filters these out, but always double-check before posting: verify the last comment is NOT from 🤖. ⚠️**

## Preferred tools

- **Bash** — `gh` CLI calls only (issue edit, issue comment, API calls)
- **Read** — read `/tmp/refine-candidate-issues.json` and issue details

## Inputs

- `/tmp/refine-candidate-issues.json` — pre-filtered candidate issues from the startup script.
- [agents/references/sizing-guide.md](../references/sizing-guide.md) — t-shirt sizing reference for effort estimates.

## Outputs

- Issues labeled `intake:ready` with refinement assessment appended to description (clear and ready to route).
- Clarifying comments posted on unclear issues.
- Summary for the run log (no PR needed for issue-only work).
