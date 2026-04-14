#!/usr/bin/env bash
# init.sh — initialize .agents/scout/ in the target repo.
# Sourced by startup.sh when any required Scout files are missing.
# Non-destructive: skips files that already exist, so safe to run on partial setups.
# Does all deterministic filesystem work so Claude only needs to commit + open PR.

_scout_dir="$WORKSPACE/.agents/scout"
_templates_src="/worker/agents/scout/templates"

echo "[worker]   Scout init: creating .agents/scout/ directory..."
mkdir -p "$_scout_dir"

# ── Compute default next_report_date (14 days from today) ───────────────
_init_today=$(date +%Y-%m-%d)
if command -v gdate > /dev/null 2>&1; then
    _init_next_date=$(gdate -d "$_init_today + 14 days" +%Y-%m-%d)
elif date -d "today" > /dev/null 2>&1; then
    _init_next_date=$(date -d "$_init_today + 14 days" +%Y-%m-%d)
else
    _init_next_date=$(date -d "@$(( $(date +%s) + 14 * 86400 ))" +%Y-%m-%d 2>/dev/null || echo "unknown")
fi

# ── Write default config (only if missing) ───────────────────────────────
if [ ! -f "$_scout_dir/config.yaml" ]; then
    cat > "$_scout_dir/config.yaml" <<EOF
max_open_prs: 1
next_report_date: "${_init_next_date}"
report_interval_days: 14
report_instructions: templates/report-technical.md
reports_dir: docs/reports
EOF
    echo "[worker]   Scout init: wrote config.yaml"
fi

# ── Copy report templates (non-destructive; fill in missing files) ───────
if [ ! -d "$_scout_dir/templates" ]; then
    mkdir -p "$_scout_dir/templates"
fi

if [ -d "$_templates_src" ]; then
    (
        cd "$_templates_src" || {
            echo "[worker]   Scout init: ERROR: unable to cd into template source '$_templates_src'" >&2
            exit 1
        }
        find . -type f | while IFS= read -r _rel_path; do
            _src_file="$_templates_src/$_rel_path"
            _dest_file="$_scout_dir/templates/$_rel_path"
            if [ ! -e "$_dest_file" ]; then
                mkdir -p "$(dirname "$_dest_file")"
                cp "$_src_file" "$_dest_file"
            fi
        done
    )
    echo "[worker]   Scout init: ensured report templates are present"
fi

# ── Create starter notes (only if missing) ───────────────────────────────
if [ ! -f "$_scout_dir/NOTES.md" ]; then
    cat > "$_scout_dir/NOTES.md" <<'EOF'
# Scout Notes

<!-- The Scout agent uses this file to track observations across runs. -->
EOF
    echo "[worker]   Scout init: wrote NOTES.md"
fi

# ── Create GH Pages workflow (only if missing) ───────────────────────────
_workflow_file="$WORKSPACE/.github/workflows/reports.yml"
if [ ! -f "$_workflow_file" ]; then
    mkdir -p "$WORKSPACE/.github/workflows"
    # Derive base_url from repo name (TARGET_REPO = owner/repo → /repo).
    # For a root Pages repo (username.github.io), set base_url to / manually.
    _repo_name="${TARGET_REPO#*/}"
    _base_url="/${_repo_name}"
    cat > "$_workflow_file" <<EOF
name: Publish Scout Reports

on:
  push:
    branches: [main]
    paths:
      - '${SCOUT_REPORTS_DIR:-docs/reports}/**'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build reports app
        uses: NoahWright87/repo-report/.github/actions/build-reports@v1
        with:
          reports_path: ${SCOUT_REPORTS_DIR:-docs/reports}
          output_path: _site
          base_url: ${_base_url}

      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: \${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
EOF
    echo "[worker]   Scout init: wrote .github/workflows/reports.yml"
fi

echo "[worker]   Scout init: .agents/scout/ ready (missing files filled in)"
