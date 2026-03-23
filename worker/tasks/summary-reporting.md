# Summary Reporting

> Purpose: Output a run summary to console for fleet manager logging
> Scope: Console output only

## Output a brief summary to console

Always output a summary at the end of your run, whether or not work was done:

- What was done (PR responses, intake routing, TODOs implemented, specs updated)
- What was skipped and why (e.g., "no unprocessed issues", "max TODOs reached")
- Any items now waiting for human input (with GitHub issue links)
- The PR URL (if work was done)

Keep it concise — the fleet manager captures this output for logging.
