#!/usr/bin/env bash
# Fleet manager entrypoint — executed on each cron iteration.
#
# Flow: validate env → authenticate → clone/update target repo
#         → detect scaffold → install mode OR operate mode → exit
#
# Install mode: scaffold not found in target repo
#   → copy dist/ payload, create branch, open bootstrap PR, exit
#
# Operate mode: scaffold found in target repo
#   → read .agents/config.json (or legacy worker-config.yaml) for agent list + limits
#   → check global activity signals (issues, comments)
#   → for each declared agent: assemble prompt from tasks, check triggers, run Claude CLI
#   → each agent gets its own branch (worker/{name}/YYYY-MM-DD) and PR
#   → write state files (.agents/{name}/state.json, .agents/coordination.json)
#
# State that should survive between runs (logs) lives in /worker/state (volume).
# Agent state (.agents/) is committed to the target repo for cross-agent awareness.

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

    if [ "$_http_code" = "200" ]; then
        echo "[worker] ✓ Model '$MODEL' is accessible"
    else
        echo "[worker] PREFLIGHT FAIL: Model validation returned HTTP $_http_code for model '$MODEL'."
        echo "[worker]"
        echo "[worker] API response:"
        echo "$_response" | jq -r '.' 2>/dev/null || echo "$_response" | sed 's/^/[worker]   /'
        echo "[worker]"
        echo "[worker] Troubleshooting:"
        case "$_http_code" in
            401) echo "[worker]   • API key is invalid or expired — verify ANTHROPIC_API_KEY" ;;
            404) echo "[worker]   • Model '$MODEL' not found — check the model ID (e.g. claude-sonnet-4-6)" ;;
            429) echo "[worker]   • Rate limited — try again later or use a different model" ;;
        esac
        echo "[worker]   • Try omitting MODEL to use the default model"
        exit 1
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
# Composable agent architecture: reads .agents/config.json (or legacy worker-config.yaml)
# from the target repo to determine which agents to run. Each agent is assembled from
# task files and gets its own branch, PR, and Claude session.

cd "$WORKSPACE"

# ── Source fleet manager libraries ───────────────────────────────────────────
FLEET_LIB="/worker/lib"
source "$FLEET_LIB/config.sh"
source "$FLEET_LIB/activity.sh"
source "$FLEET_LIB/prompt-assembly.sh"
source "$FLEET_LIB/agent-runner.sh"

# ── Set up paths ─────────────────────────────────────────────────────────────
AGENT_DIR="/worker/agents"
TASK_DIR="/worker/tasks"
export AGENT_DIR TASK_DIR WORKSPACE TARGET_REPO TARGET_BRANCH STATE_DIR MODEL

# ── Read fleet config ────────────────────────────────────────────────────────
read_fleet_config
apply_config_defaults

# ── Verify agent instruction files exist ─────────────────────────────────────
_missing=0
for _agent in $AGENTS; do
    if [ ! -f "$AGENT_DIR/$_agent.md" ]; then
        echo "[fleet] PREFLIGHT FAIL: Agent manifest not found: $AGENT_DIR/$_agent.md"
        _missing=1
    fi
done
if [ "$_missing" -ne 0 ]; then
    echo "[fleet]   Available agents: $(ls "$AGENT_DIR"/*.md 2>/dev/null | grep -v AGENTS.md | grep -v README.md | xargs -I{} basename {} .md | tr '\n' ' ')"
    echo "[fleet]   Check .agents/config.json agent names match files in $AGENT_DIR/"
    exit 1
fi

# Verify command files exist in the container for agents that reference them
COMMAND_DIR="/worker/commands/lib"
for _agent in $AGENTS; do
    case "$_agent" in
        intake|knock-out-todos)
            _cmd_file="$COMMAND_DIR/$_agent.md"
            if [ ! -f "$_cmd_file" ]; then
                echo "[fleet] PREFLIGHT FAIL: Required command file not found: $_cmd_file"
                _missing=1
            fi
            ;;
    esac
done
if [ "$_missing" -ne 0 ]; then
    echo "[fleet]   The container image may be outdated. Rebuild: docker compose build worker"
    exit 1
fi
echo "[fleet] ✓ All agent manifests and required command files verified."

# ── Check global activity signals ────────────────────────────────────────────
check_global_activity
enumerate_worker_prs

# ── Run agents ───────────────────────────────────────────────────────────────
run_agents
_exit_code=$?

# ── Commit state files to target repo ────────────────────────────────────────
if [ -d "$WORKSPACE/.agents" ]; then
    cd "$WORKSPACE"
    if git diff --quiet .agents/ 2>/dev/null && git diff --cached --quiet .agents/ 2>/dev/null; then
        echo "[fleet] No state changes to commit."
    else
        git add .agents/
        git commit -m "Update agent state files

Written by the spec-template fleet manager after agent run." 2>/dev/null || true
        git push origin HEAD 2>/dev/null || true
    fi
fi

exit "$_exit_code"
