#!/usr/bin/env bash
# startup-intake.sh — gather data for the intake agent before Claude runs.
# Sourced by entrypoint.sh. Writes data files and sets _startup_context.

_startup_context=""

# ── Fetch intake-ready issues ────────────────────────────────────────────────
# Get issues labeled intake:ready, exclude those already filed/rejected/ignored.
_ready_issues=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --label "intake:ready" \
    --json number,title,url,labels,body \
    --limit 100 2>/dev/null || echo "[]")

_ready_issues=$(echo "$_ready_issues" | jq '[.[] | select(
    (.labels | map(.name) |
        (contains(["intake:filed"]) or contains(["intake:rejected"]) or contains(["intake:ignore"]))
    ) | not
)]')

# Sort bug issues to the top of the queue.
_ready_issues=$(echo "$_ready_issues" | jq 'sort_by(
    if ((.title | test("BUG|🪳"; "i")) or (.labels | map(.name) | any(. == "bug")))
    then 0 else 1 end
)')

_ready_count=$(echo "$_ready_issues" | jq 'length')
echo "[worker]   Startup: ${_ready_count} intake-ready issues"

# ── Limit to MAX_ITEMS_PER_RUN ──────────────────────────────────────────────
_limited=$(echo "$_ready_issues" | jq ".[0:${MAX_ITEMS_PER_RUN}]")
_limited_count=$(echo "$_limited" | jq 'length')
if [ "$_ready_count" -gt "$_limited_count" ]; then
    echo "[worker]   Startup: Limited to ${_limited_count} of ${_ready_count} issues (MAX_ITEMS_PER_RUN=${MAX_ITEMS_PER_RUN})"
fi

# ── Write data file ──────────────────────────────────────────────────────────
echo "$_limited" | jq '.' > /tmp/intake-ready-issues.json

# ── Build startup context for situation report ───────────────────────────────
_startup_context="### Intake-Ready Issues (${_limited_count})

Pre-filtered list of issues labeled \`intake:ready\` (excluding \`intake:filed\`, \`intake:rejected\`, \`intake:ignore\`).
The startup script has limited this to ${MAX_ITEMS_PER_RUN} issues (${_ready_count} total candidates).
**Read the file:** \`/tmp/intake-ready-issues.json\` — JSON array with fields: number, title, url, labels, body.

Process all issues in this file."
