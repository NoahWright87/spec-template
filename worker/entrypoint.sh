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
#   Subscription: Omit ANTHROPIC_API_KEY. Mount ~/.claude from the host so the Claude
#                 Code CLI can find the OAuth credentials from `claude login`.
#                 e.g. docker run -v ~/.claude:/root/.claude ...
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[worker] Auth mode: API key"
else
    echo "[worker] Auth mode: Claude Code subscription (expecting mounted ~/.claude credentials)"
    if [ ! -d "/root/.claude" ]; then
        echo "[worker] ERROR: No ANTHROPIC_API_KEY set and no ~/.claude directory mounted."
        echo "[worker]        Mount your host credentials: -v ~/.claude:/root/.claude:ro"
        echo "[worker]        Or set ANTHROPIC_API_KEY for API key auth."
        exit 1
    fi
fi

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

# ── Authenticate GitHub CLI ────────────────────────────────────────────────────
# gh CLI automatically uses GITHUB_TOKEN from the environment — no explicit login needed.
echo "[worker] gh CLI ready (using GITHUB_TOKEN from environment)."

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

echo "[worker] Running Claude CLI..."
cd "$WORKSPACE"

INSTRUCTIONS_FILE="/worker/worker-instructions.md"
if [ -f "$CLAUDE_CONFIG_PATH/worker-instructions.md" ]; then
    # Allow the target repo to supply its own worker instructions
    INSTRUCTIONS_FILE="$CLAUDE_CONFIG_PATH/worker-instructions.md"
    echo "[worker] Using repo-local worker instructions."
fi

claude \
    -p "$(cat "$INSTRUCTIONS_FILE")" \
    2>&1 | tee "$LOG_FILE"

echo "[worker] Run complete. Log: $LOG_FILE"
