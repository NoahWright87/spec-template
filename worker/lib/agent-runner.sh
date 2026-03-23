#!/usr/bin/env bash
# agent-runner.sh — Per-agent execution loop
#
# Iterates through declared agents, checks triggers, assembles prompts,
# invokes Claude CLI, and writes state files.
#
# Required globals:
#   AGENTS            — newline-separated list of agent names
#   AGENT_DIR         — path to worker/agents/
#   TASK_DIR          — path to worker/tasks/
#   WORKSPACE         — path to target repo clone
#   TARGET_REPO       — owner/repo string
#   TARGET_BRANCH     — target branch (default: main)
#   MAX_OPEN_PRS      — max open worker PRs
#   STATE_DIR         — path to persistent state directory
#   MODEL             — Claude model to use (optional)
#   _global_activity  — 0 or 1 (from activity.sh)
#   _global_reason    — human-readable reason (from activity.sh)
#   _all_worker_prs   — "branch number" pairs (from activity.sh)
#   _open_pr_count    — count of open worker PRs (from activity.sh)
#
# Requires: prompt-assembly.sh and activity.sh to be sourced first

run_agents() {
    local _any_agent_ran=0
    local _any_agent_failed=0
    local _agent_results=""
    local TODAY
    TODAY=$(date +%Y-%m-%d)

    for _agent in $AGENTS; do
        echo ""
        echo "[fleet] ── Agent: $_agent ────────────────────────────────────────────"

        # ── Find this agent's existing open PR ───────────────────────────
        local _agent_pr=""
        local _agent_pr_branch=""
        if [ -n "$_all_worker_prs" ]; then
            _agent_pr_branch=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $1}' || true)
            _agent_pr=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $2}' || true)
        fi

        # Use the existing PR's branch when responding to comments; today's date for new work
        local _agent_branch
        if [ -n "$_agent_pr_branch" ]; then
            _agent_branch="$_agent_pr_branch"
        else
            _agent_branch="worker/$_agent/$TODAY"
        fi

        local _agent_should_run=0
        local _agent_reason=""
        local _is_new_pr=0

        if [ -n "$_agent_pr" ]; then
            # PR exists — check for human comments or merge conflicts
            echo "[fleet]   Existing PR: #$_agent_pr"
            has_human_comments "$_agent_pr"
            if [ "$_has_comments" -eq 1 ]; then
                _agent_should_run=1
                _agent_reason="$_comment_reason"
            fi

            # Check for merge conflicts
            if [ "$_agent_should_run" -eq 0 ]; then
                local _mergeable
                _mergeable=$(gh api "repos/$TARGET_REPO/pulls/$_agent_pr" --jq '.mergeable // true' 2>/dev/null || echo "true")
                if [ "$_mergeable" = "false" ]; then
                    _agent_should_run=1
                    _agent_reason="merge conflicts on PR #$_agent_pr"
                else
                    echo "[fleet]   No human comments or merge conflicts on PR #$_agent_pr — skipping."
                fi
            fi
        else
            # No PR — run only if global activity signals fire
            _is_new_pr=1
            if [ "$_global_activity" -eq 1 ]; then
                if [ "$_open_pr_count" -ge "$MAX_OPEN_PRS" ]; then
                    echo "[fleet]   Would create new PR but max_open_prs cap ($MAX_OPEN_PRS) reached — skipping."
                else
                    _agent_should_run=1
                    _agent_reason="$_global_reason (new work)"
                fi
            else
                echo "[fleet]   No existing PR and no global activity — skipping."
            fi
        fi

        if [ "$_agent_should_run" -eq 0 ]; then
            _agent_results="${_agent_results}  $_agent: skipped\n"
            continue
        fi

        echo "[fleet]   Running: $_agent_reason"

        # ── Export per-agent environment variables ────────────────────────
        export AGENT_NAME="$_agent"
        export AGENT_BRANCH="$_agent_branch"
        if [ -n "$_agent_pr" ]; then
            export WORKER_PR_NUMBER="$_agent_pr"
        else
            unset WORKER_PR_NUMBER 2>/dev/null || true
        fi

        # ── Assemble the prompt from tasks + agent manifest ──────────────
        local _prompt
        _prompt="$(assemble_prompt "$_agent")"

        local _agent_log="$STATE_DIR/$_agent-last-run.log"

        # ── Invoke Claude CLI ────────────────────────────────────────────
        set +e
        if [ -n "$MODEL" ]; then
            echo "[fleet]   Model: $MODEL"
            claude --dangerously-skip-permissions --model "$MODEL" \
                -p "$_prompt" 2>&1 | tee "$_agent_log"
        else
            claude --dangerously-skip-permissions \
                -p "$_prompt" 2>&1 | tee "$_agent_log"
        fi
        local _agent_exit=${PIPESTATUS[0]}
        set -e

        if [ "$_agent_exit" -ne 0 ]; then
            echo "[fleet]   Agent '$_agent' exited with code $_agent_exit"
            if grep -qE "Not logged in|401|authentication_error|Invalid authentication" "$_agent_log" 2>/dev/null; then
                echo "[fleet] ────────────────────────────────────────────────────────────────"
                echo "[fleet] ERROR: Claude authentication failed."
                echo "[fleet]        Subscription OAuth tokens expire and cannot be refreshed"
                echo "[fleet]        in a headless container (no browser available)."
                echo "[fleet]"
                echo "[fleet]        To fix: use API key mode for containers:"
                echo "[fleet]          docker run -e ANTHROPIC_API_KEY=sk-ant-... ..."
                echo "[fleet] ────────────────────────────────────────────────────────────────"
                # Auth failure is fatal — remaining agents will fail too
                exit "$_agent_exit"
            fi
            _any_agent_failed=1
            _agent_results="${_agent_results}  $_agent: FAILED (exit $_agent_exit)\n"
        else
            _any_agent_ran=1
            # Check if the agent actually opened a new PR
            if [ "$_is_new_pr" -eq 1 ]; then
                local _new_pr_check
                _new_pr_check=$(gh pr list \
                    --repo "$TARGET_REPO" \
                    --state open \
                    --json number,headRefName \
                    --jq ".[] | select(.headRefName == \"$_agent_branch\") | .number" \
                    2>/dev/null || true)
                if [ -n "$_new_pr_check" ]; then
                    _open_pr_count=$(( _open_pr_count + 1 ))
                fi
            fi
            _agent_results="${_agent_results}  $_agent: OK\n"
        fi

        # ── Write state file ─────────────────────────────────────────────
        write_agent_state "$_agent" "$_agent_exit" "$_agent_branch"

        echo "[fleet]   Agent '$_agent' complete. Log: $_agent_log"
    done

    # ── Write coordination state ─────────────────────────────────────────
    write_coordination_state "$_agent_results"

    # ── Summary ──────────────────────────────────────────────────────────
    echo ""
    echo "[fleet] ────────────────────────────────────────────────────────────────"
    echo "[fleet] Run complete. Agent results:"
    echo -e "$_agent_results"
    echo "[fleet] ────────────────────────────────────────────────────────────────"

    if [ "$_any_agent_failed" -ne 0 ]; then
        return 1
    fi
    return 0
}

