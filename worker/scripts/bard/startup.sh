#!/usr/bin/env bash
# startup-bard.sh — gather data for the bard agent before Claude runs.
# Sourced by entrypoint.sh. Writes data files and sets _startup_context.
#
# All date math and agent selection happens here in bash, not in the LLM.
# Claude reads pre-gathered data and focuses on phrase generation and writing.

_startup_context=""

# ── Config: initialize if missing ────────────────────────────────────────────
_bard_config="$WORKSPACE/.agents/bard/config.yaml"

if [ ! -f "$_bard_config" ]; then
    echo "[worker]   Bard startup: no config.yaml — running init"
    source "$SCRIPT_DIR/bard/init.sh"
fi

# ── Read config values (with defaults) ───────────────────────────────────────
_agents_per_run=$(yq '.agents_per_run // 2' "$_bard_config" 2>/dev/null || echo "2")
_phrases_per_agent=$(yq '.phrases_per_agent // 2' "$_bard_config" 2>/dev/null || echo "2")
_selection_strategy=$(yq '.agent_selection_strategy // "least_populated"' "$_bard_config" 2>/dev/null || echo "least_populated")
_suggestion_label=$(yq '.suggestion_label // "bard/suggestion"' "$_bard_config" 2>/dev/null || echo "bard/suggestion")
_self_referential=$(yq '.self_referential // true' "$_bard_config" 2>/dev/null || echo "true")
_last_agent_index=$(yq '.last_agent_index // 0' "$_bard_config" 2>/dev/null || echo "0")

# ── Detect run mode ───────────────────────────────────────────────────────────
_global_agents=$(yq '.agents[]' "$WORKER_CONFIG" 2>/dev/null || echo "")
_missing_agents=""

for _a in $_global_agents; do
    if [ ! -f "$WORKSPACE/agents/$_a/phrases.yaml" ]; then
        _missing_agents="$_missing_agents $_a"
    fi
done
_missing_agents="${_missing_agents# }"  # strip leading space

if [ -n "$_missing_agents" ]; then
    _bard_mode="onboarding"
else
    _bard_mode="weekly"
fi

echo "[worker]   Bard startup: mode=$_bard_mode"

# ── Compute next run date ─────────────────────────────────────────────────────
_today=$(date +%Y-%m-%d)
if command -v gdate > /dev/null 2>&1; then
    _next_run_date=$(gdate -d "$_today + 7 days" +%Y-%m-%d)
elif date -d "today" > /dev/null 2>&1; then
    _next_run_date=$(date -d "$_today + 7 days" +%Y-%m-%d)
else
    _next_run_date=$(date -d "@$(( $(date +%s) + 7 * 86400 ))" +%Y-%m-%d 2>/dev/null || echo "unknown")
fi

# ── Select agents for weekly runs ─────────────────────────────────────────────
_selected_agents=""

