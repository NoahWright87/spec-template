#!/usr/bin/env bash
# generate-roadmap.sh — generate docs/ROADMAP.md from all *.todo.md spec files
#
# Reads every specs/**/*.todo.md file, extracts open TODO items, and produces
# a consolidated human-readable roadmap at docs/ROADMAP.md with links back to
# the individual spec files.
#
# Run this whenever TODO specs change, or automate it in CI.
#
# Usage: ./scripts/generate-roadmap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPECS_DIR="$REPO_ROOT/specs"
OUT_DIR="$REPO_ROOT/docs"
OUT_FILE="$OUT_DIR/ROADMAP.md"

mkdir -p "$OUT_DIR"

# Collect todo files, sorted.
# WHY avoid mapfile: mapfile requires Bash 4+; macOS ships Bash 3.2 by default.
TODO_FILES=()
while IFS= read -r todo_file; do
  TODO_FILES+=("$todo_file")
done < <(find "$SPECS_DIR" -name "*.todo.md" | sort)

if [[ ${#TODO_FILES[@]} -eq 0 ]]; then
  echo "No *.todo.md files found under specs/. Nothing to generate."
  exit 0
fi

# ── Write output ───────────────────────────────────────────────────────────────

{
  echo "<!-- AUTO-GENERATED — do not edit directly."
  echo "     Source: specs/**/*.todo.md"
  echo "     Regenerate: run scripts/generate-roadmap.sh from the repo root. -->"
  echo ""
  echo "# Roadmap"
  echo ""
  echo "Open TODO items across all spec files, grouped by area."
  echo "Generated $(date -u +%Y-%m-%d) from the [spec files](../specs/)."
  echo ""

  for todo_file in "${TODO_FILES[@]}"; do
    rel="${todo_file#$REPO_ROOT/}"   # e.g. specs/spec.todo.md

    # Extract the first H1 heading as the section title
    title=$(grep -m1 '^# ' "$todo_file" | sed 's/^# //' || true)
    [[ -z "$title" ]] && title="$(basename "$todo_file" .todo.md)"

    # Collect only top-level TODO bullets (lines starting with "- "), excluding
    # Reminders section and section headings
    items=()
    in_reminders=false
    while IFS= read -r line; do
      if [[ "$line" =~ ^##[[:space:]]Reminders ]]; then
        in_reminders=true
        continue
      fi
      if [[ "$line" =~ ^## ]]; then
        in_reminders=false
        continue
      fi
      $in_reminders && continue
      if [[ "$line" =~ ^-[[:space:]] ]]; then
        items+=("$line")
      fi
    done < "$todo_file"

    [[ ${#items[@]} -eq 0 ]] && continue

    echo "## [$title](../$rel)"
    echo ""
    for item in "${items[@]}"; do
      echo "$item"
    done
    echo ""
  done

} > "$OUT_FILE"

echo "Roadmap written to $OUT_FILE (${#TODO_FILES[@]} spec file(s) processed)."
