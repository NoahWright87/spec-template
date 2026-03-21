#!/usr/bin/env bash
# Helper script to run the worker locally with environment variables from .env file
#
# Usage:
#   ./run-worker.sh           # Run once
#   ./run-worker.sh --build   # Build local image first, then run
#
# This script loads environment variables from .env file (git-ignored) and passes
# them to docker run. In CI/CD, use the environment variables directly without this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo ""
    echo "Create one from the example:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your actual values"
    exit 1
fi

# Build local image if --build flag is passed
if [ "${1:-}" = "--build" ]; then
    echo "Building worker image locally..."
    docker build -f worker/Dockerfile -t spec-template-worker:local .
    IMAGE="spec-template-worker:local"
else
    IMAGE="ghcr.io/noahwright87/spec-template-worker:latest"
fi

# Load environment variables from .env
set -a  # automatically export all variables
source "$ENV_FILE"
set +a

# Validate required variables
: "${GITHUB_TOKEN:?GITHUB_TOKEN not set in .env file}"
: "${TARGET_REPO:?TARGET_REPO not set in .env file}"

# Build docker run command with environment variables
DOCKER_CMD=(
    docker run --rm
    -e "GITHUB_TOKEN=$GITHUB_TOKEN"
    -e "TARGET_REPO=$TARGET_REPO"
)

# Add optional TARGET_BRANCH
if [ -n "${TARGET_BRANCH:-}" ]; then
    DOCKER_CMD+=(-e "TARGET_BRANCH=$TARGET_BRANCH")
fi

# Add authentication
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    DOCKER_CMD+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
        DOCKER_CMD+=(-e "ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL")
    fi
    echo "Using Anthropic API key authentication"
else
    # Subscription mode - mount ~/.claude
    if [ -f "$HOME/.claude/.credentials.json" ]; then
        DOCKER_CMD+=(-v "$HOME/.claude:/home/worker/.claude:ro")
        echo "Using Claude Code subscription authentication (mounted ~/.claude)"
    else
        echo "Error: No authentication method configured in .env file"
        echo "Set ANTHROPIC_API_KEY, or ensure ~/.claude/.credentials.json exists"
        exit 1
    fi
fi

# Add optional CLAUDE_CONFIG_PATH
if [ -n "${CLAUDE_CONFIG_PATH:-}" ]; then
    DOCKER_CMD+=(-e "CLAUDE_CONFIG_PATH=$CLAUDE_CONFIG_PATH")
fi

# Add optional MODEL
if [ -n "${MODEL:-}" ]; then
    DOCKER_CMD+=(-e "MODEL=$MODEL")
fi

# Add state volume
DOCKER_CMD+=(-v "spec-worker-state:/worker/state")

# Add image
DOCKER_CMD+=("$IMAGE")

echo "Running worker..."
echo "Target: $TARGET_REPO"
echo ""

# Execute the docker run command
"${DOCKER_CMD[@]}"
