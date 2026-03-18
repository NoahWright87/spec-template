#!/usr/bin/env bash
# Worker entrypoint — executed on each cron iteration.
#
# Flow: validate env → authenticate → clone/update target repo
#         → detect scaffold → install mode OR operate mode → exit
#
# Install mode: scaffold not found in target repo
#   → copy dist/ payload, create branch, open bootstrap PR, exit
#
# Operate mode: scaffold found in target repo
#   → read .claude/worker-config.yaml for agent list + limits
#   → check global activity signals (issues, comments)
#   → for each declared agent: check per-agent PR state, run Claude CLI
#   → each agent gets its own branch (worker/{name}/YYYY-MM-DD) and PR
#
# Legacy mode: if the repo provides .claude/worker-instructions.md, the entrypoint
# falls back to the old single-invocation mode (one branch, one PR).
#
# State that should survive between runs (logs) lives in /worker/state (volume).

set -euo pipefail

# ── Required environment validation ───────────────────────────────────────────
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${TARGET_REPO:?TARGET_REPO is required}"

# ── Optional parameters with defaults ─────────────────────────────────────────
TARGET_BRANCH="${TARGET_BRANCH:-main}"
CLAUDE_CONFIG_PATH="${CLAUDE_CONFIG_PATH:-.claude}"
# MODEL: Claude model to use (e.g., claude-opus-4-6, claude-sonnet-4-5, claude-haiku-4-5)
# If not set, Claude CLI will use its default model selection
MODEL="${MODEL:-}"

# ── Auth mode detection ────────────────────────────────────────────────────────
# Two supported modes:
#   API key:      Set ANTHROPIC_API_KEY. Uses the Anthropic API directly (pay-per-token).
#                 Optionally set ANTHROPIC_BASE_URL to target a custom endpoint (enterprise proxy).
#   Subscription: Omit ANTHROPIC_API_KEY. Mount ~/.claude from the host so the Claude
#                 Code CLI can find the OAuth credentials from `claude login`.
#                 e.g. docker run -v ~/.claude:/home/worker/.claude:ro ...
#                 IMPORTANT: credentials must be stored as files in ~/.claude/.credentials.json.
#                 If `claude login` stored tokens in your OS keychain (macOS/Windows default),
#                 the file won't be present — use API key mode instead.
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[worker] Auth mode: API key"
    if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
        echo "[worker] Using custom API endpoint: $ANTHROPIC_BASE_URL"
    fi
else
    echo "[worker] Auth mode: Claude Code subscription (expecting mounted ~/.claude credentials)"
    if [ ! -f "$HOME/.claude/.credentials.json" ]; then
        echo "[worker] ERROR: Subscription credentials not found at \$HOME/.claude/.credentials.json"
        echo "[worker]        On macOS/Windows, 'claude login' stores tokens in the OS keychain,"
        echo "[worker]        not as a file — use API key mode instead:"
        echo "[worker]          docker run -e ANTHROPIC_API_KEY=<key> ..."
        echo "[worker]        Or if credentials are file-based, mount the directory:"
        echo "[worker]          docker run -v ~/.claude:/home/worker/.claude:ro ..."
        exit 1
    fi
fi

# ── Write Claude settings with full tool permissions ──────────────────────────
# The Claude CLI requires ~/.claude/settings.json to start, even in API key mode.
# We also need explicit permissions.allow entries — --dangerously-skip-permissions
# bypasses interactive prompts but does NOT unblock tools missing from the allow list.
#
# Always overwrite (not just create-if-absent) so that a settings.json copied or
# mounted from a host machine (which won't have the worker's Bash(*) allow rules)
# doesn't leave Claude's tools blocked.
#
# If ~/.claude is mounted read-only (subscription mode: -v ~/.claude:/home/worker/.claude:ro)
# the write will fail silently — the user is responsible for permissions in that case.
mkdir -p "$HOME/.claude"
if cat > "$HOME/.claude/settings.json" << 'SETTINGS_EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "MultiEdit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)"
    ],
    "deny": []
  }
}
SETTINGS_EOF
then
    echo "[worker] Wrote ~/.claude/settings.json with full tool permissions for headless operation."
else
    echo "[worker] WARNING: Could not write ~/.claude/settings.json (read-only mount?)."
    echo "[worker]          Ensure your mounted settings.json includes Bash(*), Read(*), Write(*), etc."
    echo "[worker]          in permissions.allow — otherwise Claude will report tools as blocked."
