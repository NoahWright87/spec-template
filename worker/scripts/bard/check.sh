#!/usr/bin/env bash
# check-bard.sh — determine if the bard agent should run.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.
#
# Bard runs when:
#   A) Any agent in the global config is missing agents/{name}/phrases.yaml (onboarding), OR
#   B) Today >= next_run_date in .agents/bard/config.yaml (weekly schedule)

_check_result=0
_check_reason=""

# ── Signal A: Onboarding — any enabled agent missing phrases.yaml ─────────────
_global_agents=$(yq '.agents[]' "$WORKER_CONFIG" 2>/dev/null || echo "")
_missing_count=0
_missing_names=""

for _a in $_global_agents; do
    if [ ! -f "$WORKSPACE/agents/$_a/phrases.yaml" ]; then
        _missing_count=$((_missing_count + 1))
        _missing_names="$_missing_names $_a"
    fi
done

if [ "$_missing_count" -gt 0 ]; then
    _check_result=1
    _check_reason="onboarding: ${_missing_count} agent(s) missing phrases.yaml:${_missing_names}"
    debug "check-bard: onboarding run triggered for:${_missing_names}"
    return 0 2>/dev/null || true
fi

# ── Signal B: Weekly schedule ─────────────────────────────────────────────────
if [ -z "$BARD_NEXT_RUN_DATE" ]; then
    debug "check-bard: no next_run_date configured — skipping"
    _check_reason="no next_run_date configured"
    return 0 2>/dev/null || true
fi

_today=$(date +%Y-%m-%d)
if [ "$_today" \> "$BARD_NEXT_RUN_DATE" ] || [ "$_today" = "$BARD_NEXT_RUN_DATE" ]; then
    _check_result=1
    _check_reason="weekly run due (next_run_date=$BARD_NEXT_RUN_DATE, today=$_today)"
    debug "check-bard: weekly run due — $_today >= $BARD_NEXT_RUN_DATE"
else
    debug "check-bard: weekly run not due — $_today < $BARD_NEXT_RUN_DATE"
fi
