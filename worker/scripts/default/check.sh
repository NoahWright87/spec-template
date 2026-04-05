#!/usr/bin/env bash
# check-default.sh — fallback check for unknown/custom agents.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.
#
# Uses the union of all signals: if ANY signal fires, the unknown agent runs.
# This is a safe default — the agent itself decides what to do with the work.

_check_result=0
_check_reason=""

# Check for unrefined issues
_unprocessed=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,labels \
    --jq '[.[] | select(
        (.labels | map(.name) | any(startswith("intake:")) ) | not
    )] | length' 2>/dev/null || echo "0")

if [ "${_unprocessed:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_unprocessed} unprocessed issue(s)"
    return 0 2>/dev/null || true
fi

# Check for intake-ready issues
_ready=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --label "intake:ready" \
    --json number \
    --jq 'length' 2>/dev/null || echo "0")

if [ "${_ready:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_ready} intake-ready issue(s)"
    return 0 2>/dev/null || true
fi

# Check for refined TODOs
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")
_refined=$(find "$WORKSPACE/$_specs_dir" -name "*.todo.md" -print0 2>/dev/null | xargs -0 grep -l '^- 💎' 2>/dev/null | wc -l | tr -d ' ' || echo "0")

if [ "${_refined:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_refined} file(s) with refined TODOs"
    return 0 2>/dev/null || true
fi

# Check for human comments on filed issues
_filed=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --label "intake:filed" \
    --json number \
    --jq '.[].number' 2>/dev/null || echo "")
for _inum in $_filed; do
    _last=$(gh api --paginate "repos/$TARGET_REPO/issues/$_inum/comments" \
        2>/dev/null | jq -rs 'add // [] | if length == 0 then "empty"
              elif (last | .user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))
              then "human"
              else "robot"
              end' || echo "robot")
    if [ "$_last" = "human" ]; then
        _check_result=1
        _check_reason="human comment on filed issue #${_inum}"
        break
    fi
done
