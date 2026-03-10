FROM node:20-slim

# ── System dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ─────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ── Claude Code CLI ────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code@2.1.71

# ── Worker runtime files ───────────────────────────────────────────────────────
WORKDIR /worker
COPY worker/entrypoint.sh ./entrypoint.sh
COPY worker/worker-instructions.md ./worker-instructions.md
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
RUN useradd --create-home --shell /bin/bash worker \
    && chown -R worker:worker /worker

# Persist state across container restarts; workspace is re-created each run by default
VOLUME /worker/state

USER worker

# ── Runtime secrets and parameters (supplied at container start, never baked in)
# Auth (choose one) — ANTHROPIC_API_KEY (API key mode — recommended for containers)
#                     OR mount ~/.claude from host: -v ~/.claude:/home/worker/.claude:ro (subscription mode)
#                        Subscription mode requires file-based credentials (~/.claude/.credentials.json).
#                        If `claude login` used your OS keychain, use API key mode instead.
# Required secrets  — GITHUB_TOKEN
# Required params   — TARGET_REPO (e.g. "owner/repo")
# Optional params   — TARGET_BRANCH (default: main)
#                     CLAUDE_CONFIG_PATH (default: .claude — relative to repo root)
#                     ANTHROPIC_BASE_URL (custom API endpoint for enterprise/proxy deployments)

ENTRYPOINT ["/worker/entrypoint.sh"]
