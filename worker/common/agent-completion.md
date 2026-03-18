# Agent Completion

After completing all assigned steps:

1. **Determine if actual work was done:**
   - Did you respond to PR comments?
   - Did you route any issues (intake)?
   - Did you implement any TODOs?
   - Did you make any commits?

2. **If NO work was done** (no comments to respond to, no issues to route, no TODOs implemented), skip ahead to step 4.

3. **If work WAS done:**
   - Push your branch: `git push origin "$AGENT_BRANCH"`
   - Check whether a PR already exists for this branch:
     ```
     EXISTING_PR=$(gh pr list --head "$AGENT_BRANCH" --state open --json number --jq '.[0].number')
     ```
     - If a PR exists (`EXISTING_PR` is non-empty): your new commits are already part of the PR
     - If no PR exists: Create one targeting the default branch
   - **Post a summary comment to the PR:**
     ```bash
     gh pr comment ${EXISTING_PR:-$NEW_PR_NUMBER} --body "🤖 Claude ($AGENT_NAME): [summary of work done]"
     ```

4. **Output a brief summary to console (always):**
   - What was done (PR responses, intake routing, TODOs implemented)
   - What was skipped and why
   - Any items now waiting for human input (with GitHub issue links)
   - The PR URL (if work was done)

## Reminders

- **All comments and PR descriptions must begin with `🤖 Claude ($AGENT_NAME):`** — include the agent name so humans know which agent is speaking.
- When creating a new PR, start the description with `🤖 Claude ($AGENT_NAME):` followed by a brief statement of the agent's purpose.