if [ "$_bard_mode" = "weekly" ]; then
    # Build list of candidate agents (all global agents, optionally including bard itself)
    _candidates=""
    for _a in $_global_agents; do
        if [ "$_a" = "bard" ] && [ "$_self_referential" != "true" ]; then
            continue
        fi
        _candidates="$_candidates $_a"
    done
    _candidates="${_candidates# }"

    if [ "$_selection_strategy" = "round_robin" ]; then
        # Pick agents starting at last_agent_index, wrapping around
        _candidate_arr=($_candidates)
        _count=${#_candidate_arr[@]}
        _picked=0
        _idx=$_last_agent_index

        while [ "$_picked" -lt "$_agents_per_run" ] && [ "$_picked" -lt "$_count" ]; do
            _wrapped_idx=$(( _idx % _count ))
            _selected_agents="$_selected_agents ${_candidate_arr[$_wrapped_idx]}"
            _idx=$(( _idx + 1 ))
            _picked=$(( _picked + 1 ))
        done

        # Advance index for next run (write back to config)
        _new_index=$(( (_last_agent_index + _agents_per_run) % _count ))
        yq -i ".last_agent_index = $_new_index" "$_bard_config" 2>/dev/null || true

    else
        # least_populated: count phrases per agent and pick those with fewest
        declare -A _phrase_counts
        for _a in $_candidates; do
            _pfile="$WORKSPACE/agents/$_a/phrases.yaml"
            if [ -f "$_pfile" ]; then
                # Count non-blank, non-comment, non-key lines in the phrases block
                _count=$(grep -c '^  - ' "$_pfile" 2>/dev/null || echo "0")
                _phrase_counts["$_a"]=$_count
            else
                _phrase_counts["$_a"]=0
            fi
        done

        # Sort by count ascending; pick the first N
        _sorted=$(for _a in "${!_phrase_counts[@]}"; do
            echo "${_phrase_counts[$_a]} $_a"
        done | sort -n | head -n "$_agents_per_run" | awk '{print $2}')

        _selected_agents=$(echo "$_sorted" | tr '\n' ' ')
    fi

    _selected_agents="${_selected_agents# }"
    echo "[worker]   Bard startup: selected agents (strategy=$_selection_strategy): $_selected_agents"
fi

# ── Fetch suggestions ─────────────────────────────────────────────────────────
_suggestions=$(gh issue list \
    --repo "$TARGET_REPO" \
    --label "$_suggestion_label" \
    --state open \
    --json number,title,body,author,url \
    --limit 20 2>/dev/null || echo "[]")

_suggestion_count=$(echo "$_suggestions" | jq 'length' 2>/dev/null || echo "0")
echo "[worker]   Bard startup: suggestions pending=$_suggestion_count"
echo "$_suggestions" | jq '.' > /tmp/bard-suggestions.json 2>/dev/null || echo "[]" > /tmp/bard-suggestions.json

# ── Write run config for Claude ───────────────────────────────────────────────
if [ "$_bard_mode" = "onboarding" ]; then
    _selected_for_json=$(echo "$_missing_agents" | tr ' ' '\n' | jq -R . | jq -s .)
else
    _selected_for_json=$(echo "$_selected_agents" | tr ' ' '\n' | jq -R . | jq -s .)
fi

cat > /tmp/bard-run-config.json << EOF
{
  "mode": "$_bard_mode",
  "selected_agents": $_selected_for_json,
  "phrases_per_agent": $_phrases_per_agent,
  "suggestion_count": $_suggestion_count,
  "next_run_date": "$_next_run_date",
  "today": "$_today"
}
EOF

debug_var "bard-run-config" "$(cat /tmp/bard-run-config.json)"

# ── Build startup context ─────────────────────────────────────────────────────
if [ "$_bard_mode" = "onboarding" ]; then
    _mode_detail="### Onboarding Mode

The following agents are missing \`agents/{name}/phrases.yaml\` and need onboarding:
$(echo "$_missing_agents" | tr ' ' '\n' | sed 's/^/- /')

Create a \`phrases.yaml\` for each, populated with initial phrases that match the agent's personality.
Then open an introductory PR in full Bard voice."

else
    _mode_detail="### Weekly Mode

**Selected agents** (strategy: $_selection_strategy):
$(echo "$_selected_agents" | tr ' ' '\n' | sed 's/^/- /')

**Phrases to add per agent:** $_phrases_per_agent
**Suggestions pending:** $_suggestion_count (see \`/tmp/bard-suggestions.json\`)"

    if [ "$_suggestion_count" -gt 0 ]; then
        _mode_detail="$_mode_detail

**Run mode: Weekly with suggestions** — process suggestions first, then fill remaining slots with original phrases."
    else
        _mode_detail="$_mode_detail

**Run mode: Weekly, no suggestions** — generate original phrases for selected agents."
    fi
fi

_startup_context="### Bard Run Configuration

$_mode_detail

**Run config file:** \`/tmp/bard-run-config.json\`
**Suggestions file:** \`/tmp/bard-suggestions.json\`
**Next run date (computed):** $_next_run_date

**After completing the run:** Update \`.agents/bard/config.yaml\` with:
\`\`\`yaml
next_run_date: \"$_next_run_date\"
\`\`\`
Commit this update along with the phrases changes (or in a follow-up commit before the PR is opened)."

export BARD_NEXT_RUN_DATE_COMPUTED="$_next_run_date"
export BARD_RUN_MODE="$_bard_mode"
