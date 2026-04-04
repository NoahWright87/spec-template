#!/usr/bin/env bash
# check-intake.sh — determine if the intake agent has work to do.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.

_check_result=0
_check_reason=""

# Signal: Issues labeled intake:ready but not yet filed/rejected/ignored
_intake_ready_count=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --label "intake:ready" \
    --json number,labels \
    --jq '[.[] | select(
        (.labels | map(.name) |
            (contains(["intake:filed"]) or contains(["intake:rejected"]) or contains(["intake:ignore"]))
        ) | not
    )] | length' 2>/dev/null || echo "0")
debug "check-intake: intake-ready issues: ${_intake_ready_count:-0}"

if [ "${_intake_ready_count:-0}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_intake_ready_count} intake-ready issue(s)"
fi
