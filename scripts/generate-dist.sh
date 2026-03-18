#!/usr/bin/env bash
# generate-dist.sh — build dist/ from scaffold source files
#
# Run this after modifying any scaffold source files.
# Commit the resulting dist/ directory so downstream users can consume it directly.
#
# Usage: ./scripts/generate-dist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"

# ── Helpers ────────────────────────────────────────────────────────────────────

# Prepend an auto-generated header to a markdown file
md_header() {
  local src_rel="$1"
  printf '<!-- AUTO-GENERATED — do not edit directly.\n'
  printf '     Source: %s\n' "$src_rel"
  printf '     Regenerate: run scripts/generate-dist.sh from the repo root. -->\n\n'
}

# Prepend an auto-generated header to a YAML/shell file
comment_header() {
  local src_rel="$1"
  printf '# AUTO-GENERATED — do not edit directly.\n'
  printf '# Source: %s\n' "$src_rel"
  printf '# Regenerate: run scripts/generate-dist.sh from the repo root.\n\n'
}

# Copy a file to dist/ with the appropriate header prepended
copy_with_header() {
  local src="$1"        # absolute source path
  local dst="$2"        # absolute dest path
  local src_rel="${src#$REPO_ROOT/}"

  mkdir -p "$(dirname "$dst")"

  case "$src" in
    *.yml|*.yaml|*.sh) { comment_header "$src_rel"; cat "$src"; } > "$dst" ;;
    *)                 { md_header "$src_rel"; cat "$src"; } > "$dst" ;;
  esac
}

# ── Clean ──────────────────────────────────────────────────────────────────────
echo "Cleaning dist/..."
rm -rf "$DIST_DIR"

# ── Commands (.claude/commands/) ───────────────────────────────────────────────
echo "Copying commands..."
copy_with_header \
  "$REPO_ROOT/.claude/commands/what-now.md" \
  "$DIST_DIR/.claude/commands/what-now.md"
for cmd in respec.md intake.md knock-out-todos.md spec-backfill.md refine.md pr-review.md; do
  copy_with_header \
    "$REPO_ROOT/.claude/commands/lib/$cmd" \
    "$DIST_DIR/.claude/commands/lib/$cmd"
done

# ── Spec templates (scaffold/specs/) ──────────────────────────────────────────
echo "Copying spec templates..."
for file in spec.md spec.todo.md INTAKE.md AGENTS.md README.md; do
  copy_with_header \
    "$REPO_ROOT/scaffold/specs/$file" \
    "$DIST_DIR/specs/$file"
done
copy_with_header \
  "$REPO_ROOT/scaffold/specs/deps/README.md" \
  "$DIST_DIR/specs/deps/README.md"

# ── GitHub Actions workflow ────────────────────────────────────────────────────
echo "Copying GitHub Actions workflow..."
copy_with_header \
  "$REPO_ROOT/.github/workflows/spec-check.yml" \
  "$DIST_DIR/.github/workflows/spec-check.yml"

# ── Worker config ────────────────────────────────────────────────────────────
echo "Copying worker config..."
copy_with_header \
  "$REPO_ROOT/scaffold/worker-config.yaml" \
  "$DIST_DIR/.claude/worker-config.yaml"

echo ""
echo "dist/ generated successfully."
echo "Review changes, then commit dist/ to the repo."