fi

# ── Ensure Claude's session-env directory is writable ─────────────────────────
# Claude Code stores per-session state in ~/.claude/session-env/<uuid>/ at runtime.
# If a previous container run executed as root (before the non-root user was added),
# it may have left this directory owned by root with 755 permissions, causing:
#   EACCES: permission denied, mkdir '~/.claude/session-env/<uuid>'
# This blocks the Bash tool and all shell operations for the entire Claude run.
mkdir -p "$HOME/.claude/session-env" 2>/dev/null || true
if [ ! -w "$HOME/.claude/session-env" ]; then
    echo "[worker] ────────────────────────────────────────────────────────────────"
    echo "[worker] ERROR: ~/.claude/session-env is not writable by '$(whoami)' (uid=$(id -u))."
    echo "[worker]        A previous container run as root left it with wrong ownership."
    echo "[worker]        One-time fix: delete it on the Docker host, then re-run."
    echo "[worker]"
    echo "[worker]          Windows:    rd /s /q C:\\.claude\\session-env"
    echo "[worker]          Linux/Mac:  rm -rf ~/.claude/session-env"
    echo "[worker]"
    echo "[worker]        Claude will recreate the directory with correct ownership on the next run."
    echo "[worker] ────────────────────────────────────────────────────────────────"
    exit 1
fi

# ── Pre-flight checks ─────────────────────────────────────────────────────────
# Verify everything the worker needs BEFORE invoking Claude, so failures are
# caught immediately without spending API tokens on work that can't be committed.
echo "[worker] Running pre-flight checks..."

# 0. Claude API: validate model access (if MODEL is specified)
if [ -n "$MODEL" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[worker] Validating model access: $MODEL"
    set +e
    _model_test=$(curl -s -w "\n%{http_code}" -X POST "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{\"model\":\"$MODEL\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"test\"}]}" 2>&1)
    _http_code=$(echo "$_model_test" | tail -1)
    _response=$(echo "$_model_test" | sed '$d')
    set -e

    if [ "$_http_code" = "401" ]; then
        echo "[worker] PREFLIGHT FAIL: Model '$MODEL' is not accessible with this API key."
        echo "[worker]"
        echo "[worker] API response:"
        echo "$_response" | jq -r '.' 2>/dev/null || echo "$_response" | sed 's/^/[worker]   /'
        echo "[worker]"
        echo "[worker] Troubleshooting:"
        echo "[worker]   • Verify MODEL='$MODEL' is correct"
        echo "[worker]   • Check if your API key has access to this model"
        echo "[worker]   • Try omitting MODEL to use the default model"
        exit 1
    elif [ "$_http_code" != "200" ]; then
        echo "[worker] WARNING: Model validation returned HTTP $_http_code (proceeding anyway)"
    else
        echo "[worker] ✓ Model '$MODEL' is accessible"
    fi
elif [ -n "$MODEL" ]; then
    echo "[worker] ⚠ MODEL specified but skipping validation (subscription mode)"
fi

# 1. GitHub token: repo access + push permission (one API call, jq is installed)
set +e  # Temporarily disable errexit so we can capture the error
_gh_response=$(gh api "repos/$TARGET_REPO" --jq '.permissions.push // "unknown"' 2>&1)
_gh_exit_code=$?
set -e  # Re-enable errexit
if [ $_gh_exit_code -ne 0 ]; then
    echo "[worker] PREFLIGHT FAIL: Cannot access '$TARGET_REPO' with the supplied GITHUB_TOKEN."
    echo "[worker]"
    echo "[worker] GitHub API error:"
    echo "$_gh_response" | sed 's/^/[worker]   /'
    echo "[worker]"
    echo "[worker] Troubleshooting:"
    echo "[worker]   • Verify GITHUB_TOKEN is valid and not expired"
    echo "[worker]   • Verify the token has 'repo' scope (classic) or 'contents:read/write' (fine-grained)"
    echo "[worker]   • Verify TARGET_REPO='$TARGET_REPO' is correct (owner/repo format)"
    echo "[worker]   • If the repo is private, ensure the token has access to it"
    exit 1
fi
_push="$_gh_response"
case "$_push" in
    "true")
        echo "[worker] ✓ GitHub: '$TARGET_REPO' accessible, push permission confirmed."
        ;;
    "false")
        echo "[worker] PREFLIGHT FAIL: GITHUB_TOKEN lacks push access to '$TARGET_REPO'."
        echo "[worker]   The worker creates branches and opens PRs — write access is required."
        echo "[worker]   Grant write access (classic PAT: 'repo' scope; fine-grained: 'contents:write')."
        exit 1
        ;;
    *)
        # Fine-grained PATs sometimes omit the permissions object; warn and proceed.
        echo "[worker] ⚠ Push permission unverifiable (fine-grained PAT?). Proceeding — a"
        echo "[worker]   push failure will surface later if the token lacks write access."
        ;;
