#!/usr/bin/env bash
# common.sh — shared function library, sourced by entrypoint.sh.
#
# This is NOT an entry point. The entry point is: worker/entrypoint.sh
# Per-agent check/startup scripts live in: worker/scripts/{agent-name}/
#
# Expects these variables to be set before sourcing:
#   WORKER_DEBUG, TARGET_REPO, WORKSPACE, WORKER_CONFIG (may be empty)

# ── Debug logging helpers ────────────────────────────────────────────────────
# debug "message"       — single-line debug output, shown only when WORKER_DEBUG=1
# debug_var "label" val — multi-line value dump (JSON, file contents, etc.)
# Both prefix output with [worker:debug] so it's easy to grep in logs.
debug() {
    [ "$WORKER_DEBUG" = "1" ] && echo "[worker:debug] $*" || true
}
debug_var() {
    [ "$WORKER_DEBUG" = "1" ] || return 0
    local label="$1"; shift
    echo "[worker:debug] ── $label ──"
    echo "$*" | sed 's/^/[worker:debug]   /'
    echo "[worker:debug] ── end $label ──"
}

# ── Per-agent config reader ──────────────────────────────────────────────────
# Reads .agents/{name}/config.yaml from the target repo workspace.
# Exports per-agent env vars with conservative defaults when config is missing.
# Only active for config version >= 2; version 1 repos get hardcoded defaults.
#
# Exports:
#   AGENT_MAX_OPEN_PRS     — per-agent PR cap (default: 1)
#   MAX_ITEMS_PER_RUN      — items to process per run (default: 1)
#   MAX_REFINE_PER_RUN     — alias for MAX_ITEMS_PER_RUN (backward compat with refine-todos.md)
#   MAX_ISSUES_PER_RUN     — refine agent: issues to assess per run (default: 3)
#   MAX_TODO_SIZE          — knock-out-todos agent: maximum effort size to implement (default: "S")
#   SCOUT_NEXT_REPORT_DATE — scout agent: when the next report is due
#   SCOUT_REPORT_INTERVAL  — scout agent: days between reports (default: 14)
#   SCOUT_REPORT_INSTRUCTIONS — scout agent: report instructions filename (default: "report-technical.md")
# ── TODO size rank helper ────────────────────────────────────────────────────
# Converts a size label to a numeric rank for comparison.
# Strips all ? characters before ranking so "?S" → "S".
# Returns 0 for unknown sizes (do not filter these out).
_todo_size_rank() {
    local _size="${1//\?/}"           # strip all ? characters (pure bash)
    _size="${_size//[[:space:]]/}"    # strip all whitespace (pure bash)
    case "$_size" in
        XS) echo 1 ;;
        S)  echo 2 ;;
        M)  echo 3 ;;
        L)  echo 4 ;;
        XL) echo 5 ;;
        *)  echo 0 ;;  # unknown — do not filter out
    esac
}

# _todo_size_max_items effort_string
# Returns the configured per-size item limit for the given effort annotation.
# Uses MAX_TODOS_XS / MAX_TODOS_S / etc. env vars (set by read_agent_config).
# Returns -1 for unrecognized/unknown sizes — no per-size limit applied.
# Strips leading ? and whitespace before matching (e.g. "?M" → "M").
_todo_size_max_items() {
    local _size="${1//\?/}"
    _size="${_size//[[:space:]]/}"
    _size="${_size^^}"
    case "$_size" in
        XS) echo "${MAX_TODOS_XS:-3}" ;;
        S)  echo "${MAX_TODOS_S:-1}" ;;
        M)  echo "${MAX_TODOS_M:-0}" ;;
        L)  echo "${MAX_TODOS_L:-0}" ;;
        XL) echo "${MAX_TODOS_XL:-0}" ;;
        *)  echo "-1" ;;
    esac
}

# ── Config auto-upgrade ──────────────────────────────────────────────────────
# upgrade_config config_file current_version
#   Migrates the target repo's .agents/config.yaml to CURRENT_CONFIG_VERSION.
#   Each version step is a separate block (incremental migrations).
#   Commits the upgraded file to the workspace repo so the change is persisted.
#   Sets _config_version=$CURRENT_CONFIG_VERSION on success.
upgrade_config() {
    local config_file="$1"
    local current_version="$2"

    if [ "$current_version" -ge "$CURRENT_CONFIG_VERSION" ]; then
        return
    fi

    echo "[worker] Upgrading .agents/config.yaml from version $current_version → $CURRENT_CONFIG_VERSION"

    # v1 → v2: add version field; ensure specs_dir default is present
    if [ "$current_version" -lt 2 ]; then
        yq -i '.version = 2' "$config_file"
        yq -i '.settings.specs_dir = (.settings.specs_dir // "specs")' "$config_file"
    fi

    # Future: v2 → v3 migrations go here

    local rel_config_file="$config_file"
    if [[ "$config_file" == "$WORKSPACE/"* ]]; then
        rel_config_file="${config_file#$WORKSPACE/}"
    fi

    git -C "$WORKSPACE" add -- "$rel_config_file"
    git -C "$WORKSPACE" commit -m "Upgrade .agents/config.yaml to version $CURRENT_CONFIG_VERSION

Automated by spec-template worker." || true

    _config_version=$CURRENT_CONFIG_VERSION
    echo "[worker] Config upgrade complete — now at version $_config_version"
}

