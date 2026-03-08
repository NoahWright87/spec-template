#!/usr/bin/env bash
# Worker entrypoint — executed on each cron iteration.
#
# Flow: validate env → authenticate → clone/update target repo → run Claude CLI → exit.
# State that should survive between runs (logs, Claude memory) lives in /worker/state (volume).

set -euo pipefail

# ── Required environment validation ───────────────────────────────────────────
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${TARGET_REPO:?TARGET_REPO is required}"

# ── Optional parameters with defaults ─────────────────────────────────────────
TARGET_BRANCH="${TARGET_BRANCH:-main}"
EXECUTION_MODE="${EXECUTION_MODE:-full}"
CLAUDE_CONFIG_PATH="${CLAUDE_CONFIG_PATH:-.claude}"

WORKSPACE="/worker/workspace"
STATE_DIR="/worker/state"
LOG_FILE="$STATE_DIR/last-run.log"

echo "[worker] ────────────────────────────────────────────────────────────────"
echo "[worker] Starting run"
echo "[worker]   target:  $TARGET_REPO @ $TARGET_BRANCH"
echo "[worker]   mode:    $EXECUTION_MODE"
echo "[worker] ────────────────────────────────────────────────────────────────"

# ── Authenticate GitHub CLI ────────────────────────────────────────────────────
echo "[worker] Authenticating gh CLI..."
echo "$GITHUB_TOKEN" | gh auth login --with-token --hostname github.com

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

# ── Run Claude CLI ─────────────────────────────────────────────────────────────
echo "[worker] Running Claude CLI (mode: $EXECUTION_MODE)..."
cd "$WORKSPACE"

INSTRUCTIONS_FILE="/worker/worker-instructions.md"
if [ -f "$CLAUDE_CONFIG_PATH/worker-instructions.md" ]; then
    # Allow the target repo to supply its own worker instructions
    INSTRUCTIONS_FILE="$CLAUDE_CONFIG_PATH/worker-instructions.md"
    echo "[worker] Using repo-local worker instructions."
fi

claude --no-interactive \
    -p "$(cat "$INSTRUCTIONS_FILE")" \
    2>&1 | tee "$LOG_FILE"

echo "[worker] Run complete. Log: $LOG_FILE"
