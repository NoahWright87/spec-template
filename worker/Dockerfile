FROM node:20-alpine

# ── System dependencies ────────────────────────────────────────────────────────
RUN apk add --no-cache \
    git \
    curl \
    jq \
    bash \
    github-cli

# ── Claude Code CLI ────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code@2.1.71 tsx

# ── yq (YAML parser for agent config) ──────────────────────────────────────
ARG YQ_VERSION=v4.44.1
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# ── Worker runtime files ───────────────────────────────────────────────────────
WORKDIR /worker
COPY worker/entrypoint.sh ./entrypoint.sh
COPY worker/scripts/ ./scripts/
COPY agents/ ./agents/
RUN chmod +x ./entrypoint.sh && find ./scripts -name '*.sh' -exec chmod +x {} +

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
#                     OR mount ~/.claude from host: -v ~/.claude:/home/worker/.claude:ro (subscription mode)
#                        Subscription mode requires file-based credentials (~/.claude/.credentials.json).
#                        If `claude login` stored tokens in your OS keychain, use API key mode instead.
# GitHub (choose one):
#   PAT mode:        GH_TOKEN (classic with 'repo' scope, or fine-grained with contents:write)
#   GitHub App mode: GITHUB_APP_ID + GITHUB_APP_PRIVATE_KEY (PEM, raw or base64) + GITHUB_APP_INSTALLATION_ID
#                    → generates a short-lived installation token automatically
# Required params   — TARGET_REPO (e.g. "owner/repo")
# Optional params   — TARGET_BRANCH (default: main)
#                     CLAUDE_CONFIG_PATH (default: .claude — relative to repo root)
#                     ANTHROPIC_BASE_URL (custom API endpoint for proxy/gateway deployments)
#                     MODEL (Claude model to use, e.g. claude-sonnet-4-5, claude-haiku-4-5)
#                        Defaults to Claude CLI's default if not specified

ENTRYPOINT ["/worker/entrypoint.sh"]
