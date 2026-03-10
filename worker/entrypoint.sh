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
#   → run intake + knock-out-todos via Claude CLI non-interactively
#
# State that should survive between runs (logs) lives in /worker/state (volume).

set -euo pipefail

# ── Required environment validation ───────────────────────────────────────────
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${TARGET_REPO:?TARGET_REPO is required}"

# ── Optional parameters with defaults ─────────────────────────────────────────
TARGET_BRANCH="${TARGET_BRANCH:-main}"
CLAUDE_CONFIG_PATH="${CLAUDE_CONFIG_PATH:-.claude}"

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

# 1. GitHub token: repo access + push permission (one API call, jq is installed)
_push=$(gh api "repos/$TARGET_REPO" --jq '.permissions.push // "unknown"' 2>&1) || {
    echo "[worker] PREFLIGHT FAIL: Cannot access '$TARGET_REPO' with the supplied GITHUB_TOKEN."
    echo "[worker]   • Verify GITHUB_TOKEN is valid and not expired."
    echo "[worker]   • Verify the token has 'repo' scope (classic) or 'contents:read' (fine-grained)."
    echo "[worker]   • Verify TARGET_REPO='$TARGET_REPO' is correct (owner/repo format)."
    exit 1
}
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

- \`.claude/commands/\` — four slash commands: \`/respec\`, \`/intake\`, \`/knock-out-todos\`, \`/spec-backfill\`
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
# Used when the scaffold is already present. Runs intake + knock-out-todos via Claude CLI.

# Pre-flight (operate mode): verify required command files exist in the cloned repo.
# Claude reads these files to know what to do — missing files = empty run with wasted tokens.
_missing=0
for _cmd in "$WORKSPACE/$CLAUDE_CONFIG_PATH/commands/intake.md" \
            "$WORKSPACE/$CLAUDE_CONFIG_PATH/commands/knock-out-todos.md"; do
    if [ ! -f "$_cmd" ]; then
        echo "[worker] PREFLIGHT FAIL: Required command file not found: $_cmd"
        _missing=1
    fi
done
if [ "$_missing" -ne 0 ]; then
    echo "[worker]   The scaffold may be incomplete. Possible fixes:"
    echo "[worker]     • Wait for the bootstrap PR to be merged if it's still open."
    echo "[worker]     • Run /respec in the target repo to restore missing scaffold files."
    exit 1
fi
echo "[worker] ✓ Required command files present in $CLAUDE_CONFIG_PATH/commands/."

# ── Activity check: is there new work for Claude to do? ──────────────────────
# Run lightweight gh API calls before invoking Claude so runs with nothing
# new to do exit immediately without spending any API tokens.
#
# Claude runs if ANY of the following are true:
#   1. No open worker/* PR exists (TODOs may be waiting; Claude decides)
#   2. An open worker/* PR has human comments (user.type=="User", body not 🤖-prefixed)
#   3. Open issues exist with no intake label (intake:filed / rejected / ignore)
#   4. A filed issue's most recent comment is human (user.type=="User", body not 🤖-prefixed)
#
# "Human" = GitHub user type is "User" AND body does NOT start with 🤖.
#   - Personal-PAT mode: human and worker share the same login, so the 🤖
#     prefix is the ONLY reliable discriminator. Login is not checked here.
#   - Service-account mode: worker login differs AND worker uses 🤖 prefix.
#     The user.type=="User" filter additionally excludes GitHub Bot accounts
#     (github-actions[bot], dependabot, etc.) so they never trigger a run.
echo "[worker] Checking for new activity..."
_should_run=0
_run_reason=""

# Condition 1 — no open worker/* PR ───────────────────────────────────────────
_worker_pr=$(gh pr list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,headRefName \
    --jq '[.[] | select(.headRefName | startswith("worker/"))][0].number // empty' \
    2>/dev/null || true)
if [ -z "$_worker_pr" ]; then
    _should_run=1
    _run_reason="no open worker PR"
fi

# Condition 2 — human comments on the open worker PR ──────────────────────────
if [ "$_should_run" -eq 0 ] && [ -n "$_worker_pr" ]; then
    # jq filter: select comments from real users that don't carry the 🤖 prefix.
    # WHY test() not ltrimstr(): ltrimstr removes only one exact character;
    # a body starting with "  🤖" (two spaces) or "\n🤖" would slip through.
    # test("^[[:space:]]*🤖") correctly matches any leading whitespace before the emoji.
    _human_filter='[.[] | select(.user.type == "User" and (.body | test("^[[:space:]]*🤖") | not))] | length'
    for _api in issues pulls; do
        _n=$(gh api "repos/$TARGET_REPO/$_api/$_worker_pr/comments" \
            --jq "$_human_filter" 2>/dev/null || echo "0")
        if [ "${_n:-0}" -gt 0 ]; then
            _should_run=1
            _run_reason="${_n} human comment(s) on worker PR #$_worker_pr"
            break
        fi
    done
fi

# Condition 3 — open issues with no intake label ──────────────────────────────
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
    _should_run=1
    _run_reason="${_unprocessed} unprocessed issue(s) without intake labels"
fi

# Condition 4 — filed issue with human as the most recent commenter ────────────
if [ "$_should_run" -eq 0 ]; then
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
            _should_run=1
            _run_reason="human comment on filed issue #${_inum}"
            break
        fi
    done
fi

# Decision ─────────────────────────────────────────────────────────────────────
if [ "$_should_run" -eq 0 ]; then
    echo "[worker] No new activity requiring Claude's attention — skipping run."
    if [ -n "$_worker_pr" ]; then
        echo "[worker] Worker PR #$_worker_pr is open and up to date."
        echo "[worker] Trigger the next run by:"
        echo "[worker]   • Commenting on PR #$_worker_pr (without the 🤖 prefix)"
        echo "[worker]   • Opening a new GitHub issue"
        echo "[worker]   • Merging or closing PR #$_worker_pr"
    fi
    exit 0
fi
echo "[worker] Activity detected: $_run_reason — proceeding."

echo "[worker] Running Claude CLI..."
cd "$WORKSPACE"

INSTRUCTIONS_FILE="/worker/worker-instructions.md"
if [ -f "$CLAUDE_CONFIG_PATH/worker-instructions.md" ]; then
    # Allow the target repo to supply its own worker instructions
    INSTRUCTIONS_FILE="$CLAUDE_CONFIG_PATH/worker-instructions.md"
    echo "[worker] Using repo-local worker instructions."
fi

# Temporarily disable errexit so we can inspect the log for a helpful auth error
# message before exiting, rather than letting the bare "Not logged in · Please
# run /login" TUI text be the last thing the user sees.
set +e
claude \
    --dangerously-skip-permissions \
    -p "$(cat "$INSTRUCTIONS_FILE")" \
    2>&1 | tee "$LOG_FILE"
CLAUDE_EXIT=${PIPESTATUS[0]}
set -e

if [ "$CLAUDE_EXIT" -ne 0 ]; then
    if grep -qE "Not logged in|401|authentication_error|Invalid authentication" "$LOG_FILE" 2>/dev/null; then
        echo "[worker] ────────────────────────────────────────────────────────────────"
        echo "[worker] ERROR: Claude authentication failed."
        echo "[worker]        Subscription OAuth tokens expire and cannot be refreshed"
        echo "[worker]        in a headless container (no browser available)."
        echo "[worker]"
        echo "[worker]        To fix: use Claude interactively on your host machine"
        echo "[worker]        (this triggers a token refresh), then re-copy the fresh"
        echo "[worker]        credentials file to the Docker host:"
        echo "[worker]          ~/.claude/.credentials.json → C:\.claude\.credentials.json"
        echo "[worker]"
        echo "[worker]        Or avoid this entirely with API key mode:"
        echo "[worker]          docker run -e ANTHROPIC_API_KEY=sk-ant-... ..."
        echo "[worker] ────────────────────────────────────────────────────────────────"
    fi
    exit "$CLAUDE_EXIT"
fi

echo "[worker] Run complete. Log: $LOG_FILE"
