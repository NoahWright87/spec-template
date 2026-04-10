#!/usr/bin/env bash
# init-bard.sh — initialize .agents/bard/ when config is missing.
# Sourced by startup.sh when .agents/bard/config.yaml does not exist.
#
# Creates:
#   .agents/bard/config.yaml   with defaults and next_run_date 7 days from today

_bard_config_dir="$WORKSPACE/.agents/bard"
_bard_config="$_bard_config_dir/config.yaml"

echo "[worker]   Bard init: creating $_bard_config"
mkdir -p "$_bard_config_dir"

# Compute next run date: 7 days from today
_today=$(date +%Y-%m-%d)
if command -v gdate > /dev/null 2>&1; then
    _next_run=$(gdate -d "$_today + 7 days" +%Y-%m-%d)
elif date -d "today" > /dev/null 2>&1; then
    _next_run=$(date -d "$_today + 7 days" +%Y-%m-%d)
else
    _next_run=$(date -d "@$(( $(date +%s) + 7 * 86400 ))" +%Y-%m-%d 2>/dev/null || echo "unknown")
fi

cat > "$_bard_config" << EOF
# Bard agent configuration
# See: https://github.com/NoahWright87/spec-template

# How many agents to add phrases for per weekly run
agents_per_run: 2

# How many new phrases to add per agent per run
phrases_per_agent: 2

# Strategy for selecting which agent to work on each run
# "least_populated" = prioritize agents with fewest phrases
# "round_robin"     = rotate through agents in order
agent_selection_strategy: least_populated

# GitHub issue label to watch for community suggestions
suggestion_label: bard/suggestion

# Whether the Bard adds phrases to its own phrases.yaml
self_referential: true

# When the next weekly run is due (managed automatically — do not edit by hand)
next_run_date: "$_next_run"

# Internal: tracks position for round_robin strategy
last_agent_index: 0
EOF

echo "[worker]   Bard init: config created (next_run_date=$_next_run)"
