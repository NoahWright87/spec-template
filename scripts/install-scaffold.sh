#!/usr/bin/env bash
# install-scaffold.sh — copy spec-template scaffold files into a target repo
#
# Copies the managed scaffold files from this repo's dist/ directory into a
# target repository without overwriting any files that already exist there.
# Faster and cheaper than running /respec with Claude: no AI tokens consumed
# for the deterministic file-copy step.
#
# Usage:
#   ./scripts/install-scaffold.sh <target-repo-path>
#
# After running, open Claude and run /respec to review and finalise the
# installation (write specs/.meta.json, add optional AGENTS.md / CHANGELOG.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"

# ── Args ───────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo-path>" >&2
  exit 1
fi

if [[ ! -d "$1" ]]; then
  echo "Error: target directory '$1' does not exist." >&2
  exit 1
fi

TARGET="$(cd "$1" && pwd)"

echo "Installing scaffold from $DIST_DIR"
echo "Target: $TARGET"
echo ""

# ── Copy files (never overwrite) ───────────────────────────────────────────────

# rsync --ignore-existing copies only files that do not already exist at the
# destination, preserving any customisations the target repo has already made.
rsync -a --ignore-existing "$DIST_DIR/" "$TARGET/"

echo "Scaffold files copied (existing files were not overwritten)."
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Open Claude and run /respec to review, set specs/.meta.json, and"
echo "     optionally add AGENTS.md and CHANGELOG.md."
echo "  3. Commit the new files."