esac

# 2. Claude CLI binary
if ! command -v claude > /dev/null 2>&1; then
    echo "[worker] PREFLIGHT FAIL: 'claude' CLI not found in PATH."
    echo "[worker]   This indicates a broken container image. Rebuild: docker compose build worker"
    exit 1
fi
echo "[worker] ✓ Claude CLI present: $(claude --version 2>&1 | head -1 || echo 'version unknown')"

echo "[worker] Pre-flight checks passed."

WORKSPACE="/worker/workspace"
DIST_DIR="/worker/dist"
STATE_DIR="/worker/state"
LOG_FILE="$STATE_DIR/last-run.log"

# Scaffold detection marker — presence of this file means the scaffold is installed.
# specs/AGENTS.md is distinctive to the scaffold and not found in unscaffolded repos.
SCAFFOLD_MARKER="specs/AGENTS.md"

echo "[worker] ────────────────────────────────────────────────────────────────"
echo "[worker] Starting run — $TARGET_REPO @ $TARGET_BRANCH"
echo "[worker] ────────────────────────────────────────────────────────────────"

# ── Runtime diagnostics ────────────────────────────────────────────────────────
echo "[worker] User:     $(whoami) (uid=$(id -u) gid=$(id -g))"
echo "[worker] Home:     $HOME"
echo "[worker] Creds:    $([ -f "$HOME/.claude/.credentials.json" ] \
    && echo "found ($(wc -c < "$HOME/.claude/.credentials.json") bytes)" \
    || echo "NOT FOUND at $HOME/.claude/.credentials.json")"
echo "[worker] Settings: $([ -f "$HOME/.claude/settings.json" ] \
    && echo "found" \
    || echo "NOT FOUND — will be created")"

# ── Authenticate GitHub CLI and git ───────────────────────────────────────────
# gh CLI automatically uses GITHUB_TOKEN from the environment for API calls.
# Configure git's credential helper so HTTPS git operations (push/pull) also use it.
#
# WHY scope to https://github.com: a global credential helper sends GITHUB_TOKEN
# to every HTTPS host git contacts (mirrors, submodule servers, etc.), which would
# silently leak the token to any server the worker clones from.
git config --global 'credential.https://github.com.helper' \
    '!f() { echo "username=x-access-token"; echo "password=$GITHUB_TOKEN"; }; f'
echo "[worker] GitHub auth configured (GITHUB_TOKEN → gh CLI + git credential helper, scoped to github.com)."

# ── Clone or update the target repository ─────────────────────────────────────
if [ -d "$WORKSPACE/.git" ]; then
    echo "[worker] Updating existing clone of $TARGET_REPO..."
    git -C "$WORKSPACE" fetch origin
    git -C "$WORKSPACE" checkout "$TARGET_BRANCH"
    git -C "$WORKSPACE" reset --hard "origin/$TARGET_BRANCH"
else
    echo "[worker] Cloning $TARGET_REPO..."
    gh repo clone "$TARGET_REPO" "$WORKSPACE" -- --branch "$TARGET_BRANCH"
fi

# ── Configure git identity for any commits the worker makes ───────────────────
git -C "$WORKSPACE" config user.name  "spec-template worker"
git -C "$WORKSPACE" config user.email "worker@spec-template"

# ── Scaffold detection ─────────────────────────────────────────────────────────
if [ -f "$WORKSPACE/$SCAFFOLD_MARKER" ]; then
    echo "[worker] Scaffold detected ($SCAFFOLD_MARKER present) — operate mode."
    WORKER_MODE="operate"
else
    echo "[worker] No scaffold detected ($SCAFFOLD_MARKER absent) — install mode."
    WORKER_MODE="install"
fi

