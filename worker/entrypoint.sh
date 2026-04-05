#!/usr/bin/env bash
# Worker entrypoint — executed on each cron iteration.
#
# Flow: validate env → authenticate → clone/update target repo
#         → detect scaffold → install mode OR operate mode → exit
#
# Install mode: scaffold not found in target repo
#   → copy spec templates from agents/templates/, create branch, open bootstrap PR, exit
#
# Operate mode: scaffold found in target repo
#   → read .agents/config.yaml for agent list + limits
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
: "${TARGET_REPO:?TARGET_REPO is required}"

# ── GitHub auth mode detection ───────────────────────────────────────────────
# Priority:
#   1. GitHub App (GITHUB_APP_ID + GITHUB_APP_PRIVATE_KEY + GITHUB_APP_INSTALLATION_ID)
#      → generates a short-lived installation token and exports it as GH_TOKEN
#   2. PAT fallback (GH_TOKEN) — used if App vars are missing or token generation fails
#   3. Neither → fail with helpful error
#
# Both can be set simultaneously for safe rollout: the worker tries the App first
# and falls back to the PAT if anything goes wrong.
_GH_FALLBACK_TOKEN="${GH_TOKEN:-}"

if [ -n "${GITHUB_APP_ID:-}" ]; then
    if [ -z "${GITHUB_APP_PRIVATE_KEY:-}" ] || [ -z "${GITHUB_APP_INSTALLATION_ID:-}" ]; then
        echo "[worker] WARNING: GITHUB_APP_ID is set but GITHUB_APP_PRIVATE_KEY or"
        echo "[worker]          GITHUB_APP_INSTALLATION_ID is missing — cannot use GitHub App auth."
        if [ -n "$_GH_FALLBACK_TOKEN" ]; then
            echo "[worker] GitHub auth: falling back to PAT (GH_TOKEN)"
        fi
    else
        echo "[worker] GitHub auth: GitHub App (ID: $GITHUB_APP_ID, Installation: $GITHUB_APP_INSTALLATION_ID)"
        if _APP_TOKEN=$(node "$(dirname "$0")/scripts/github-app-token.mjs" 2>&1); then
            export GH_TOKEN="$_APP_TOKEN"
            echo "[worker] GitHub App installation token generated successfully (valid ~1 hour)."
        else
            echo "[worker] WARNING: GitHub App token generation failed:"
            echo "$_APP_TOKEN" | sed 's/^/[worker]   /'
            if [ -n "$_GH_FALLBACK_TOKEN" ]; then
                echo "[worker] GitHub auth: falling back to PAT (GH_TOKEN)"
                export GH_TOKEN="$_GH_FALLBACK_TOKEN"
            fi
        fi
    fi
fi

if [ -z "${GH_TOKEN:-}" ]; then
    echo "[worker] ERROR: No GitHub credentials available."
    echo "[worker]"
    echo "[worker] Option A — GitHub App (recommended):"
    echo "[worker]   Set GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, and GITHUB_APP_INSTALLATION_ID."
    echo "[worker]"
    echo "[worker] Option B — Personal Access Token:"
    echo "[worker]   Set GH_TOKEN to a classic PAT (repo scope) or fine-grained PAT (contents:write)."
    echo "[worker]"
    echo "[worker]   Both can be set for safe rollout — the App is tried first, PAT is the fallback."
    echo "[worker]   See .env.example for details."
    exit 1
fi

# ── Optional parameters with defaults ─────────────────────────────────────────
TARGET_BRANCH="${TARGET_BRANCH:-main}"
CLAUDE_CONFIG_PATH="${CLAUDE_CONFIG_PATH:-.claude}"
CURRENT_CONFIG_VERSION=2
# MODEL: Claude model to use (e.g., claude-opus-4-6, claude-sonnet-4-5, claude-haiku-4-5)
# If not set, Claude CLI will use its default model selection
MODEL="${MODEL:-}"
# WORKER_DEBUG: enable verbose diagnostic output for troubleshooting.
# Can be set via env var (takes priority) or settings.debug in .agents/config.yaml.
# The env var override is handy for one-off debugging without committing config changes.
WORKER_DEBUG="${WORKER_DEBUG:-}"

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

