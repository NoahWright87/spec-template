FROM node:20-alpine

# ── System dependencies ────────────────────────────────────────────────────────
RUN apk add --no-cache \
    git \
    curl \
    jq \
    rsync \
    bash \
    python3 \
    github-cli

# ── Claude Code CLI ────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code@2.1.71

# ── Worker runtime files ───────────────────────────────────────────────────────
WORKDIR /worker
COPY worker/entrypoint.sh ./entrypoint.sh
COPY worker/common/ ./common/
COPY worker/agents/ ./agents/
# dist/ is the scaffold payload used by install mode to bootstrap unscaffolded repos
COPY dist/ ./dist/
RUN chmod +x ./entrypoint.sh

# ── Directories ────────────────────────────────────────────────────────────────
# /worker/workspace — target repo clone (can be a volume for faster cron re-runs)
# /worker/state     — persistent state between cron runs (logs, Claude memory cache)
RUN mkdir -p /worker/workspace /worker/state

# ── Non-root runtime user ──────────────────────────────────────────────────────
# --dangerously-skip-permissions refuses to run as root for security reasons.
# Create a dedicated non-root user and transfer ownership of all worker directories.
RUN adduser -D -s /bin/bash worker \
    && chown -R worker:worker /worker

# Persist state across container restarts; workspace is re-created each run by default
VOLUME /worker/state

USER worker

# ── Runtime secrets and parameters (supplied at container start, never baked in)
# Auth (choose one) — ANTHROPIC_API_KEY (API key mode — recommended for containers)
#                        ANTHROPIC_API_KEY: Standard Anthropic API (api.anthropic.com)
#                     OR mount ~/.claude from host: -v ~/.claude:/home/worker/.claude:ro (subscription mode)
#                        Subscription mode requires file-based credentials (~/.claude/.credentials.json).
#                        If `claude login` used your OS keychain, use API key mode instead.
# Required secrets  — GITHUB_TOKEN
# Required params   — TARGET_REPO (e.g. "owner/repo")
# Optional params   — TARGET_BRANCH (default: main)
#                     CLAUDE_CONFIG_PATH (default: .claude — relative to repo root)
#                     ANTHROPIC_BASE_URL (custom API endpoint for enterprise/proxy/gateway deployments)
#                     MODEL (Claude model to use, e.g. claude-sonnet-4-6, claude-haiku-4-5)
#                        Defaults to Claude CLI's default if not specified
#                        When using subscription mode (mounted ~/.claude), MODEL is accepted
#                        but model validation is skipped (no API key to validate against)

ENTRYPOINT ["/worker/entrypoint.sh"]