# ══ Install mode ═══════════════════════════════════════════════════════════════
# Used when the target repo has not yet adopted the spec-template scaffold.
# Copies the dist/ payload, opens a bootstrap PR, then exits.
# The next cron run will find the scaffold (once the PR is merged) and operate normally.

if [ "$WORKER_MODE" = "install" ]; then
    BRANCH="scaffold/bootstrap"

    # Check for an already-open bootstrap PR to avoid creating duplicates on repeated runs
    existing_pr=$(gh pr list --repo "$TARGET_REPO" --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || true)
    if [ -n "$existing_pr" ]; then
        echo "[worker] Bootstrap PR #$existing_pr already open — skipping. Run complete."
        exit 0
    fi

    # Clean up any stale local/remote branch left over from a previous closed attempt
    if git -C "$WORKSPACE" show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "[worker] Removing stale local branch $BRANCH..."
        git -C "$WORKSPACE" branch -D "$BRANCH"
    fi
    if git -C "$WORKSPACE" ls-remote --exit-code --heads origin "$BRANCH" > /dev/null 2>&1; then
        echo "[worker] Removing stale remote branch $BRANCH..."
        git -C "$WORKSPACE" push origin --delete "$BRANCH"
    fi

    echo "[worker] Creating branch: $BRANCH"
    git -C "$WORKSPACE" checkout -b "$BRANCH"

    echo "[worker] Copying scaffold from $DIST_DIR (non-destructive — existing files preserved)..."
    rsync -a --ignore-existing "$DIST_DIR/" "$WORKSPACE/"

    echo "[worker] Committing scaffold files..."
    git -C "$WORKSPACE" add .
    git -C "$WORKSPACE" commit -m "Install spec-template scaffold

Installed by the spec-template autonomous worker.
Source: https://github.com/NoahWright87/spec-template"

    echo "[worker] Pushing branch..."
    git -C "$WORKSPACE" push origin "$BRANCH"

    echo "[worker] Opening bootstrap PR..."
    gh pr create \
        --repo "$TARGET_REPO" \
        --title "Install spec-template scaffold" \
        --base "$TARGET_BRANCH" \
        --head "$BRANCH" \
        --body "## Install spec-template scaffold

