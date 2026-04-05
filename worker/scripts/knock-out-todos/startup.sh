#!/usr/bin/env bash
# startup.sh — pre-filter refined TODOs for the knock-out-todos agent.
# Sourced by entrypoint.sh. Uses MAX_TODO_SIZE from the environment
# (exported by read_agent_config from per-agent maximum_issue_size, with a
# local default here), filters out 💎 TODO items whose effort exceeds that
# threshold, and exposes the eligible list to Claude via _startup_context.
#
# Exports:
#   MAX_TODO_SIZE — the configured size ceiling (e.g. "S")
#
# Writes:
#   /tmp/knock-out-todos-eligible.json — JSON array of eligible TODO items
#                                        [{item: "raw line", effort: "S"}, ...]

_startup_context=""

# ── Maximum issue size ───────────────────────────────────────────────────────
# MAX_TODO_SIZE is normally exported by read_agent_config (called before startup.sh).
# Fall back to "S" defensively if it's unset or cleared in the environment.
# _todo_size_rank is defined in common.sh (sourced by entrypoint.sh before this).
MAX_TODO_SIZE="${MAX_TODO_SIZE:-S}"
export MAX_TODO_SIZE
_max_rank=$(_todo_size_rank "$MAX_TODO_SIZE")
echo "[worker]   Startup: knock-out-todos maximum_issue_size=$MAX_TODO_SIZE (rank=$_max_rank)"

# ── Scan all refined (💎) TODO items and filter by effort ────────────────────
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")

_eligible_item_lines=()
_eligible_efforts=()
_filtered_out_size=0
_filtered_out_count=0
_total=0
declare -A _startup_size_count=()

while IFS= read -r _todo_line; do
    _total=$((_total + 1))

    # Extract effort annotation: *(effort: S)*, *(effort: ?M)*, *(effort: L?)*, etc.
    _effort=$(echo "$_todo_line" | sed -n 's/.*\*(effort: \([^)]*\))\*.*/\1/p')

    _item_rank=$(_todo_size_rank "$_effort")

    if [ "$_item_rank" -eq 0 ]; then
        # Unknown size: include without per-size count limit (existing behavior)
        _eligible_item_lines+=("$_todo_line")
        _eligible_efforts+=("$_effort")
    elif [ "$_item_rank" -gt "$_max_rank" ]; then
        # Exceeds size ceiling
        _filtered_out_size=$((_filtered_out_size + 1))
        debug "startup-knock-out-todos: filtered (effort=$_effort > $MAX_TODO_SIZE): $_todo_line"
    else
        # Within size ceiling: apply per-size count limit
        _size_max=$(_todo_size_max_items "$_effort")
        _norm_size="${_effort//\?/}"
        _norm_size="${_norm_size//[[:space:]]/}"
        _norm_size="${_norm_size^^}"
        _current="${_startup_size_count[$_norm_size]:-0}"
        if [ "$_size_max" -lt 0 ] || [ "$_current" -lt "$_size_max" ]; then
            _eligible_item_lines+=("$_todo_line")
            _eligible_efforts+=("$_effort")
            _startup_size_count[$_norm_size]=$((_current + 1))
        else
            _filtered_out_count=$((_filtered_out_count + 1))
            debug "startup-knock-out-todos: filtered (per-size limit ${_norm_size}=${_size_max} reached): $_todo_line"
        fi
    fi
done < <(find "$WORKSPACE/$_specs_dir" -name "*.todo.md" -print0 2>/dev/null \
             | sort -z \
             | xargs -0 grep -h '^- 💎' 2>/dev/null || true)

_filtered_out=$((_filtered_out_size + _filtered_out_count))

# Build the eligible items JSON in a single jq pass (avoids O(n²) jq-per-item cost).
if [ "${#_eligible_item_lines[@]}" -gt 0 ]; then
    _items_json=$(printf '%s\n' "${_eligible_item_lines[@]}" | jq -Rn '[inputs]')
    _efforts_json=$(printf '%s\n' "${_eligible_efforts[@]}" | jq -Rn '[inputs]')
    _eligible_items=$(jq -n \
        --argjson items "$_items_json" \
        --argjson efforts "$_efforts_json" \
        '[$items, $efforts] | transpose | map({item: .[0], effort: .[1]})')
else
    _eligible_items='[]'
fi

_eligible_count=$(echo "$_eligible_items" | jq 'length')
echo "[worker]   Startup: ${_eligible_count} eligible TODO items (${_filtered_out} filtered [${_filtered_out_size} size / ${_filtered_out_count} count], MAX_TODO_SIZE=${MAX_TODO_SIZE})"

# ── Write eligible items to file ─────────────────────────────────────────────
echo "$_eligible_items" | jq '.' > /tmp/knock-out-todos-eligible.json

# ── Build startup context ────────────────────────────────────────────────────
_per_size_limits="XS:${MAX_TODOS_XS:-3}, S:${MAX_TODOS_S:-1}, M:${MAX_TODOS_M:-0}, L:${MAX_TODOS_L:-0}, XL:${MAX_TODOS_XL:-0}"
if [ "$_filtered_out" -gt 0 ]; then
    _startup_context="### TODO Size Filter (MAX_TODO_SIZE=${MAX_TODO_SIZE})

${_filtered_out} item(s) were excluded this run: ${_filtered_out_size} exceeded the size ceiling (**${MAX_TODO_SIZE}**), ${_filtered_out_count} exceeded per-size count limits (${_per_size_limits}).
These limits are set in \`.agents/knock-out-todos/config.yaml\` → \`maximum_issue_size\` and \`max_items_per_size\`.
Only the ${_eligible_count} item(s) below are eligible — skip any TODO not in this list.

**Read the file:** \`/tmp/knock-out-todos-eligible.json\` — JSON array with fields: \`item\` (raw TODO line), \`effort\` (parsed size)."
else
    _startup_context="### TODO Size Filter (MAX_TODO_SIZE=${MAX_TODO_SIZE})

All ${_total} refined (💎) TODO item(s) are within the configured size and count limits (${_per_size_limits}). No items were filtered out.
All ${_total} item(s) are included in the eligible list — skip any TODO not in this list.

**Read the file:** \`/tmp/knock-out-todos-eligible.json\` — JSON array with fields: \`item\` (raw TODO line), \`effort\` (parsed size)."
fi