# ── Webhook notification helper ──────────────────────────────────────────────
# Posts a structured notification to all configured webhooks (always non-fatal).
# Args: $1=agent_name, $2=is_error ("true"/"false"), $3=message_body
webhook_notify() {
    local _sn_agent="$1" _sn_err="$2" _sn_msg="$3"
    local _sn_payload _sn_sent=0 _sn_wh
    _sn_payload=$(jq -n \
        --arg agent_name "$_sn_agent" \
        --arg is_error "$_sn_err" \
        --arg message_body "$_sn_msg" \
        --arg repo_name "$TARGET_REPO" \
        '{agent_name: $agent_name, is_error: $is_error, message_body: $message_body, repo_name: $repo_name}') || return 0
    for _sn_wh in "${NOTIFICATION_WEBHOOK:-}" "${REPO_NOTIFICATION_WEBHOOK:-}"; do
        [ -z "$_sn_wh" ] && continue
        if echo "$_sn_payload" | curl -sf -X POST \
                -H 'Content-type: application/json' \
                --data-binary @- \
                --connect-timeout 5 --max-time 10 \
                "$_sn_wh" > /dev/null 2>&1; then
            _sn_sent=$(( _sn_sent + 1 ))
        else
            echo "[worker]   WARNING: Webhook notification failed (non-fatal)"
        fi
    done
    [ "$_sn_sent" -gt 0 ] && echo "[worker]   Notification sent for $_sn_agent" || true
    return 0
}

# ── Auth mode detection ────────────────────────────────────────────────────────
# Two supported modes:
#   API key:      Set ANTHROPIC_API_KEY. Uses the Anthropic API directly (pay-per-token).
#                 Optionally set ANTHROPIC_BASE_URL to target a custom endpoint (enterprise proxy/gateway).
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
        echo "[worker]          docker run -e ANTHROPIC_API_KEY=sk-ant-... ..."
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
    echo "[worker] PREFLIGHT FAIL: Cannot access '$TARGET_REPO' with the current GitHub credentials."
    echo "[worker]"
    echo "[worker] GitHub API error:"
    echo "$_gh_response" | sed 's/^/[worker]   /'
    echo "[worker]"
    echo "[worker] Troubleshooting:"
    echo "[worker]   • If using a PAT: verify GH_TOKEN is valid and not expired"
    echo "[worker]   • If using a GitHub App: verify the app is installed on this repo"
    echo "[worker]   • Verify the token has 'repo' scope (classic PAT), 'contents:read/write' (fine-grained PAT),"
    echo "[worker]     or Contents + Issues + Pull Requests permissions (GitHub App)"
    echo "[worker]   • Verify TARGET_REPO='$TARGET_REPO' is correct (owner/repo format)"
    echo "[worker]   • If the repo is private, ensure the token/app has access to it"
    exit 1
fi
_push="$_gh_response"
case "$_push" in
    "true")
        echo "[worker] ✓ GitHub: '$TARGET_REPO' accessible, push permission confirmed."
        ;;
    "false")
        echo "[worker] PREFLIGHT FAIL: GitHub credentials lack push access to '$TARGET_REPO'."
        echo "[worker]   The worker creates branches and opens PRs — write access is required."
        echo "[worker]   Grant write access: classic PAT 'repo' scope, fine-grained PAT 'contents:write',"
        echo "[worker]   or GitHub App 'Contents: Read & Write' permission."
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
TEMPLATES_DIR="/worker/agents/templates"
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
# gh CLI automatically uses GH_TOKEN from the environment for API calls.
# Configure git's credential helper so HTTPS git operations (push/pull) also use it.
#
# WHY scope to https://github.com: a global credential helper sends GH_TOKEN
# to every HTTPS host git contacts (mirrors, submodule servers, etc.), which would
# silently leak the token to any server the worker clones from.
git config --global 'credential.https://github.com.helper' \
    '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