read_agent_config() {
    local agent="$1"
    local agent_config="$WORKSPACE/.agents/$agent/config.yaml"

    # Defaults — conservative, safe for any agent
    export AGENT_MAX_OPEN_PRS=1
    export MAX_ITEMS_PER_RUN=1
    export MAX_REFINE_PER_RUN=1
    export MAX_ISSUES_PER_RUN=3
    export MAX_TODO_SIZE="S"
    export MAX_TODOS_XS=3
    export MAX_TODOS_S=1
    export MAX_TODOS_M=0
    export MAX_TODOS_L=0
    export MAX_TODOS_XL=0
    export SCOUT_NEXT_REPORT_DATE=""
    export SCOUT_REPORT_INTERVAL=14
    export SCOUT_REPORT_INSTRUCTIONS="templates/report-technical.md"

    if [ "$_config_version" -lt 2 ]; then
        debug "Config version $_config_version < 2 — using hardcoded defaults for '$agent'"
        return
    fi

    if [ ! -f "$agent_config" ]; then
        debug "No per-agent config at $agent_config — using defaults for '$agent'"
        return
    fi

    echo "[worker]   Reading per-agent config: $agent_config"

    # Common fields
    AGENT_MAX_OPEN_PRS=$(yq '.max_open_prs // 1' "$agent_config")
    MAX_ITEMS_PER_RUN=$(yq '.max_items_per_run // 1' "$agent_config")
    MAX_REFINE_PER_RUN="$MAX_ITEMS_PER_RUN"
    export AGENT_MAX_OPEN_PRS MAX_ITEMS_PER_RUN MAX_REFINE_PER_RUN

    # Agent-specific fields
    case "$agent" in
        refine)
            MAX_ISSUES_PER_RUN=$(yq '.max_issues_per_run // 3' "$agent_config")
            export MAX_ISSUES_PER_RUN
            ;;
        knock-out-todos)
            # Read maximum_issue_size from config, then normalize and validate.
            local _max_todo_size_raw _max_todo_size_trimmed _max_todo_size_normalized
            _max_todo_size_raw=$(yq '.maximum_issue_size // "S"' "$agent_config")
            # Trim surrounding whitespace.
            _max_todo_size_trimmed="$(printf '%s' "$_max_todo_size_raw" | tr '[:space:]' ' ' | xargs)"
            # Uppercase for case-insensitive handling.
            _max_todo_size_normalized="${_max_todo_size_trimmed^^}"

            case "$_max_todo_size_normalized" in
                XS|S|M|L|XL)
                    MAX_TODO_SIZE="$_max_todo_size_normalized"
                    ;;
                "")
                    # Empty after trimming — fall back to safe default.
                    MAX_TODO_SIZE="S"
                    ;;
                *)
                    echo "[worker]   Warning: Unrecognized maximum_issue_size '$_max_todo_size_trimmed' in $agent_config (env MAX_TODO_SIZE) — falling back to 'S'."
                    MAX_TODO_SIZE="S"
                    ;;
            esac
            export MAX_TODO_SIZE

            # Read per-size item count limits (max_items_per_size map).
            # _sanitize_int: trim whitespace, verify integer; fall back to default with warning.
            _sanitize_int() {
                local val="${1//[[:space:]]/}" default="$2"
                if [[ "$val" =~ ^-?[0-9]+$ ]]; then echo "$val"
                else echo "[worker] Warning: invalid max_items_per_size value '$1', using default $default" >&2; echo "$default"
                fi
            }
            MAX_TODOS_XS=$(_sanitize_int "$(yq '.max_items_per_size.XS // 3' "$agent_config")" 3)
            MAX_TODOS_S=$(_sanitize_int "$(yq '.max_items_per_size.S // 1' "$agent_config")" 1)
            MAX_TODOS_M=$(_sanitize_int "$(yq '.max_items_per_size.M // 0' "$agent_config")" 0)
            MAX_TODOS_L=$(_sanitize_int "$(yq '.max_items_per_size.L // 0' "$agent_config")" 0)
            MAX_TODOS_XL=$(_sanitize_int "$(yq '.max_items_per_size.XL // 0' "$agent_config")" 0)
            export MAX_TODOS_XS MAX_TODOS_S MAX_TODOS_M MAX_TODOS_L MAX_TODOS_XL
            ;;
        scout)
            SCOUT_NEXT_REPORT_DATE=$(yq '.next_report_date // ""' "$agent_config")
            SCOUT_REPORT_INTERVAL=$(yq '.report_interval_days // 14' "$agent_config")
            SCOUT_REPORT_INSTRUCTIONS=$(yq '.report_instructions // "templates/report-technical.md"' "$agent_config")
            export SCOUT_NEXT_REPORT_DATE SCOUT_REPORT_INTERVAL SCOUT_REPORT_INSTRUCTIONS
            ;;
    esac

    debug "Per-agent config for '$agent': max_open_prs=$AGENT_MAX_OPEN_PRS max_items=$MAX_ITEMS_PER_RUN"
}

