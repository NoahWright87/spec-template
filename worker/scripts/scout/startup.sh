#!/usr/bin/env bash
# startup-scout.sh — gather data for the scout agent before Claude runs.
# Sourced by entrypoint.sh. Writes data files and sets _startup_context.
#
# All date math and data gathering happens here in bash, not in the LLM.
# The agent reads pre-gathered data from /tmp/scout-report-data.yaml and
# focuses on synthesis and writing — the things LLMs are good at.

_startup_context=""

# ── Onboarding: initialize .agents/scout/ if any required files are missing ──
_scout_dir="$WORKSPACE/.agents/scout"
_scout_needs_init=false
for _required in "config.yaml" "NOTES.md" "templates"; do
    case "$_required" in
        config.yaml|NOTES.md)
            if [ ! -f "$_scout_dir/$_required" ]; then
                echo "[worker]   Scout startup: missing required file: $_required — running init"
                _scout_needs_init=true
                break
            fi
            ;;
        templates)
            _templates_src="/worker/agents/scout/templates"
            if [ ! -d "$_scout_dir/templates" ]; then
                echo "[worker]   Scout startup: missing required directory: templates/ — running init"
                _scout_needs_init=true
                break
            fi
            # Ensure the configured report_instructions template (or the default) exists
            _required_template_file="$_scout_dir/templates/report-technical.md"
            if [ -f "$_scout_dir/config.yaml" ]; then
                _configured_report_instructions="$(yq -r '.report_instructions // ""' "$_scout_dir/config.yaml" 2>/dev/null || echo "")"
                if [ -n "$_configured_report_instructions" ]; then
                    _required_template_file="$_scout_dir/$_configured_report_instructions"
                fi
            fi
            if [ ! -f "$_required_template_file" ]; then
                # Determine whether init.sh can fix this: only bundled templates (under templates/
                # and present in the source) can be restored by init. Custom paths are config errors.
                _rel_path="${_configured_report_instructions:-templates/report-technical.md}"
                _src_equiv="$_templates_src/${_rel_path#templates/}"
                if [[ "$_rel_path" == templates/* ]] && [ -f "$_src_equiv" ]; then
                    echo "[worker]   Scout startup: missing bundled template: $_rel_path — running init"
                    _scout_needs_init=true
                    break
                else
                    echo "[worker]   Scout startup: ERROR: report_instructions not found: $_rel_path" >&2
                    echo "[worker]   Scout startup: Custom template paths cannot be created by init. Fix config.yaml." >&2
                    _startup_context="### Configuration Error

The file configured as \`report_instructions\` in \`.agents/scout/config.yaml\` does not exist:
\`$_rel_path\`

Either update \`report_instructions\` in \`.agents/scout/config.yaml\` to use a bundled template
(\`templates/report-technical.md\`, \`templates/report-stakeholder.md\`), or create the missing
file at \`.agents/scout/$_rel_path\` and commit it."
                    return 0
                fi
            fi
            ;;
    esac
done

if [ "$_scout_needs_init" = true ]; then
    source "$SCRIPT_DIR/scout/init.sh"
    _startup_context="### Onboarding Mode

The init script has created or completed \`.agents/scout/\` with any missing files (config, report templates, NOTES.md).
These files are ready to commit. Open a PR and add inline review comments per \`/worker/agents/tasks/scout-onboarding.md\`.

**Do not generate a report on this run** — the team needs to review and merge the config first."
    return 0
fi

# ── Ensure scout is looking at latest main ───────────────────────────────────
echo "[worker]   Startup: Ensuring workspace is up to date with $TARGET_BRANCH..."
git -C "$WORKSPACE" fetch origin "$TARGET_BRANCH" 2>/dev/null || true

# ── Read reports directory from config ───────────────────────────────────────
SCOUT_REPORTS_DIR=$(yq '.reports_dir // "docs/reports"' "$WORKSPACE/.agents/scout/config.yaml" 2>/dev/null || echo "docs/reports")
export SCOUT_REPORTS_DIR

# ── Calculate report dates ───────────────────────────────────────────────────
_today=$(date +%Y-%m-%d)
# Next report date: today + interval (computed in bash, NOT by LLM)
if command -v gdate > /dev/null 2>&1; then
    # macOS with coreutils
    _next_report_date=$(gdate -d "$_today + ${SCOUT_REPORT_INTERVAL:-14} days" +%Y-%m-%d)
elif date -d "today" > /dev/null 2>&1; then
    # GNU date (Linux)
    _next_report_date=$(date -d "$_today + ${SCOUT_REPORT_INTERVAL:-14} days" +%Y-%m-%d)
else
    # BusyBox/Alpine date fallback
    _next_report_date=$(date -d "@$(( $(date -d "$_today" +%s 2>/dev/null || date +%s) + ${SCOUT_REPORT_INTERVAL:-14} * 86400 ))" +%Y-%m-%d 2>/dev/null || echo "unknown")
fi
echo "[worker]   Startup: Report date: $_today, next: $_next_report_date"

# ── Determine baseline (diff range start) ───────────────────────────────────
_baseline_commit=""
_baseline_date=""
_specs_dir=$(yq '.settings.specs_dir // "specs"' "$WORKER_CONFIG" 2>/dev/null || echo "specs")

# Look for the most recent report file
_last_report=$(ls "$WORKSPACE/$SCOUT_REPORTS_DIR/"*.md 2>/dev/null | sort | tail -1 || true)

if [ -n "$_last_report" ]; then
    _baseline_commit=$(git -C "$WORKSPACE" log --diff-filter=A --format=%H -- "$_last_report" 2>/dev/null | head -1 || true)
    _baseline_date=$(basename "$_last_report" .md)
    echo "[worker]   Startup: Baseline from last report: $_baseline_date (commit: ${_baseline_commit:-unknown})"
fi

if [ -z "$_baseline_commit" ]; then
    # No previous report — use 30-day lookback
    _baseline_commit=$(git -C "$WORKSPACE" log --since="30 days ago" --format=%H 2>/dev/null | tail -1 || true)
    _baseline_date="(30 days ago)"
    echo "[worker]   Startup: No previous report — using 30-day lookback"
fi

if [ -z "$_baseline_commit" ]; then
    _baseline_commit=$(git -C "$WORKSPACE" rev-list --max-parents=0 HEAD 2>/dev/null | head -1 || echo "HEAD~50")
    _baseline_date="(repo start)"
fi

# ── Gather git activity ──────────────────────────────────────────────────────
_git_log=$(git -C "$WORKSPACE" log "$_baseline_commit..HEAD" --oneline --no-merges 2>/dev/null || echo "(no commits)")
_git_stat=$(git -C "$WORKSPACE" diff "$_baseline_commit..HEAD" --stat 2>/dev/null || echo "(no changes)")

# ── Gather GitHub data ───────────────────────────────────────────────────────
# Fetch ALL merged PRs (no arbitrary limit) with descriptions — agents write thorough
# PR descriptions that help explain *why* things happened.
_merged_prs=$(gh pr list \
    --repo "$TARGET_REPO" \
    --state merged \
    --json number,title,mergedAt,author,body,url \
    --limit 200 2>/dev/null || echo "[]")

_closed_issues=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state closed \
    --json number,title,closedAt,labels,url \
    --limit 200 2>/dev/null || echo "[]")

_open_prs=$(gh pr list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,title,labels,headRefName,url \
    2>/dev/null || echo "[]")

_open_issues=$(gh issue list \
    --repo "$TARGET_REPO" \
    --state open \
    --json number,title,labels,url \
    2>/dev/null || echo "[]")

# Count new issues opened in the period
_new_issues_count=$(echo "$_open_issues" | jq 'length' 2>/dev/null || echo "0")
_closed_issues_count=$(echo "$_closed_issues" | jq 'length' 2>/dev/null || echo "0")
_merged_prs_count=$(echo "$_merged_prs" | jq 'length' 2>/dev/null || echo "0")

# ── Gather TODO status ───────────────────────────────────────────────────────
_refined_count=$(grep -r '^- 💎' "$WORKSPACE/$_specs_dir/"**/*.todo.md 2>/dev/null | wc -l | tr -d ' ' || echo "0")
_unrefined_count=$(grep -r '^- ❓' "$WORKSPACE/$_specs_dir/"**/*.todo.md 2>/dev/null | wc -l | tr -d ' ' || echo "0")
_waiting_count=$(grep -r '^- ⏳' "$WORKSPACE/$_specs_dir/"**/*.todo.md 2>/dev/null | wc -l | tr -d ' ' || echo "0")

echo "[worker]   Startup: PRs merged: $_merged_prs_count, issues closed: $_closed_issues_count, TODOs: 💎$_refined_count ❓$_unrefined_count ⏳$_waiting_count"

# ── Write data to files for agent consumption ────────────────────────────────
mkdir -p /tmp/scout-data

echo "$_git_log" > /tmp/scout-data/git-log.txt
echo "$_git_stat" > /tmp/scout-data/git-stat.txt
echo "$_merged_prs" | jq '.' > /tmp/scout-data/merged-prs.json
echo "$_closed_issues" | jq '.' > /tmp/scout-data/closed-issues.json
echo "$_open_prs" | jq '.' > /tmp/scout-data/open-prs.json
echo "$_open_issues" | jq '.' > /tmp/scout-data/open-issues.json

# ── Build startup context for situation report ───────────────────────────────
_startup_context="### Report Data (pre-gathered by startup script)

All data below was gathered deterministically by the startup script. Use it directly —
do not re-fetch from GitHub or git.

**Report period:** ${_baseline_date} to ${_today}
**Report instructions:** \`.agents/scout/${SCOUT_REPORT_INSTRUCTIONS:-templates/report-technical.md}\`
**Reports directory:** \`${SCOUT_REPORTS_DIR}\`
**Next report date (computed):** ${_next_report_date}

**Summary metrics:**
- PRs merged: ${_merged_prs_count}
- Issues closed: ${_closed_issues_count}
- Open issues: ${_new_issues_count}
- TODOs: 💎 ${_refined_count} (refined) | ❓ ${_unrefined_count} (unrefined) | ⏳ ${_waiting_count} (waiting)

**Data files (read these for details):**
- \`/tmp/scout-data/git-log.txt\` — commit log since baseline
- \`/tmp/scout-data/git-stat.txt\` — diff stats since baseline
- \`/tmp/scout-data/merged-prs.json\` — recently merged PRs with descriptions
- \`/tmp/scout-data/closed-issues.json\` — recently closed issues
- \`/tmp/scout-data/open-prs.json\` — currently open PRs
- \`/tmp/scout-data/open-issues.json\` — currently open issues

**Date advancement:** After generating the report, update \`.agents/scout/config.yaml\`
with \`next_report_date: \"${_next_report_date}\"\`. Commit both the report and the
config update in the same commit."

# Export for use by the agent
export SCOUT_REPORT_DATE="$_today"
export SCOUT_NEXT_REPORT_DATE_COMPUTED="$_next_report_date"
export SCOUT_BASELINE_DATE="$_baseline_date"
