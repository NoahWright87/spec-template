# Open PR

## Purpose

Push the agent's branch and create or update the pull request after all work is complete.

## Preconditions

- Agent has completed all assigned work steps.
- Agent is on `$AGENT_BRANCH`.

## Steps

1. **Determine if actual work was done:**
   - Did you respond to PR comments?
   - Did you route any issues (intake)?
   - Did you implement any TODOs?
   - Did you make any commits?

2. **If NO work was done** (no comments to respond to, no issues to route, no TODOs implemented), skip this task — go directly to **post-summary**.

3. **Check for zero net file changes (abandonment check):**

   After confirming work was done (commits exist), verify the branch has actual file changes relative to the target branch:
   ```bash
   BASE_BRANCH=${TARGET_BRANCH:-main}
   MERGE_BASE=$(git merge-base HEAD "origin/$BASE_BRANCH")
   COMMITS_AHEAD=$(git rev-list "$MERGE_BASE..HEAD" --count)
   CHANGED_FILES=$(git diff "$MERGE_BASE" HEAD --name-only)
   ```
   - If `COMMITS_AHEAD` is **zero**: no commits ahead of base — the agent did GitHub-only work (labels, comments) with no local commits; this check does not apply, continue to the next step.
   - If `COMMITS_AHEAD` is **non-zero** but `CHANGED_FILES` is **empty** (zero net file changes):
     - Check if an open PR exists and close it with an explanatory comment:
       ```bash
       EXISTING_PR=$(gh pr list --head "$AGENT_BRANCH" --state open --json number --jq '.[0].number // empty')
       if [ -n "$EXISTING_PR" ]; then
         gh pr comment "$EXISTING_PR" --body "🤖 Claude ($AGENT_NAME): Closing this PR — no net file changes detected relative to $BASE_BRANCH (merge base: $MERGE_BASE). This typically happens when a merge conflict was resolved by accepting the target branch's version of the changed content. No work remains to merge."
         gh pr close "$EXISTING_PR"
         echo "[open-pr] Closed empty PR #$EXISTING_PR (zero file changes vs. $BASE_BRANCH)"
       fi
       ```
     - Log the abandonment: `echo "[open-pr] Abandoned: zero file changes vs. $BASE_BRANCH — skipping push/PR creation"`
     - Export: `export PR_ABANDONED=true`
     - Skip the rest of this task and go directly to **post-summary**.
   - If `COMMITS_AHEAD` is **non-zero** and `CHANGED_FILES` is **non-empty**, continue to the next step.

4. **If work WAS done:**
   - Push your branch: `git push origin "$AGENT_BRANCH"`
   - Check whether a PR already exists for this branch:
     ```
     EXISTING_PR=$(gh pr list --head "$AGENT_BRANCH" --state open --json number --jq '.[0].number // empty')
     ```
     - If a PR exists (`EXISTING_PR` is non-empty): your new commits are already part of the PR. Use `EXISTING_PR` for subsequent commands.
     - If no PR exists: Create one targeting the default branch and capture the number:
       ```bash
       gh pr create --head "$AGENT_BRANCH" \
         --title "🤖 Claude ($AGENT_NAME): Work from ${RUN_DATE:-$(date -u +%Y-%m-%d)}" \
         --body "🤖 Claude ($AGENT_NAME): [brief description of work done]"
       EXISTING_PR=$(gh pr list --head "$AGENT_BRANCH" --state open --json number --jq '.[0].number // empty')
       ```
   - **Enable auto-merge** so the PR merges as soon as required checks pass — skip only if `$QUESTIONS_OPEN` is set (meaning you posted a clarifying question and need human input before merging):
     ```bash
     if [ -z "$QUESTIONS_OPEN" ] && [ -n "$EXISTING_PR" ]; then
       _merge_out=$(gh pr merge "$EXISTING_PR" --auto --squash 2>&1); _merge_rc=$?
       if [ "$_merge_rc" -ne 0 ]; then
         # Treat known ineligible cases as soft failures (log and skip),
         # but fail the task for unexpected errors so they get surfaced.
         if echo "$_merge_out" | grep -qiE 'auto[- ]merge.*(disabled|not enabled)|not mergeable|merge method .*not allowed'; then
           echo "[open-pr] auto-merge skipped (ineligible): $_merge_out"
         else
           echo "[open-pr] auto-merge failed unexpectedly: $_merge_out" >&2
           exit "$_merge_rc"
         fi
       fi
     fi
     ```
     Agents that post a clarifying question (e.g., a ⏳ comment on an issue) should `export QUESTIONS_OPEN=true` at that point so this step is skipped.
   - **Check that the PR description is accurate** — read and follow [tasks/check-pr-description.md](check-pr-description.md) now that `EXISTING_PR` is set.
   - **Post a summary comment to the PR:**
     ```bash
     gh pr comment "$EXISTING_PR" --body "🤖 Claude ($AGENT_NAME): [summary of work done]"
     ```

## Reminders

- **All comments and PR descriptions must begin with `🤖 Claude ($AGENT_NAME):`** — include the agent name so humans know which agent is speaking.
- When creating a new PR, start the description with `🤖 Claude ($AGENT_NAME):` followed by a brief statement of the agent's purpose.
- **Issue closing keywords (`closes #N`, `fixes #N`) are only for PRs that directly implement the work tracked by the issue.** For routing or intake-only PRs — where the PR files an item into a TODO list but does not implement it — use `Refs #N` instead. Using `closes #N` in a routing PR will prematurely close the issue before the work is done.

## Inputs

- `AGENT_BRANCH` — the branch to push
- `AGENT_NAME` — the agent's display name for comments
- `QUESTIONS_OPEN` — (optional) if set, skip auto-merge (agent has an open question for a human)

## Outputs

- Branch is pushed to remote.
- PR exists (created or already existed) with a summary comment.
- `PR_ABANDONED=true` — exported if the branch had zero net file changes and no PR was created/updated.
