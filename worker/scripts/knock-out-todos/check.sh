#!/usr/bin/env bash
# check-knock-out-todos.sh — determine if the knock-out-todos agent has work to do.
# Sourced by entrypoint.sh. Sets _check_result (0=skip, 1=run) and _check_reason.

_check_result=0
_check_reason=""

# Signal 1: Refined TODOs (💎 in specs) ready for implementation within the size limit.
# MAX_TODO_SIZE, _todo_size_rank(), and _todo_size_max_items() are available from
# read_agent_config + common.sh.
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")
_max_rank=$(_todo_size_rank "${MAX_TODO_SIZE:-S}")
_eligible_count=0
declare -A _check_size_count=()
while IFS= read -r _todo_line; do
    _effort=$(echo "$_todo_line" | sed -n 's/.*\*(effort: \([^)]*\))\*.*/\1/p')
    _item_rank=$(_todo_size_rank "$_effort")
    if [ "$_item_rank" -eq 0 ]; then
        # Unknown size: include without per-size count limit (existing behavior)
        _eligible_count=$((_eligible_count + 1))
    elif [ "$_item_rank" -le "$_max_rank" ]; then
        # Within size ceiling: apply per-size count limit
        _size_max=$(_todo_size_max_items "$_effort")
        _norm_size="${_effort//\?/}"
        _norm_size="${_norm_size//[[:space:]]/}"
        _norm_size="${_norm_size^^}"
        _current="${_check_size_count[$_norm_size]:-0}"
        if [ "$_size_max" -lt 0 ] || [ "$_current" -lt "$_size_max" ]; then
            _eligible_count=$((_eligible_count + 1))
            _check_size_count[$_norm_size]=$((_current + 1))
        fi
    fi
done < <(find "$WORKSPACE/$_specs_dir" -name "*.todo.md" -print0 2>/dev/null \
             | sort -z \
             | xargs -0 grep -h '^- 💎' 2>/dev/null || true)
debug "check-knock-out-todos: eligible refined TODOs (within MAX_TODO_SIZE=${MAX_TODO_SIZE:-S}, per-size limits XS=${MAX_TODOS_XS:-3} S=${MAX_TODOS_S:-1} M=${MAX_TODOS_M:-0} L=${MAX_TODOS_L:-0} XL=${MAX_TODOS_XL:-0}): ${_eligible_count}"

if [ "${_eligible_count}" -gt 0 ]; then
    _check_result=1
    _check_reason="${_eligible_count} eligible refined TODO(s)"
fi

# Signal 2: Human comment on a filed issue
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
    debug "check-knock-out-todos: issue #$_inum last commenter: $_last"
    if [ "$_last" = "human" ]; then
        if [ "$_check_result" -eq 0 ]; then
            _check_result=1
            _check_reason="human comment on filed issue #${_inum}"
        else
            _check_reason="${_check_reason} + human comment on filed issue #${_inum}"
        fi
        break
    fi
done