echo "[worker] GitHub auth configured (GH_TOKEN → gh CLI + git credential helper, scoped to github.com)."

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
# Detect via new .agents/config.yaml OR legacy specs/AGENTS.md marker.
if [ -f "$WORKSPACE/.agents/config.yaml" ]; then
    echo "[worker] Scaffold detected (.agents/config.yaml present) — operate mode."
    WORKER_MODE="operate"
elif [ -f "$WORKSPACE/$SCAFFOLD_MARKER" ]; then
    echo "[worker] Scaffold detected ($SCAFFOLD_MARKER present) — operate mode."
    WORKER_MODE="operate"
else
    echo "[worker] No scaffold detected (no .agents/config.yaml or $SCAFFOLD_MARKER) — install mode."
    WORKER_MODE="install"
fi

# ══ Install mode ═══════════════════════════════════════════════════════════════
# Used when the target repo has not yet adopted the spec-template scaffold.
# Copies spec templates from agents/templates/, opens a bootstrap PR, then exits.
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

    echo "[worker] Copying spec templates from $TEMPLATES_DIR (non-destructive — existing files preserved)..."
    mkdir -p "$WORKSPACE/specs/deps" "$WORKSPACE/.agents" "$WORKSPACE/.github/workflows"
    for f in spec.md spec.todo.md INTAKE.md AGENTS.md README.md; do
        [ ! -f "$WORKSPACE/specs/$f" ] && cp "$TEMPLATES_DIR/$f" "$WORKSPACE/specs/$f"
    done
    [ ! -f "$WORKSPACE/specs/deps/README.md" ] && cp "$TEMPLATES_DIR/deps-README.md" "$WORKSPACE/specs/deps/README.md"
    [ ! -f "$WORKSPACE/.agents/config.yaml" ] && cp "$TEMPLATES_DIR/config.yaml" "$WORKSPACE/.agents/config.yaml"
    [ ! -f "$WORKSPACE/.github/workflows/spec-check.yml" ] && cp "$TEMPLATES_DIR/spec-check.yml" "$WORKSPACE/.github/workflows/spec-check.yml"

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

