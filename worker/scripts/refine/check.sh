#!/usr/bin/env bash
# check-refine.sh — determine if the refine agent has work to do.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.

_check_result=0
_check_reason=""

# Signal 1: Unrefined issues — no intake:* label at all, OR intake:filed without intake:ready
_refine_issue_count=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,labels \
    --jq '[.[] | select(
        ((.labels | map(.name) | any(startswith("intake:")) ) | not)
        or
        (
            (.labels | map(.name) | any(. == "intake:filed"))
            and
            ((.labels | map(.name) | any(. == "intake:ready")) | not)
        )
    )] | length' 2>/dev/null || echo "0")
debug "check-refine: unrefined issues (no intake:* label or intake:filed without intake:ready): ${_refine_issue_count:-0}"

if [ "${_refine_issue_count:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_refine_issue_count} unrefined issue(s)"
fi

# Signal 2: Unrefined TODOs (❓ in specs)
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")
_unrefined_todo_count=$(find "$WORKSPACE/$_specs_dir" -name "*.todo.md" -print0 2>/dev/null | xargs -0 grep -l '^- ❓' 2>/dev/null | wc -l | tr -d ' ' || echo "0")
debug "check-refine: files with unrefined TODOs (❓): ${_unrefined_todo_count:-0}"

if [ "$_check_result" -eq 0 ] && [ "${_unrefined_todo_count:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_unrefined_todo_count} file(s) with unrefined TODOs"
fi

# Combine reasons if both signals fire
if [ "${_refine_issue_count:-0}" -gt 0 ] && [ "${_unrefined_todo_count:-0}" -gt 0 ]; then
    _check_reason="${_refine_issue_count} unrefined issue(s) + ${_unrefined_todo_count} file(s) with unrefined TODOs"
fi
