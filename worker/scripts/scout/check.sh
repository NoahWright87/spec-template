#!/usr/bin/env bash
# check-scout.sh — determine if the scout agent should run.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.
#
# Scout runs when today >= next_report_date. Date math is done here in bash
# (not by the LLM) because LLMs are unreliable with date comparisons.

_check_result=0
_check_reason=""

if [ -z "$SCOUT_NEXT_REPORT_DATE" ]; then
    debug "check-scout: no next_report_date configured — skipping"
    _check_reason="no next_report_date configured"
    return 0 2>/dev/null || true
fi

# Compare dates as strings (YYYY-MM-DD format sorts lexicographically)
_today=$(date +%Y-%m-%d)
if [ "$_today" \> "$SCOUT_NEXT_REPORT_DATE" ] || [ "$_today" = "$SCOUT_NEXT_REPORT_DATE" ]; then
    _check_result=1
    _check_reason="report due (next_report_date=$SCOUT_NEXT_REPORT_DATE, today=$_today)"
    debug "check-scout: report due — $_today >= $SCOUT_NEXT_REPORT_DATE"
else
    debug "check-scout: report not due — $_today < $SCOUT_NEXT_REPORT_DATE"
fi
