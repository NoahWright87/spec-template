#!/usr/bin/env bash
# activity.sh — Detect activity signals in the target repo
#
# These signals indicate new work exists. Individual agents decide
# whether to run based on their own PR state plus these global signals.
#
# "Human" = GitHub user type is "User" AND body does NOT start with 🤖.
#
# Required globals:
#   TARGET_REPO — owner/repo string
#
# Sets:
#   _global_activity — 0 or 1
#   _global_reason   — human-readable reason

# ── Human comment detection filters ─────────────────────────────────────
_human_filter='[.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))] | length'
_human_filter_reviews='[.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not) and (.line != null))] | length'

# ── Check for global activity signals ───────────────────────────────────
check_global_activity() {
    echo "[fleet] Checking global activity signals..."
    _global_activity=0
    _global_reason=""

    # Signal A — open issues with no intake label
    local _unprocessed
    _unprocessed=$(gh issue list \
        --repo "$TARGET_REPO" \
        --state open \
        --json number,labels \
        --jq '[.[] | select(
            (.labels | map(.name) |
                (contains(["intake:filed"]) or contains(["intake:rejected"]) or contains(["intake:ignore"]))
            ) | not
        )] | length' 2>/dev/null || echo "0")
    if [ "${_unprocessed:-0}" -gt 0 ]; then
        _global_activity=1
        _global_reason="${_unprocessed} unprocessed issue(s)"
    fi

    # Signal B — filed issue with human as the most recent commenter
    if [ "$_global_activity" -eq 0 ]; then
        local _filed
        _filed=$(gh issue list \
            --repo "$TARGET_REPO" \
            --state open \
            --label "intake:filed" \
            --json number \
            --jq '.[].number' 2>/dev/null || echo "")
        for _inum in $_filed; do
            local _last
            _last=$(gh api "repos/$TARGET_REPO/issues/$_inum/comments" \
                --jq 'if length == 0 then "empty"
                      elif (last | .user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))
                      then "human"
                      else "robot"
                      end' 2>/dev/null || echo "robot")
            if [ "$_last" = "human" ]; then
                _global_activity=1
                _global_reason="human comment on filed issue #${_inum}"
                break
            fi
        done
    fi

    if [ "$_global_activity" -eq 1 ]; then
        echo "[fleet] Global activity: $_global_reason"
    else
        echo "[fleet] No global activity signals."
    fi
}

# ── Enumerate all open worker/* PRs ─────────────────────────────────────
# Sets:
#   _all_worker_prs  — "branch number" pairs, one per line
#   _open_pr_count   — count of open worker PRs
enumerate_worker_prs() {
    _all_worker_prs=$(gh pr list \
        --repo "$TARGET_REPO" \
        --state open \
        --json number,headRefName \
        --jq '.[] | select(.headRefName | startswith("worker/")) | "\(.headRefName) \(.number)"' \
        2>/dev/null || true)
    _open_pr_count=0
    if [ -n "$_all_worker_prs" ]; then
        _open_pr_count=$(printf '%s\n' "$_all_worker_prs" | grep -c .)
    fi
    echo "[fleet] Open worker PRs: $_open_pr_count / $MAX_OPEN_PRS"
}

# ── Check if a PR has human comments ────────────────────────────────────
# Usage: has_human_comments PR_NUMBER → sets _has_comments=1 if found
has_human_comments() {
    local pr_num="$1"
    _has_comments=0
    _comment_reason=""

    # Check issue comments (general PR conversation)
    local n
    n=$(gh api "repos/$TARGET_REPO/issues/$pr_num/comments" \
        --jq "$_human_filter" 2>/dev/null || echo "0")
    if [ "${n:-0}" -gt 0 ]; then
        _has_comments=1
        _comment_reason="${n} human comment(s) on PR #$pr_num"
        return
    fi

    # Check PR review comments (inline code comments, excluding outdated)
    n=$(gh api "repos/$TARGET_REPO/pulls/$pr_num/comments" \
        --jq "$_human_filter_reviews" 2>/dev/null || echo "0")
    if [ "${n:-0}" -gt 0 ]; then
        _has_comments=1
        _comment_reason="${n} human review comment(s) on PR #$pr_num"
    fi
}
