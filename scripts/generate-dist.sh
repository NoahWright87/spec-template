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

# Copy a file to dist/ without any header (for JSON and files that shouldn't be modified)
copy_raw() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# Generate a loader stub for a command
# Usage: generate_stub <command_name> <source_path_in_repo>
generate_stub() {
  local cmd_name="$1"    # e.g., "intake"
  local src_path="$2"    # e.g., ".claude/commands/lib/intake.md"
  local dst="$3"         # absolute dest path

  mkdir -p "$(dirname "$dst")"
  cat > "$dst" << STUB_EOF
<!-- AUTO-GENERATED loader stub — do not edit.
     The full command lives in the spec-template source repo.
     To update this stub: run /respec -->

# /$cmd_name

This command is managed by [spec-template](https://github.com/NoahWright87/spec-template).

## Execute

1. Read \`specs/.meta.json\` and extract the \`source\` field (the source repo URL)
2. Construct the raw file URL: replace the GitHub URL with a raw content URL, targeting the \`main\` branch, path: \`$src_path\`
   - For \`https://github.com/OWNER/REPO\`, the raw URL is \`https://raw.githubusercontent.com/OWNER/REPO/main/$src_path\`
3. Use WebFetch to retrieve the full command file
4. Follow the fetched instructions exactly — they are the complete command
STUB_EOF
}

# ── Clean ──────────────────────────────────────────────────────────────────────
echo "Cleaning dist/..."
rm -rf "$DIST_DIR"

# ── Commands (.claude/commands/) ───────────────────────────────────────────────
# /respec is the bootstrapper — it must be a full local copy so it can update everything else.
# All other commands are loader stubs that fetch the real command from the source repo at runtime.
echo "Generating command stubs..."
generate_stub "what-now" ".claude/commands/what-now.md" \
  "$DIST_DIR/.claude/commands/what-now.md"
# /respec stays as a full copy (it's the updater that must work without fetching)
copy_with_header \
  "$REPO_ROOT/.claude/commands/lib/respec.md" \
  "$DIST_DIR/.claude/commands/lib/respec.md"
for cmd in intake knock-out-todos spec-backfill refine pr-review; do
  generate_stub "$cmd" ".claude/commands/lib/$cmd.md" \
    "$DIST_DIR/.claude/commands/lib/$cmd.md"
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

# ── Worker config (legacy — kept for backward compatibility) ─────────────────
echo "Copying legacy worker config..."
copy_with_header \
  "$REPO_ROOT/scaffold/worker-config.yaml" \
  "$DIST_DIR/.claude/worker-config.yaml"

# ── .agents/ directory (fleet configuration for target repos) ────────────────
echo "Generating .agents/ directory..."
copy_raw \
  "$REPO_ROOT/scaffold/.agents/CLAUDE.md" \
  "$DIST_DIR/.agents/CLAUDE.md"
copy_raw \
  "$REPO_ROOT/scaffold/.agents/AGENTS.md" \
  "$DIST_DIR/.agents/AGENTS.md"
copy_raw \
  "$REPO_ROOT/scaffold/.agents/README.md" \
  "$DIST_DIR/.agents/README.md"
copy_raw \
  "$REPO_ROOT/scaffold/.agents/config.json" \
  "$DIST_DIR/.agents/config.json"
# Per-agent directories
for agent in intake knock-out-todos; do
  copy_raw \
    "$REPO_ROOT/scaffold/.agents/$agent/AGENTS.md" \
    "$DIST_DIR/.agents/$agent/AGENTS.md"
  copy_raw \
    "$REPO_ROOT/scaffold/.agents/$agent/config.json" \
    "$DIST_DIR/.agents/$agent/config.json"
done

echo ""
echo "dist/ generated successfully."
echo "Review changes, then commit dist/ to the repo."
