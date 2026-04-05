#!/usr/bin/env bash
# startup-refine.sh — gather data for the refine agent before Claude runs.
# Sourced by entrypoint.sh. Writes data files and sets _startup_context.
#
# Self-talk prevention is structural: this script filters out issues where the
# last comment is from our agent (🤖 prefix), so Claude never sees them.

_startup_context=""

# ── Fetch candidate issues for refinement ────────────────────────────────────
# Get all open issues. Candidates are:
#   1. Issues with no intake:* label at all (never seen by intake pipeline), OR
#   2. Issues with intake:filed but NOT intake:ready (filed before refinement existed)
_all_issues=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,title,url,labels,body \
    --limit 100 2>/dev/null || echo "[]")

_candidates=$(echo "$_all_issues" | jq '[.[] | select(
    ((.labels | map(.name) | any(startswith("intake:")) ) | not)
    or
    (
        (.labels | map(.name) | any(. == "intake:filed"))
        and
        ((.labels | map(.name) | any(. == "intake:ready")) | not)
    )
)]')

_candidate_count=$(echo "$_candidates" | jq 'length')
debug "startup-refine: ${_candidate_count} candidate issues (no intake:* label or intake:filed without intake:ready)"

# ── Apply self-talk filter ───────────────────────────────────────────────────
# For each candidate, check the last comment. Only include issues where:
#   - There are no comments (new issue), OR
#   - The last comment is NOT from our agent (human replied or different commenter)
# This is the structural self-talk prevention — Claude only sees issues it should act on.
_filtered="[]"
for _num in $(echo "$_candidates" | jq -r '.[].number'); do
    _comments_json=$(gh api --paginate "repos/$TARGET_REPO/issues/$_num/comments" \
        2>/dev/null | jq -s 'add // [] | [.[] | {user: .user.login, body: .body, created_at: .created_at}]' \
        || echo "[]")
    _comment_count=$(echo "$_comments_json" | jq 'length')

    if [ "$_comment_count" -eq 0 ]; then
        # New issue, no comments — include it
        _issue=$(echo "$_candidates" | jq ".[] | select(.number == $_num) | . + {comments: []}")
        _filtered=$(echo "$_filtered" | jq ". + [$_issue]")
        debug "startup-refine: issue #$_num — no comments, including"
    else
        _last_body=$(echo "$_comments_json" | jq -r 'last | .body')
        _is_agent=$(echo "$_last_body" | grep -q '^[[:space:]]*🤖' && echo "true" || echo "false")

        if [ "$_is_agent" = "false" ]; then
            # Last comment is from a human — include (may be a reply to our question)
            _issue=$(echo "$_candidates" | jq ".[] | select(.number == $_num) | . + {comments: $_comments_json}")
            _filtered=$(echo "$_filtered" | jq ". + [$_issue]")
            debug "startup-refine: issue #$_num — human replied, including for reassessment"
        else
            debug "startup-refine: issue #$_num — last comment is 🤖 agent, skipping (self-talk prevention)"
        fi
    fi
done

# Sort bug issues to the top of the queue.
_filtered=$(echo "$_filtered" | jq 'sort_by(
    if ((.title | test("BUG|🪳"; "i")) or (.labels | map(.name) | any(. == "bug")))
    then 0 else 1 end
)')

_filtered_count=$(echo "$_filtered" | jq 'length')
echo "[worker]   Startup: ${_filtered_count} candidate issues for refinement (filtered from ${_candidate_count})"

# ── Limit to MAX_ISSUES_PER_RUN ──────────────────────────────────────────────
# Only pass the agent exactly the number of issues it should process.
_limited=$(echo "$_filtered" | jq ".[0:${MAX_ISSUES_PER_RUN}]")
_limited_count=$(echo "$_limited" | jq 'length')
if [ "$_filtered_count" -gt "$_limited_count" ]; then
    echo "[worker]   Startup: Limited to ${_limited_count} of ${_filtered_count} candidates (MAX_ISSUES_PER_RUN=${MAX_ISSUES_PER_RUN})"
fi

# ── Write data file ──────────────────────────────────────────────────────────
echo "$_limited" | jq '.' > /tmp/refine-candidate-issues.json

# ── Build startup context for situation report ───────────────────────────────
_startup_context="### Candidate Issues for Refinement (${_limited_count})

Pre-filtered list of open issues that need refinement — either no \`intake:*\` label at all,
or labeled \`intake:filed\` without \`intake:ready\` (filed before refinement existed).
Issues where the last comment is from our agent (🤖) have been excluded.
The startup script has already limited this to ${MAX_ISSUES_PER_RUN} issues (${_filtered_count} total candidates).
**Read the file:** \`/tmp/refine-candidate-issues.json\` — JSON array with fields: number, title, url, labels, body, comments.

Process all issues in this file."

# ── Also note unrefined TODOs ────────────────────────────────────────────────
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")
_unrefined_files=$(find "$WORKSPACE/$_specs_dir" -name "*.todo.md" -print0 2>/dev/null | xargs -0 grep -l '^- ❓' 2>/dev/null || true)
_unrefined_count=$(echo "$_unrefined_files" | grep -c . 2>/dev/null || echo "0")

if [ "${_unrefined_count:-0}" -gt 0 ]; then
    _startup_context="${_startup_context}

### Unrefined TODOs (${_unrefined_count} files)

Files containing ❓ items that may need refinement:
$(echo "$_unrefined_files" | sed 's|^.*/workspace/||' | sed 's/^/- /')"
fi