# ── Write per-agent state file to .agents/{name}/state.json ──────────────
write_agent_state() {
    local agent_name="$1"
    local exit_code="$2"
    local branch="$3"
    local agent_workspace
    agent_workspace=$(get_agent_header "$AGENT_DIR/$agent_name.md" "Workspace")

    [ -z "$agent_workspace" ] && return 0

    local state_dir="$WORKSPACE/$agent_workspace"
    mkdir -p "$state_dir"

    local result="ok"
    [ "$exit_code" -ne 0 ] && result="failed"

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Find owned PRs for this agent
    local owned_prs="[]"
    if [ -n "$_all_worker_prs" ]; then
        owned_prs=$(echo "$_all_worker_prs" | grep "^worker/$agent_name/" | awk '{print $2}' | jq -R -s 'split("\n") | map(select(. != "") | tonumber)' 2>/dev/null || echo "[]")
    fi

    cat > "$state_dir/state.json" << EOF
{
  "last_run": "$now",
  "result": "$result",
  "owned_prs": $owned_prs,
  "branch": "$branch"
}
EOF
}

# ── Write coordination state to .agents/coordination.json ────────────────
write_coordination_state() {
    local agent_results="$1"
    local coord_file="$WORKSPACE/.agents/coordination.json"

    [ ! -d "$WORKSPACE/.agents" ] && return 0

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Parse agent results into ran/skipped lists
    local ran_agents skipped_agents
    ran_agents=$(echo -e "$agent_results" | grep ': OK' | awk '{print $1}' | tr -d ':' | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
    skipped_agents=$(echo -e "$agent_results" | grep ': skipped' | awk '{print $1}' | tr -d ':' | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")

    # Build open_prs map
    local open_prs="{}"
    if [ -n "$_all_worker_prs" ]; then
        open_prs=$(echo "$_all_worker_prs" | awk -F'/' '{split($3, a, " "); agent=$2; pr=a[2]; print agent, pr}' | jq -R -s '
            split("\n") | map(select(. != "") | split(" ") | {(.[0]): (.[1] | tonumber)}) | add // {}
        ' 2>/dev/null || echo "{}")
    fi

    cat > "$coord_file" << EOF
{
  "last_run": "$now",
  "agents_ran": $ran_agents,
  "agents_skipped": $skipped_agents,
  "open_prs": $open_prs
}
EOF
}
