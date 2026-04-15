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
# sub_scouts: []  # List Scout-enabled repos whose reports this Scout should summarize.
#   Each entry is either a plain "owner/repo" string (scout_dir defaults to .agents/scout/)
#   or an object with an optional scout_dir override.
#   Example:
#     sub_scouts:
#       - myorg/backend
#       - myorg/frontend
#       - repo: myorg/platform
#         scout_dir: .agents/scout
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

# ── Write welcome report (only if reports dir is empty) ─────────────────
_reports_dir="$WORKSPACE/${SCOUT_REPORTS_DIR:-docs/reports}"
_welcome_report="$_reports_dir/welcome/data.json"
_welcome_template="/worker/agents/scout/templates/welcome-report.json"

if [ ! -d "$_reports_dir" ] || [ -z "$(ls -A "$_reports_dir" 2>/dev/null)" ]; then
    mkdir -p "$_reports_dir/welcome"
    if [ -f "$_welcome_template" ]; then
        _repo_name="${TARGET_REPO#*/}"
        sed \
            -e "s|__REPO_NAME__|${_repo_name}|g" \
            -e "s|__TARGET_REPO__|${TARGET_REPO}|g" \
            -e "s|__TODAY__|${_init_today}|g" \
            -e "s|__NEXT_REPORT_DATE__|${_init_next_date}|g" \
            "$_welcome_template" > "$_welcome_report"
        echo "[worker]   Scout init: wrote welcome report to ${SCOUT_REPORTS_DIR:-docs/reports}/welcome/data.json"
    fi
fi

# ── Create GH Pages workflow (only if missing) ───────────────────────────
_workflow_file="$WORKSPACE/.github/workflows/reports.yml"
if [ ! -f "$_workflow_file" ]; then
    mkdir -p "$WORKSPACE/.github/workflows"
    _reports_path="${SCOUT_REPORTS_DIR:-docs/reports}"
    cat > "$_workflow_file" <<EOF
name: Publish Scout Reports

on:
  push:
    branches: [main]
    paths:
      - '${_reports_path}/**'
      - '.github/workflows/reports.yml'
  pull_request:
    types: [opened, synchronize, reopened, closed]
    paths:
      - '${_reports_path}/**'
      - '.github/workflows/reports.yml'
  workflow_dispatch:

permissions:
  contents: write       # push to gh-pages branch
  pull-requests: write  # post preview comments

concurrency:
  group: pages-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-deploy:
    if: github.event_name != 'pull_request' || github.event.action != 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set base URL
        id: base
        run: |
          REPO="\${GITHUB_REPOSITORY#*/}"
          if [ "\${{ github.event_name }}" = "pull_request" ]; then
            echo "url=/\${REPO}/pr-preview/pr-\${{ github.event.pull_request.number }}/" >> \$GITHUB_OUTPUT
          else
            echo "url=/\${REPO}/" >> \$GITHUB_OUTPUT
          fi

      - name: Build reports app
        uses: NoahWright87/repo-report/.github/actions/build-reports@main
        with:
          reports_path: ${_reports_path}
          output_path: _site
          base_url: \${{ steps.base.outputs.url }}

      - name: Deploy to GitHub Pages
        if: github.event_name != 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: gh-pages
          folder: _site
          clean: true
          clean-exclude: pr-preview

      - name: Deploy preview
        if: github.event_name == 'pull_request'
        uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: gh-pages
          folder: _site
          target-folder: pr-preview/pr-\${{ github.event.pull_request.number }}
          clean: false

      - name: Post preview comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const owner = context.repo.owner;
            const repo = context.repo.repo;
            const pr = context.payload.pull_request.number;
            const url = \`https://\${owner}.github.io/\${repo}/pr-preview/pr-\${pr}/\`;
            const marker = '<!-- scout-preview -->';
            const body = \`\${marker}\n🤖 Claude (scout): Preview is ready!\n\n**[View report →](\${url})**\n\n_Updates automatically when new commits are pushed to this PR._\`;

            const { data: comments } = await github.rest.issues.listComments(
              { owner, repo, issue_number: pr }
            );
            const existing = comments.find(c => c.body.includes(marker));
            if (existing) {
              await github.rest.issues.updateComment(
                { owner, repo, comment_id: existing.id, body }
              );
            } else {
              await github.rest.issues.createComment(
                { owner, repo, issue_number: pr, body }
              );
            }

  cleanup:
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: gh-pages

      - name: Remove preview
        run: |
          dir="pr-preview/pr-\${{ github.event.pull_request.number }}"
          if [ -d "\$dir" ]; then
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git rm -rf "\$dir"
            git commit -m "Remove preview for PR #\${{ github.event.pull_request.number }}"
            git push
          fi
EOF
    echo "[worker]   Scout init: wrote .github/workflows/reports.yml"
fi

echo "[worker]   Scout init: .agents/scout/ ready (missing files filled in)"