- \`.agents/config.yaml\` — agent configuration (which agents to run, settings)
- \`specs/\` — starter spec directory (templates, ideas intake, agent instructions)
- \`.github/workflows/spec-check.yml\` — PR check that warns when source changes lack spec updates

### What to do next

1. **Review and merge this PR** — the scaffold is safe to add to any repo.
2. After merging, install the plugin: \`claude plugin install spec-template@NoahWright87/spec-template\`
3. Run \`/what-now\` to get started with intake and TODO processing.
4. The worker will automatically switch to operate mode on the next run, processing GitHub issues and implementing TODOs.

### Source of truth

The scaffold source lives at [NoahWright87/spec-template](https://github.com/NoahWright87/spec-template)."

    echo "[worker] Bootstrap PR opened. Run complete."
    exit 0
fi

# ══ Operate mode ═══════════════════════════════════════════════════════════════
# Multi-agent architecture: reads .agents/config.yaml from the target repo to determine
# which agents to run.
# Each agent gets its own branch, PR, and Claude session.
# Agent prompts are assembled from agents/ definitions + tasks/ files in the image,
# with optional per-repo overrides from .agents/overrides/ in the target repo.

cd "$WORKSPACE"

# ── Source shared functions ──────────────────────────────────────────────────
# common.sh provides: read_agent_config, fetch_pr_comments, build_situation_report
# (debug/debug_var are defined inline above since they're needed before this point)
SCRIPT_DIR="/worker/scripts"
source "$SCRIPT_DIR/common.sh"

# ── Read agent config ────────────────────────────────────────────────────────
AGENT_DIR="/worker/agents"
TASK_DIR="/worker/agents/tasks"

if [ -f "$WORKSPACE/.agents/config.yaml" ]; then
    WORKER_CONFIG="$WORKSPACE/.agents/config.yaml"
    echo "[worker] Reading agent config: $WORKER_CONFIG"
    MAX_OPEN_PRS=$(yq '.settings.max_open_prs // 1' "$WORKER_CONFIG")
    AGENTS=$(yq '.agents[]' "$WORKER_CONFIG" 2>/dev/null || echo "")
else
    echo "[worker] No agent config found — using defaults."
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

# ── Repo-specific notification webhook ───────────────────────────────────────
# Teams can supply settings.notification_webhook in .agents/config.yaml to receive
# notifications in their own channel. Posts in addition to NOTIFICATION_WEBHOOK.
REPO_NOTIFICATION_WEBHOOK=""
if [ -n "${WORKER_CONFIG:-}" ]; then
    REPO_NOTIFICATION_WEBHOOK=$(yq '.settings.notification_webhook // ""' "$WORKER_CONFIG" 2>/dev/null || echo "")
fi

# ── Config version detection ─────────────────────────────────────────────────
# Version 2 enables per-agent config (.agents/{name}/config.yaml) and per-agent
# activity signals. Version 1 (or missing) uses legacy global signals + defaults.
_config_version=1
if [ -n "${WORKER_CONFIG:-}" ]; then
    _config_version=$(yq '.version // 1' "$WORKER_CONFIG")
fi
echo "[worker] Config version: $_config_version"

# ── Auto-upgrade config if outdated ──────────────────────────────────────────
if [ -n "${WORKER_CONFIG:-}" ] && [ "$_config_version" -lt "$CURRENT_CONFIG_VERSION" ]; then
    upgrade_config "$WORKER_CONFIG" "$_config_version"
    # Push the upgrade commit so subsequent branches from origin/$TARGET_BRANCH
    # include the upgraded config and the migration is durable.
    debug "Pushing auto-upgraded config commit to origin/$TARGET_BRANCH"
    git -C "$WORKSPACE" push origin "HEAD:${TARGET_BRANCH}"
fi

# ── Resolve debug setting ────────────────────────────────────────────────────
# WORKER_DEBUG env var takes priority over config file setting. This lets you
# enable debug for a single run (e.g. kubectl set env) without committing changes.
# Setting WORKER_DEBUG=0/false/no explicitly disables debug even if config enables it.
# Normalize WORKER_DEBUG: accept 1/true/yes (on) and 0/false/no (off), case-insensitive
_debug_env_set="${WORKER_DEBUG:+yes}"  # non-empty if WORKER_DEBUG was set to anything
case "$(echo "$WORKER_DEBUG" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes) WORKER_DEBUG=1 ;;
    0|false|no) WORKER_DEBUG=0 ;;
    *) WORKER_DEBUG="" ;;
esac

if [ "$WORKER_DEBUG" = "1" ]; then
    _debug_source="env var"
elif [ -n "$_debug_env_set" ] && [ "$WORKER_DEBUG" = "0" ]; then
    # Explicitly set to off via env var — don't let config override
    _debug_source="env var (explicitly off)"
elif [ -n "${WORKER_CONFIG:-}" ]; then
    _debug_setting=$(yq '.settings.debug // false' "$WORKER_CONFIG" 2>/dev/null || echo "false")
    [ "$_debug_setting" = "true" ] && WORKER_DEBUG=1 || WORKER_DEBUG=0
    _debug_source="config"
else
    WORKER_DEBUG=0
    _debug_source="default (off)"
fi
export WORKER_DEBUG

if [ "$WORKER_DEBUG" = "1" ]; then
    echo "[worker] Debug output: ENABLED (source: $_debug_source)"
    debug "Config file: ${WORKER_CONFIG:-none}"
    if [ -n "${WORKER_CONFIG:-}" ]; then
        debug "Config settings: agents=$(yq '.agents[]' "$WORKER_CONFIG" 2>/dev/null | tr '\n' ',' || echo 'n/a') max_open_prs=$(yq '.settings.max_open_prs // "n/a"' "$WORKER_CONFIG" 2>/dev/null || echo 'n/a')"
    fi
    debug "Agent instruction dir: $AGENT_DIR"
    debug "Task file dir: $TASK_DIR"
fi

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
    echo "[worker]   Check agent names in ${WORKER_CONFIG:-config} match files in $AGENT_DIR/"
    exit 1
fi

# ── Verify task files referenced by each agent ──────────────────────────────
# Agent files reference tasks via markdown links: [description](tasks/name.md)
for _agent in $AGENTS; do
    _tasks=$(grep -o '(tasks/[a-z0-9-]*\.md)' "$AGENT_DIR/$_agent.md" \
        | sed 's/(tasks\///;s/\.md)//' \
        | sort -u)
    for _task in $_tasks; do
        if [ ! -f "$TASK_DIR/$_task.md" ]; then
            echo "[worker] PREFLIGHT FAIL: Task file not found: $TASK_DIR/$_task.md (referenced by agent $_agent)"
            _missing=1
        fi
    done
done
if [ "$_missing" -ne 0 ]; then
    echo "[worker]   Available tasks: $(ls "$TASK_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | tr '\n' ' ')"
    exit 1
fi
echo "[worker] ✓ All agent and task files verified."
if [ "$WORKER_DEBUG" = "1" ]; then
    for _agent in $AGENTS; do
        _tasks=$(grep -o '(tasks/[a-z0-9-]*\.md)' "$AGENT_DIR/$_agent.md" \
            | sed 's/(tasks\///;s/\.md)//' | sort -u | tr '\n' ', ' | sed 's/,$//')
        debug "Agent '$_agent' tasks: $_tasks"
    done
fi

# ── Apply task overrides from target repo ────────────────────────────────────
# Override resolution: .agents/overrides/{task}.md in target repo replaces the
# central default in $TASK_DIR (/worker/agents/tasks/). Full-file replacement — no partial merging.
# Container is ephemeral, so modifying TASK_DIR in place is safe.
#
# Supports both top-level task overrides and sub-task overrides:
#   .agents/overrides/backfill-specs.md           → replaces tasks/backfill-specs.md
#   .agents/overrides/backfill-specs/fill-incomplete.md → replaces tasks/backfill-specs/fill-incomplete.md
if [ -d "$WORKSPACE/.agents/overrides" ]; then
    _override_count=0
    # Top-level task overrides
    for _override in "$WORKSPACE/.agents/overrides/"*.md; do
        [ -f "$_override" ] || continue
        _task_name=$(basename "$_override")
        echo "[worker]   Task override: $_task_name"
        cp -- "$_override" "$TASK_DIR/$_task_name"
        _override_count=$(( _override_count + 1 ))
    done
    # Sub-task directory overrides
    for _override_dir in "$WORKSPACE/.agents/overrides/"*/; do
        [ -d "$_override_dir" ] || continue
        _sub_dir_name=$(basename "$_override_dir")
        mkdir -p "$TASK_DIR/$_sub_dir_name"
        for _sub_override in "$_override_dir"*.md; do
            [ -f "$_sub_override" ] || continue
            _sub_name=$(basename "$_sub_override")
            echo "[worker]   Sub-task override: $_sub_dir_name/$_sub_name"
            cp -- "$_sub_override" "$TASK_DIR/$_sub_dir_name/$_sub_name"
            _override_count=$(( _override_count + 1 ))
        done
    done
    if [ "$_override_count" -gt 0 ]; then
        echo "[worker] Applied $_override_count task override(s) from .agents/overrides/"
    fi
fi


# ── Activity signal detection ─────────────────────────────────────────────────
# Version 2: per-agent check scripts in worker/scripts/ determine if each agent
# should run. Scripts are sourced in the per-agent loop.
#
# Version 1 (backward compat): global activity signals computed here upfront.
_global_activity=0
_global_reason=""

if [ "$_config_version" -lt 2 ]; then
    echo "[worker] Checking global activity signals (v1 compat)..."
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
    debug "Signal A — unprocessed issues: ${_unprocessed:-0}"
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
            debug "Signal B — issue #$_inum last commenter: $_last"
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
else
    echo "[worker] Activity signals: per-agent check scripts (v2)"
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
if [ -n "$_all_worker_prs" ]; then
    debug_var "Open worker PR branches" "$_all_worker_prs"
else
    debug "No open worker PRs found."
fi

# ── PR comment fetching + situation report builder ───────────────────────────
# These functions are defined in scripts/common.sh (sourced above):
#   fetch_pr_comments()    — fetches non-agent comments, sets _review_comments_json etc.
#   build_situation_report() — assembles markdown situation report for agent prompt

# ── Per-agent loop ───────────────────────────────────────────────────────────
_any_agent_ran=0
_any_agent_failed=0
_agent_results=""
TODAY=$(date -u +%Y-%m-%d)

for _agent in $AGENTS; do
    echo ""
    echo "[worker] ── Agent: $_agent ────────────────────────────────────────────"

    # Read per-agent config (version 2+) or use defaults (version 1)
    read_agent_config "$_agent"

    # Find this agent's existing open PR (branch pattern: worker/{agent-name}/*)
    _agent_pr=""
    _agent_pr_branch=""
    _agent_open_pr_count=0
    if [ -n "$_all_worker_prs" ]; then
        _agent_pr_branch=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $1}' || true)
        _agent_pr=$(echo "$_all_worker_prs" | grep "^worker/$_agent/" | head -1 | awk '{print $2}' || true)
        _agent_open_pr_count=$(echo "$_all_worker_prs" | grep -c "^worker/$_agent/" 2>/dev/null || true)
    fi

    # Use the existing PR's branch when responding to comments; today's date for new work
    if [ -n "$_agent_pr_branch" ]; then
        _agent_branch="$_agent_pr_branch"
    else
        _agent_branch="worker/$_agent/$TODAY"
    fi
    debug "Agent '$_agent': existing_pr=${_agent_pr:-none} branch=$_agent_branch agent_prs=$_agent_open_pr_count"

    _agent_should_run=0
    _agent_reason=""
    _is_new_pr=0
    _startup_context=""
    # Pre-initialize state variables used by fetch_pr_comments / build_situation_report.
    # These are set properly below when a PR exists; defaults prevent unbound errors.
    _has_conflicts="false"
    _total_comment_count=0
    _review_comments_json="[]"
    _conversation_comments_json="[]"

    if [ -n "$_agent_pr" ]; then
        # ── Existing PR: pre-fetch all context deterministically ──────
        # Fetch comments and merge state BEFORE deciding whether to run.
        # This data feeds the situation report, so Claude starts with full
        # context and doesn't need to re-query the GitHub API.
        echo "[worker]   Existing PR: #$_agent_pr"

        fetch_pr_comments "$_agent_pr"

        # Check for merge conflicts.
        # WHY mergeable_state, not mergeable: GitHub computes mergeability
        # asynchronously — mergeable can be null while the computation runs,
        # but mergeable_state == "dirty" is the definitive conflict signal.
        _has_conflicts=$(gh api "repos/$TARGET_REPO/pulls/$_agent_pr" \
            --jq '.mergeable_state == "dirty"' 2>/dev/null || echo "false")
        debug "PR #$_agent_pr mergeable_state==dirty: $_has_conflicts"

        if [ "$_total_comment_count" -gt 0 ]; then
            _agent_should_run=1
            _agent_reason="${_total_comment_count} non-agent comment(s) on PR #$_agent_pr"
        elif [ "$_has_conflicts" = "true" ]; then
            _agent_should_run=1
            _agent_reason="merge conflicts on PR #$_agent_pr"
        else
            # ── Special case: agents with non-PR work ─────────────────
            # Some agents (e.g. refine) can do useful work without touching
            # files — run the check script to see if there's non-PR work.
            if [ "$_config_version" -ge 2 ]; then
                _check_script="$SCRIPT_DIR/${_agent}/check.sh"
                [ -f "$_check_script" ] || _check_script="$SCRIPT_DIR/default/check.sh"
                source "$_check_script"
                if [ "$_check_result" -eq 1 ]; then
                    _agent_should_run=1
                    _agent_reason="$_check_reason (PR #$_agent_pr has no comments)"
                else
                    echo "[worker]   No non-agent comments or merge conflicts on PR #$_agent_pr — skipping."
                fi
            else
                echo "[worker]   No non-agent comments or merge conflicts on PR #$_agent_pr — skipping."
            fi
        fi
    else
        # ── No PR: decide based on per-agent signals (v2) or global (v1) ──
        _is_new_pr=1
        _has_work=0
        _work_reason=""

        if [ "$_config_version" -ge 2 ]; then
            # Version 2: run per-agent check script
            _check_script="$SCRIPT_DIR/${_agent}/check.sh"
            [ -f "$_check_script" ] || _check_script="$SCRIPT_DIR/default/check.sh"
            echo "[worker]   Running check: $(basename "$_check_script")"
            source "$_check_script"
            _has_work=$_check_result
            _work_reason="$_check_reason"
        else
            # Version 1: global activity signal
            if [ "$_global_activity" -eq 1 ]; then
                _has_work=1
                _work_reason="$_global_reason"
            fi
        fi

        if [ "$_has_work" -eq 1 ]; then
            # ── Dual PR cap check ─────────────────────────────────────
            # 1. Per-agent cap: don't exceed this agent's own PR limit
            # 2. Fleet cap: don't exceed total open worker PRs
            if [ "$_agent_open_pr_count" -ge "$AGENT_MAX_OPEN_PRS" ]; then
                echo "[worker]   Would create new PR but per-agent cap ($AGENT_MAX_OPEN_PRS) reached — skipping."
            elif [ "$_open_pr_count" -ge "$MAX_OPEN_PRS" ]; then
                echo "[worker]   Would create new PR but fleet max_open_prs cap ($MAX_OPEN_PRS) reached — skipping."
            else
                _agent_should_run=1
                _agent_reason="$_work_reason (new work)"
            fi
        else
            echo "[worker]   No existing PR and no activity signals for $_agent — skipping."
        fi
    fi

    if [ "$_agent_should_run" -eq 0 ]; then
        _agent_results="${_agent_results}  $_agent: skipped\n"
        continue
    fi

    echo "[worker]   Running: $_agent_reason"

    # Export per-agent environment variables — read by task files at runtime.
    export AGENT_NAME="$_agent"
    export AGENT_BRANCH="$_agent_branch"
    export RUN_DATE="$TODAY"
    if [ -n "$_agent_pr" ]; then
        export WORKER_PR_NUMBER="$_agent_pr"
    else
        unset WORKER_PR_NUMBER 2>/dev/null || true
    fi

    # ── Run startup script (v2) ──────────────────────────────────────
    # Startup scripts gather data for the agent: fetch issues, compute
    # dates, prepare JSON files. They set _startup_context with markdown
    # to include in the situation report.
    _startup_context=""
    if [ "$_config_version" -ge 2 ]; then
        _startup_script="$SCRIPT_DIR/${_agent}/startup.sh"
        if [ -f "$_startup_script" ]; then
            echo "[worker]   Running startup: $(basename "$_startup_script")"
            source "$_startup_script"
        fi
    fi

    # ── Build the prompt: situation report + agent definition ─────────
    # The situation report provides pre-fetched, pre-filtered context
    # (PR state, comments as JSON, conflict status, startup data) so Claude
    # starts with full awareness of the current state. The agent definition
    # follows, linking to task files that Claude reads on demand via the Read tool.
    build_situation_report "$_agent" "$_agent_pr" "$_agent_branch" "$_agent_reason"
    # Rewrite relative markdown links like ](tasks/...) to absolute paths so Claude
    # can read task files from /worker/agents/tasks/ regardless of its working directory.
    _prompt="${_situation_report}$(sed 's#](tasks/#](/worker/agents/tasks/#g' "$AGENT_DIR/$_agent.md")"

    debug "Prompt length: $(echo -n "$_prompt" | wc -c | tr -d ' ') characters"
    if [ "$WORKER_DEBUG" = "1" ]; then
        debug_var "Situation report for $_agent" "$_situation_report"
    fi

    _agent_log="$STATE_DIR/$_agent-last-run.log"

    # ── Enforce correct branch before handing off to Claude ──────────────
    # Do this in bash (not via Claude task) to prevent cross-agent contamination.
    echo "[worker]   Branch: ensuring $_agent_branch is checked out"
    # Ensure the base branch (TARGET_BRANCH) is up to date
    git checkout "$TARGET_BRANCH" 2>/dev/null && git pull origin "$TARGET_BRANCH" --quiet
    # If a remote agent branch exists, track/reset to it; otherwise create from origin/$TARGET_BRANCH
    if git show-ref --verify --quiet "refs/remotes/origin/$_agent_branch"; then
        # Remote agent branch exists
        if git show-ref --verify --quiet "refs/heads/$_agent_branch"; then
            git checkout "$_agent_branch"
            git reset --hard "origin/$_agent_branch"
        else
            git checkout -b "$_agent_branch" "origin/$_agent_branch"
        fi
    else
        # No remote agent branch; create from the configured base branch
        git checkout -b "$_agent_branch" "origin/$TARGET_BRANCH"
    fi

    debug "Invoking Claude CLI: claude --dangerously-skip-permissions ${MODEL:+--model $MODEL }-p <prompt> (logging to $_agent_log)"

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
    debug "Agent '$_agent' exit code: $_agent_exit"
    set -e

    # ── Verify branch after Claude exits ─────────────────────────────────
    _actual_branch=$(git branch --show-current)
    if [ "$_actual_branch" != "$_agent_branch" ]; then
        echo "[worker]   WARNING: Agent '$_agent' left repo on wrong branch: $_actual_branch (expected $_agent_branch)"
    fi

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
            # Auth failure is fatal — send notification then stop
            _notify_message=$(printf '**%s** FAILED — Claude authentication error (exit code %s).\n\nRun reason: %s' "$_agent" "$_agent_exit" "$_agent_reason")
            webhook_notify "$_agent" "true" "$_notify_message"
            exit "$_agent_exit"
        fi
        _any_agent_failed=1
        _agent_results="${_agent_results}  $_agent: FAILED (exit $_agent_exit)\n"
    else
        _any_agent_ran=1
        # If this was a new-PR slot, verify the agent actually created a PR
        # before counting it against max_open_prs. Agents can exit 0 without
        # creating a PR (e.g., intake labels issues but has no file changes).
        if [ "$_is_new_pr" -eq 1 ]; then
            _new_pr_check=$(gh pr list --repo "$TARGET_REPO" --head "$_agent_branch" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)
            if [ -n "$_new_pr_check" ]; then
                _open_pr_count=$(( _open_pr_count + 1 ))
                echo "[worker]   PR #$_new_pr_check created — open worker PRs now $_open_pr_count / $MAX_OPEN_PRS"
            else
                echo "[worker]   Agent succeeded but no PR was created — not counting against cap."
            fi
        fi
        _agent_results="${_agent_results}  $_agent: OK\n"
    fi

    # ── Per-agent notification ────────────────────────────────────────────
    if [ "$_agent_exit" -ne 0 ]; then
        _notify_message=$(printf '**%s** FAILED (exit code %s).\n\nRun reason: %s' "$_agent" "$_agent_exit" "$_agent_reason")
        webhook_notify "$_agent" "true" "$_notify_message"
    else
        _notify_message=$(printf '**%s** completed successfully.\n\nRun reason: %s' "$_agent" "$_agent_reason")
        webhook_notify "$_agent" "false" "$_notify_message"
    fi

    echo "[worker]   Agent '$_agent' complete. Log: $_agent_log"
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "[worker] ────────────────────────────────────────────────────────────────"
echo "[worker] Run complete. Agent results:"
echo -e "$_agent_results"
echo "[worker] ────────────────────────────────────────────────────────────────"

# Notifications are sent per-agent inside the loop above.

if [ "$_any_agent_failed" -ne 0 ]; then
    exit 1
fi