This PR was opened automatically by the [spec-template](https://github.com/NoahWright87/spec-template) autonomous worker.

### What was installed

The following files were copied from the \`dist/\` payload of the spec-template repo:

- \`.claude/commands/\` — slash commands: \`/respec\`, \`/intake\`, \`/knock-out-todos\`, \`/spec-backfill\`, \`/refine\`, \`/pr-review\`
- \`specs/\` — starter spec directory (templates, ideas intake, agent instructions)
- \`.github/workflows/spec-check.yml\` — PR check that warns when source changes lack spec updates

### What to do next

1. **Review and merge this PR** — the scaffold is safe to add to any repo.
2. After merging, **run \`/respec\`** in your AI assistant to confirm the install and customise the templates for your project.
3. The worker will automatically switch to operate mode on the next run, processing GitHub issues and implementing TODOs.

### Source of truth

The scaffold source lives at [NoahWright87/spec-template](https://github.com/NoahWright87/spec-template).
Run \`/respec\` at any time to pull in updates from the source repo."

    echo "[worker] Bootstrap PR opened. Run complete."
    exit 0
fi

# ══ Operate mode ═══════════════════════════════════════════════════════════════
# Multi-agent architecture: reads .claude/worker-config.yaml from the target repo
# to determine which agents to run. Each agent gets its own branch, PR, and Claude session.
#
# Backward compatibility: if the repo provides .claude/worker-instructions.md, the
# entrypoint falls back to the legacy single-invocation mode (one branch, one PR).

cd "$WORKSPACE"

# ── Read worker-config.yaml ──────────────────────────────────────────────────
WORKER_CONFIG="$WORKSPACE/$CLAUDE_CONFIG_PATH/worker-config.yaml"
AGENT_DIR="/worker/agents"

if [ -f "$WORKER_CONFIG" ]; then
    echo "[worker] Reading worker config: $WORKER_CONFIG"
    MAX_OPEN_PRS=$(yq '.max_open_prs // 1' "$WORKER_CONFIG")
    # Read agents as newline-separated list
    AGENTS=$(yq '.agents[]' "$WORKER_CONFIG" 2>/dev/null || echo "")
else
    echo "[worker] No worker-config.yaml found — using defaults."
    MAX_OPEN_PRS=1
    AGENTS="intake
knock-out-todos"
fi

if [ -z "$AGENTS" ]; then
    AGENTS="intake
knock-out-todos"
fi

echo "[worker] Max open PRs: $MAX_OPEN_PRS"
echo "[worker] Agents: $(echo "$AGENTS" | tr '\n' ' ')"

# ── Verify agent instruction files exist ─────────────────────────────────────
_missing=0
for _agent in $AGENTS; do
    if [ ! -f "$AGENT_DIR/$_agent.md" ]; then
        echo "[worker] PREFLIGHT FAIL: Agent instruction file not found: $AGENT_DIR/$_agent.md"
        _missing=1
    fi
done
if [ "$_missing" -ne 0 ]; then
    echo "[worker]   Available agents: $(ls "$AGENT_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | tr '\n' ' ')"
    echo "[worker]   Check worker-config.yaml agent names match files in $AGENT_DIR/"
    exit 1
fi

# Verify command files for built-in agents that reference them
for _agent in $AGENTS; do
    case "$_agent" in
        intake|knock-out-todos)
            _cmd_file="$WORKSPACE/$CLAUDE_CONFIG_PATH/commands/lib/$_agent.md"
            if [ ! -f "$_cmd_file" ]; then
                echo "[worker] PREFLIGHT FAIL: Required command file not found: $_cmd_file"
                _missing=1
            fi
            ;;
    esac
done
if [ "$_missing" -ne 0 ]; then
    echo "[worker]   The scaffold may be incomplete. Possible fixes:"
    echo "[worker]     • Wait for the bootstrap PR to be merged if it's still open."
    echo "[worker]     • Run /respec in the target repo to restore missing scaffold files."
    exit 1
fi
echo "[worker] ✓ All agent files and required command files verified."

# ── Global activity signals (checked once) ───────────────────────────────────
# These signals indicate new work exists in the repo. Individual agents decide
# whether to run based on their own PR state plus these global signals.
#
# "Human" = GitHub user type is "User" AND body does NOT start with 🤖.
echo "[worker] Checking global activity signals..."
_global_activity=0
_global_reason=""

# Signal A — open issues with no intake label
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
    _filed=$(gh issue list \
        --repo "$TARGET_REPO" \
        --state open \
        --label "intake:filed" \
        --json number \
        --jq '.[].number' 2>/dev/null || echo "")
    for _inum in $_filed; do
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
    echo "[worker] Global activity: $_global_reason"
else
    echo "[worker] No global activity signals."
fi

# ── Enumerate all open worker/* PRs ──────────────────────────────────────────
# Get all open PRs with branches matching worker/*/* to count against max_open_prs
# and to find per-agent PRs.
_all_worker_prs=$(gh pr list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,headRefName \
    --jq '.[] | select(.headRefName | startswith("worker/")) | "\(.headRefName) \(.number)"' \
    2>/dev/null || true)
_open_pr_count=$(printf '%s' "$_all_worker_prs" | grep -c . 2>/dev/null || true)
echo "[worker] Open worker PRs: $_open_pr_count / $MAX_OPEN_PRS"

# ── Human comment detection helpers ──────────────────────────────────────────
_human_filter='[.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))] | length'
_human_filter_reviews='[.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not) and (.line != null or .position != null))] | length'

# ── Helper: check if a PR has human comments ─────────────────────────────────
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

# ── Per-agent loop ───────────────────────────────────────────────────────────
_any_agent_ran=0
_any_agent_failed=0
_agent_results=""
TODAY=$(date +%Y-%m-%d)

for _agent in $AGENTS; do
    echo ""
    echo "[worker] ── Agent: $_agent ────────────────────────────────────────────"

    # Find this agent's existing open PR (branch pattern: worker/{agent-name}/*)
    _agent_pr=""
    _agent_pr_branch=""
    if [ -n "$_all_worker_prs" ]; then
        _agent_pr_branch=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $1}' || true)
        _agent_pr=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $2}' || true)
    fi

    # Use the existing PR's branch when responding to comments; today's date for new work
    if [ -n "$_agent_pr_branch" ]; then
        _agent_branch="$_agent_pr_branch"
    else
        _agent_branch="worker/$_agent/$TODAY"
    fi

    _agent_should_run=0
    _agent_reason=""
    _is_new_pr=0

    if [ -n "$_agent_pr" ]; then
        # PR exists — check for human comments or merge conflicts
        echo "[worker]   Existing PR: #$_agent_pr"
        has_human_comments "$_agent_pr"
        if [ "$_has_comments" -eq 1 ]; then
            _agent_should_run=1
            _agent_reason="$_comment_reason"
        fi

        # Check for merge conflicts (mergeable=false means conflicts exist)
        if [ "$_agent_should_run" -eq 0 ]; then
            _mergeable=$(gh api "repos/$TARGET_REPO/pulls/$_agent_pr" --jq '.mergeable // true' 2>/dev/null || echo "true")
            if [ "$_mergeable" = "false" ]; then
                _agent_should_run=1
                _agent_reason="merge conflicts on PR #$_agent_pr"
            else
                echo "[worker]   No human comments or merge conflicts on PR #$_agent_pr — skipping."
            fi
        fi
    else
        # No PR — run only if global activity signals fire
        _is_new_pr=1
        if [ "$_global_activity" -eq 1 ]; then
            # Check max_open_prs cap before allowing a new PR
            if [ "$_open_pr_count" -ge "$MAX_OPEN_PRS" ]; then
                echo "[worker]   Would create new PR but max_open_prs cap ($MAX_OPEN_PRS) reached — skipping."
            else
                _agent_should_run=1
                _agent_reason="$_global_reason (new work)"
            fi
        else
            echo "[worker]   No existing PR and no global activity — skipping."
        fi
    fi

    if [ "$_agent_should_run" -eq 0 ]; then
        _agent_results="${_agent_results}  $_agent: skipped\n"
        continue
    fi

    echo "[worker]   Running: $_agent_reason"

    # Export per-agent environment variables
    export AGENT_NAME="$_agent"
    export AGENT_BRANCH="$_agent_branch"
    if [ -n "$_agent_pr" ]; then
        export WORKER_PR_NUMBER="$_agent_pr"
    else
        unset WORKER_PR_NUMBER 2>/dev/null || true
    fi

    # Each agent file is self-contained: it references the common preamble
    # and completion files via Read instructions for Claude.
    _prompt="$(cat "$AGENT_DIR/$_agent.md")"

    _agent_log="$STATE_DIR/$_agent-last-run.log"

    set +e
    if [ -n "$MODEL" ]; then
        echo "[worker]   Model: $MODEL"
        claude --dangerously-skip-permissions --model "$MODEL" \
            -p "$_prompt" 2>&1 | tee "$_agent_log"
    else
        claude --dangerously-skip-permissions \
            -p "$_prompt" 2>&1 | tee "$_agent_log"
    fi
    _agent_exit=${PIPESTATUS[0]}
    set -e

    if [ "$_agent_exit" -ne 0 ]; then
        echo "[worker]   Agent '$_agent' exited with code $_agent_exit"
        if grep -qE "Not logged in|401|authentication_error|Invalid authentication" "$_agent_log" 2>/dev/null; then
            echo "[worker] ────────────────────────────────────────────────────────────────"
            echo "[worker] ERROR: Claude authentication failed."
            echo "[worker]        Subscription OAuth tokens expire and cannot be refreshed"
            echo "[worker]        in a headless container (no browser available)."
            echo "[worker]"
            echo "[worker]        To fix: use API key mode for containers:"
            echo "[worker]          docker run -e ANTHROPIC_API_KEY=sk-ant-... ..."
            echo "[worker] ────────────────────────────────────────────────────────────────"
            # Auth failure is fatal — no point running remaining agents
            exit "$_agent_exit"
        fi
        _any_agent_failed=1
        _agent_results="${_agent_results}  $_agent: FAILED (exit $_agent_exit)\n"
    else
        _any_agent_ran=1
        # If this agent created a new PR, increment the count for subsequent agents
        if [ "$_is_new_pr" -eq 1 ]; then
            _open_pr_count=$(( _open_pr_count + 1 ))
        fi
        _agent_results="${_agent_results}  $_agent: OK\n"
    fi

    echo "[worker]   Agent '$_agent' complete. Log: $_agent_log"
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "[worker] ────────────────────────────────────────────────────────────────"
echo "[worker] Run complete. Agent results:"
echo -e "$_agent_results"
echo "[worker] ────────────────────────────────────────────────────────────────"

if [ "$_any_agent_failed" -ne 0 ]; then
    exit 1
fi
