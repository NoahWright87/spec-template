# Post Summary

## Purpose

Output a brief summary to the console so operators can see what the agent did at a glance.

## Preconditions

- Agent has completed all assigned work steps (or determined there was nothing to do).

## Steps

**Output a brief summary to console (always):**
- What was done (PR responses, intake routing, TODOs implemented)
- What was skipped and why
- Any items now waiting for human input (with GitHub issue links)
- The PR URL (if work was done)
- **PR abandonment:** if `PR_ABANDONED=true` is set, report that the branch was abandoned due to zero net file changes relative to the target branch, and note the closed PR number if applicable
- **Errors:** if any step encountered errors (failed `gh` commands, merge conflicts that couldn't be auto-resolved, build failures, etc.), briefly explain what went wrong and what you did about it (or couldn't do)

This step runs regardless of whether work was done — even a "nothing to do" run should report that.

## Inputs

- Results from all preceding tasks in this agent run.

## Outputs

- Human-readable summary printed to stdout.