# ── PR comment fetching ──────────────────────────────────────────────────────
# Fetches non-agent comments from a PR's conversation and review threads,
# returning structured JSON so Claude can reply to specific comment threads
# without needing to re-query the GitHub API itself.
#
# WHY filter on 🤖 prefix instead of user.type:
#   The old approach filtered on user.type == "User", which excluded GitHub
#   Copilot (type: "Bot") and other bot comments that agents SHOULD respond to.
#   The 🤖 prefix is the only reliable marker for "our agent wrote this" —
#   every agent comment uses it per the Reminders section in agent definitions.
#   By filtering here in bash, Claude never sees agent comments at all,
#   making self-reply structurally impossible (not just a rule it might ignore).
#
# Sets:
#   _review_comments_json       — JSON array of inline review comments (Files Changed tab)
#   _conversation_comments_json — JSON array of top-level PR conversation comments
#   _total_comment_count        — total non-agent comments found across both types
fetch_pr_comments() {
    local pr_num="$1"

    # ── Review comments (Files Changed tab) ──────────────────────────────
    # Thread-aware filtering: fetch ALL comments (including agent ones),
    # group by thread root, exclude threads where the last comment is
    # already from the agent — prevents duplicate replies on every cron run.
    #
    # GitHub threading model: all replies have in_reply_to_id pointing to
    # the top-level comment, so `in_reply_to_id // id` gives the thread root.
    #
    # NOTE: `gh api --paginate` with `--jq` runs the jq expression per-page,
    # producing multiple arrays (`[...][...]`). Piping through `jq -s 'add // []'`
    # merges them into a single array.
    local _all_review_json
    _all_review_json=$(gh api --paginate "repos/$TARGET_REPO/pulls/$pr_num/comments" \
        --jq '[.[] | {
            id: .id,
            user: .user.login,
            path: .path,
            line: (.line // .original_line // .position),
            body: .body,
            in_reply_to_id: .in_reply_to_id,
            is_agent: (.body | test("^[[:space:]]*🤖"))
        }]' 2>/dev/null | jq -s 'add // []') || _all_review_json="[]"

    _review_comments_json=$(echo "$_all_review_json" | jq '
        group_by(.in_reply_to_id // .id)
        | map(sort_by(.id) | select(.[-1].is_agent | not))
        | [.[][] | select(.is_agent | not) | del(.is_agent)]
    ')

    # ── Conversation comments (PR discussion tab) ────────────────────────
    # Array-index filtering: uses position in the API response (which reflects
    # insertion order) rather than comment ID (which GitHub does not guarantee
    # is chronological). For each non-agent comment, include it only if there
    # is no subsequent agent comment in the array — meaning the agent hasn't
    # yet responded after this comment appeared.
    local _all_convo_json
    _all_convo_json=$(gh api --paginate "repos/$TARGET_REPO/issues/$pr_num/comments" \
        --jq '[.[] | {
            id: .id,
            user: .user.login,
            body: .body,
            is_agent: (.body | test("^[[:space:]]*🤖"))
        }]' 2>/dev/null | jq -s 'add // []') || _all_convo_json="[]"

    _conversation_comments_json=$(echo "$_all_convo_json" | jq '
        . as $all
        | to_entries
        | map(select(.value.is_agent | not))
        | map(
            .key as $idx
            | select(
                ($all[($idx+1):] | any(.[]; .is_agent)) | not
            )
          )
        | [.[].value | del(.is_agent)]
    ')

    local review_count conversation_count
    review_count=$(echo "$_review_comments_json" | jq 'length')
    conversation_count=$(echo "$_conversation_comments_json" | jq 'length')
    _total_comment_count=$(( review_count + conversation_count ))

    debug "PR #$pr_num comments: $review_count review + $conversation_count conversation = $_total_comment_count unhandled total"
    if [ "$WORKER_DEBUG" = "1" ] && [ "$review_count" -gt 0 ]; then
        debug "Review comment IDs (PR #$pr_num): $(echo "$_review_comments_json" | jq -r '[.[].id] | join(", ")')"
    fi
    if [ "$WORKER_DEBUG" = "1" ] && [ "$conversation_count" -gt 0 ]; then
        debug "Conversation comment IDs (PR #$pr_num): $(echo "$_conversation_comments_json" | jq -r '[.[].id] | join(", ")')"
    fi
}

# ── Situation report builder ─────────────────────────────────────────────────
# Assembles a markdown "situation report" prepended to the agent prompt.
# This shifts deterministic work (API calls, comment filtering, conflict
# detection) into bash so Claude receives pre-fetched, pre-filtered data.
#
# WHY a situation report instead of letting Claude query GitHub itself:
#   1. Agent comments are structurally invisible — Claude can't self-reply
#   2. Comment IDs are pre-extracted — Claude replies to the right thread
#   3. Merge conflict state is pre-checked — no redundant API call
#   4. Saves 3-5 tool calls per agent run (fewer tokens, faster execution)
#   5. Deterministic filtering can't be "forgotten" the way prompt rules can
#
# Sets:
#   _situation_report — markdown string to prepend to the agent prompt
build_situation_report() {
    local agent="$1" pr_num="$2" branch="$3" reason="$4"
    local f
    f=$(mktemp)

    # Write the report to a temp file so we can use simple echo statements
    # instead of fighting with bash string escaping for multi-line markdown.
    {
        echo "## Situation Report"
        echo ""
        echo "Agent: **${agent}** | Branch: \`${branch}\` | Run reason: ${reason}"
        echo ""

        if [ -n "$pr_num" ]; then
            echo "### PR #${pr_num}"
            echo ""

            # ── Merge conflict status ──
            if [ "$_has_conflicts" = "true" ]; then
                echo "**⚠ Merge conflicts detected.** Resolve conflicts before any other work."
                echo "Read and follow [resolve-merge-conflicts.md](/worker/agents/tasks/resolve-merge-conflicts.md)."
                echo ""
            else
                echo "Mergeable: yes (no conflicts)."
                echo ""
            fi

            # ── Write comment JSON to files ──
            # Comments are written to disk and referenced by path rather than
            # embedded in the prompt. This keeps prompt size bounded and lets
            # Claude read comments on demand (one at a time if needed).
            local review_count convo_count
            review_count=$(echo "$_review_comments_json" | jq 'length')
            convo_count=$(echo "$_conversation_comments_json" | jq 'length')

            if [ "$review_count" -gt 0 ]; then
                echo "$_review_comments_json" > /tmp/pr-review-comments.json
                echo "### Review Comments (${review_count})"
                echo ""
                echo "Inline code comments on the Files Changed tab."
                echo "**Read the file:** \`/tmp/pr-review-comments.json\` — JSON array with fields: id, user, path, line, body, in_reply_to_id."
                echo ""
                echo "Reply to each in-thread using:"
                echo '```bash'
                echo "gh api \"repos/\$REPO/pulls/${pr_num}/comments/COMMENT_ID/replies\" -X POST -f body=\"🤖 Claude (\$AGENT_NAME): [response]\""
                echo '```'
                echo ""
            fi

            if [ "$convo_count" -gt 0 ]; then
                echo "$_conversation_comments_json" > /tmp/pr-conversation-comments.json
                echo "### Conversation Comments (${convo_count})"
                echo ""
                echo "Top-level discussion on the PR."
                echo "**Read the file:** \`/tmp/pr-conversation-comments.json\` — JSON array with fields: id, user, body."
                echo ""
                echo "Reply using \`gh pr comment ${pr_num}\`."
                echo ""
            fi

            if [ "$_total_comment_count" -gt 0 ]; then
                echo "**Address all comments before doing any new work.**"
                echo "Read and follow [respond-to-pr-comments.md](/worker/agents/tasks/respond-to-pr-comments.md) for guidance on how to respond."
                echo ""
            fi
        else
            echo "### No Existing PR"
            echo ""
            echo "This is a new work session. A branch and PR will be created when you have changes."
            echo ""
        fi

        # ── Startup context from per-agent startup script ──
        # Each startup script sets _startup_context with markdown to append here.
        if [ -n "${_startup_context:-}" ]; then
            echo "$_startup_context"
            echo ""
        fi

        echo "---"
        echo ""
    } > "$f"

    _situation_report=$(cat "$f")
    rm -f "$f"
}
