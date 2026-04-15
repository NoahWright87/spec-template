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
(\`templates/report-technical.md\`, \`templates/report-summary.md\`), or create the missing
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

# Look for the most recent report directory (YYYY-MM-DD/data.json)
_last_report_dir=$(ls -d "$WORKSPACE/$SCOUT_REPORTS_DIR/"*/ 2>/dev/null | sort | tail -1 || true)
_last_report_json="${_last_report_dir}data.json"

if [ -n "$_last_report_dir" ] && [ -f "$_last_report_json" ]; then
    _baseline_commit=$(git -C "$WORKSPACE" log --diff-filter=A --format=%H -- "$_last_report_json" 2>/dev/null | head -1 || true)
    _baseline_date=$(basename "${_last_report_dir%/}")
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

# ── Count filed issues (intake:filed label) ──────────────────────────────────
_intake_count=$(echo "$_open_issues" | jq '[.[] | select(.labels[]?.name == "intake:filed")] | length' 2>/dev/null || echo "0")

echo "[worker]   Startup: PRs merged: $_merged_prs_count, issues closed: $_closed_issues_count, open: $_new_issues_count, intake:filed: $_intake_count"

# ── Write data to files for agent consumption ────────────────────────────────
mkdir -p /tmp/scout-data

echo "$_git_log" > /tmp/scout-data/git-log.txt
echo "$_git_stat" > /tmp/scout-data/git-stat.txt
echo "$_merged_prs" | jq '.' > /tmp/scout-data/merged-prs.json
echo "$_closed_issues" | jq '.' > /tmp/scout-data/closed-issues.json
echo "$_open_prs" | jq '.' > /tmp/scout-data/open-prs.json
echo "$_open_issues" | jq '.' > /tmp/scout-data/open-issues.json

# ── Fetch sub-scout reports (meta-report mode) ───────────────────────────────
# When SCOUT_SUB_SCOUTS is set, read each sub-scout's already-generated
# data.json rather than re-fetching raw GitHub data. Three API calls per
# sub-scout: config → directory listing → report file.
_is_meta_report=false
_sub_repo_summary=""
_missing_scouts=""

if [ -n "${SCOUT_SUB_SCOUTS:-}" ]; then
    _is_meta_report=true
    echo "[worker]   Meta-report mode: reading sub-scout reports..."
    mkdir -p /tmp/scout-data/subordinates

    # ── Seed meta-index with the meta repo entry ─────────────────────────
    _meta_owner=$(echo "$TARGET_REPO" | cut -d/ -f1)
    _meta_name=$(echo "$TARGET_REPO" | cut -d/ -f2)
    _meta_open_prs_count=$(echo "$_open_prs" | jq 'length' 2>/dev/null || echo "0")

    _index_entries=$(jq -n \
        --arg  repo         "$TARGET_REPO" \
        --arg  name         "$_meta_name" \
        --arg  github_url   "https://github.com/$TARGET_REPO" \
        --arg  reports_url  "https://$_meta_owner.github.io/$_meta_name/" \
        --arg  data_dir     "/tmp/scout-data" \
        --argjson prs_merged    "$_merged_prs_count" \
        --argjson issues_closed "$_closed_issues_count" \
        --argjson open_prs      "$_meta_open_prs_count" \
        --argjson open_issues   "$_new_issues_count" \
        --argjson intake_filed  "$_intake_count" \
        '[{repo:$repo,name:$name,github_url:$github_url,reports_url:$reports_url,
           data_dir:$data_dir,is_meta:true,has_report:true,report_date:"current",
           prs_merged:$prs_merged,issues_closed:$issues_closed,open_prs:$open_prs,
           open_issues:$open_issues,intake_filed:$intake_filed}]')

    _total_merged=$_merged_prs_count
    _total_closed=$_closed_issues_count
    _total_open_prs=$_meta_open_prs_count
    _total_intake=$_intake_count

    # ── Fetch each sub-scout's latest data.json ───────────────────────────
    for _entry in $SCOUT_SUB_SCOUTS; do
        _sub_repo=$(echo "$_entry" | cut -d'|' -f1)
        _sub_scout_dir=$(echo "$_entry" | cut -d'|' -f2)
        _sub_owner=$(echo "$_sub_repo" | cut -d/ -f1)
        _sub_name=$(echo "$_sub_repo" | cut -d/ -f2)
        _sub_dir="/tmp/scout-data/subordinates/$_sub_owner/$_sub_name"
        mkdir -p "$_sub_dir"

        echo "[worker]     Sub-scout: $_sub_repo (scout_dir: $_sub_scout_dir)"

        # 1. Read the sub-scout's config to find its reports_dir
        _sub_config_b64=$(gh api "repos/$_sub_repo/contents/$_sub_scout_dir/config.yaml" \
            --jq '.content // empty' 2>/dev/null || echo "")
        if [ -n "$_sub_config_b64" ]; then
            _sub_reports_dir=$(printf '%s' "$_sub_config_b64" | base64 -d 2>/dev/null \
                | yq '.reports_dir // "docs/reports"' 2>/dev/null || echo "docs/reports")
        else
            _sub_reports_dir="docs/reports"
            echo "[worker]       no scout config found — defaulting reports_dir to docs/reports"
        fi

        # 2. Find the latest report date folder
        _latest_date=$(gh api "repos/$_sub_repo/contents/$_sub_reports_dir" \
            --jq '[.[] | select(.type=="dir") | .name] | sort | last // empty' \
            2>/dev/null || echo "")

        # 3. Fetch the report file
        _has_report=false
        _report_date=""
        _sub_merged=0; _sub_closed=0; _sub_open_prs=0; _sub_intake=0

        if [ -n "$_latest_date" ]; then
            _report_b64=$(gh api \
                "repos/$_sub_repo/contents/$_sub_reports_dir/$_latest_date/data.json" \
                --jq '.content // empty' 2>/dev/null || echo "")
            if [ -n "$_report_b64" ]; then
                if printf '%s' "$_report_b64" | base64 -d 2>/dev/null \
                        > "$_sub_dir/latest-report.json"; then
                    _has_report=true
                    _report_date="$_latest_date"
                    # Extract stats from the child's SprintReport summary
                    _sub_merged=$(jq '.summary.stats[] | select(.label=="PRs Merged")    | .value // 0' "$_sub_dir/latest-report.json" 2>/dev/null || echo "0")
                    _sub_closed=$(jq '.summary.stats[] | select(.label=="Issues Closed") | .value // 0' "$_sub_dir/latest-report.json" 2>/dev/null || echo "0")
                    _sub_open_prs=$(jq '.summary.stats[] | select(.label=="Open PRs")    | .value // 0' "$_sub_dir/latest-report.json" 2>/dev/null || echo "0")
                    _sub_intake=$(jq '.summary.stats[] | select(.label=="Filed Issues")  | .value // 0' "$_sub_dir/latest-report.json" 2>/dev/null || echo "0")
                    echo "[worker]       report from $_report_date — merged=$_sub_merged closed=$_sub_closed open_prs=$_sub_open_prs intake=$_sub_intake"
                fi
            fi
        fi

        if [ "$_has_report" = false ]; then
            echo "[worker]       ⚠ no report available yet"
            _missing_scouts="${_missing_scouts} $_sub_repo"
        fi

        _sub_entry=$(jq -n \
            --arg  repo        "$_sub_repo" \
            --arg  name        "$_sub_name" \
            --arg  github_url  "https://github.com/$_sub_repo" \
            --arg  reports_url "https://$_sub_owner.github.io/$_sub_name/" \
            --arg  data_dir    "$_sub_dir" \
            --arg  report_date "${_report_date:-}" \
            --arg  report_file "${_sub_dir}/latest-report.json" \
            --argjson has_report    "$_has_report" \
            --argjson prs_merged    "$_sub_merged" \
            --argjson issues_closed "$_sub_closed" \
            --argjson open_prs      "$_sub_open_prs" \
            --argjson intake_filed  "$_sub_intake" \
            '{repo:$repo,name:$name,github_url:$github_url,reports_url:$reports_url,
              data_dir:$data_dir,is_meta:false,has_report:$has_report,
              report_date:$report_date,report_file:$report_file,
              prs_merged:$prs_merged,issues_closed:$issues_closed,
              open_prs:$open_prs,intake_filed:$intake_filed}')
        _index_entries=$(echo "$_index_entries" | jq --argjson e "$_sub_entry" '. + [$e]')

        if [ "$_has_report" = true ]; then
            _total_merged=$(( _total_merged + _sub_merged ))
            _total_closed=$(( _total_closed + _sub_closed ))
            _total_open_prs=$(( _total_open_prs + _sub_open_prs ))
            _total_intake=$(( _total_intake + _sub_intake ))
            _sub_repo_summary="${_sub_repo_summary}
- \`$_sub_repo\`: report from ${_report_date} — ${_sub_merged} PRs merged, ${_sub_closed} issues closed, ${_sub_open_prs} open PRs, ${_sub_intake} filed"
        else
            _sub_repo_summary="${_sub_repo_summary}
- \`$_sub_repo\`: ⚠ no report available yet"
        fi
    done

    # ── Write pre-computed aggregate files ────────────────────────────────
    echo "$_index_entries" > /tmp/scout-data/meta-index.json

    jq -n \
        --argjson merged   "$_total_merged" \
        --argjson closed   "$_total_closed" \
        --argjson open_prs "$_total_open_prs" \
        --argjson intake   "$_total_intake" \
        '{total_prs_merged:$merged,total_issues_closed:$closed,
          total_open_prs:$open_prs,total_intake_filed:$intake}' \
        > /tmp/scout-data/meta-stats.json

    _missing_scouts=$(echo "$_missing_scouts" | xargs)  # trim whitespace
    echo "[worker]   Meta totals: merged=$_total_merged closed=$_total_closed open_prs=$_total_open_prs intake=$_total_intake"
    [ -n "$_missing_scouts" ] && echo "[worker]   Missing sub-scout reports: $_missing_scouts"
fi

# ── Build startup context for situation report ───────────────────────────────
_startup_context="### Report Data (pre-gathered by startup script)

All data below was gathered deterministically by the startup script. Use it directly —
do not re-fetch from GitHub or git.

**Report period:** ${_baseline_date} to ${_today}
**Report instructions:** \`.agents/scout/${SCOUT_REPORT_INSTRUCTIONS:-templates/report-technical.md}\`
**Reports directory:** \`${SCOUT_REPORTS_DIR}\`
**Next report date (computed):** ${_next_report_date}

**Summary metrics (${TARGET_REPO}):**
- PRs merged: ${_merged_prs_count}
- Issues closed: ${_closed_issues_count}
- Open PRs: $(echo "$_open_prs" | jq 'length' 2>/dev/null || echo "0")
- Open issues: ${_new_issues_count}
- Filed issues (intake:filed): ${_intake_count}

**Data files (read these for details):**
- \`/tmp/scout-data/git-log.txt\` — commit log since baseline
- \`/tmp/scout-data/git-stat.txt\` — diff stats since baseline
- \`/tmp/scout-data/merged-prs.json\` — recently merged PRs with descriptions
- \`/tmp/scout-data/closed-issues.json\` — recently closed issues
- \`/tmp/scout-data/open-prs.json\` — currently open PRs
- \`/tmp/scout-data/open-issues.json\` — currently open issues (filter for \`intake:filed\` label for Upcoming theme)

**Date advancement:** After generating the report, update \`.agents/scout/config.yaml\`
with \`next_report_date: \"${_next_report_date}\"\`. Commit both the report and the
config update in the same commit."

# Append meta-report section when sub-scouts are configured
if [ "$_is_meta_report" = true ]; then
    _startup_context="${_startup_context}

### Meta-Report Mode

**Mode: META-REPORT** — Follow \`/worker/agents/tasks/generate-meta-report.md\` instead of \`generate-report.md\`.

**Aggregate totals (meta repo + sub-scouts with available reports):**
- PRs merged: ${_total_merged}
- Issues closed: ${_total_closed}
- Open PRs: ${_total_open_prs}
- Filed issues (intake:filed): ${_total_intake}

**Sub-scouts:**${_sub_repo_summary}

**Missing sub-scout reports:** ${_missing_scouts:-none}

**Pre-computed files:**
- \`/tmp/scout-data/meta-index.json\` — one object per repo with: \`repo\`, \`name\`, \`github_url\`, \`reports_url\` (GitHub Pages), \`data_dir\`, \`is_meta\`, \`has_report\`, \`report_date\`, \`report_file\` (path to fetched data.json, when \`has_report\` is true), \`prs_merged\`, \`issues_closed\`, \`open_prs\`, \`intake_filed\`
- \`/tmp/scout-data/meta-stats.json\` — fleet-wide totals: \`total_prs_merged\`, \`total_issues_closed\`, \`total_open_prs\`, \`total_intake_filed\`

Sub-scout reports are at each entry's \`report_file\` path (SprintReport JSON — already summarized by that Scout)."
fi

# Export for use by the agent
export SCOUT_REPORT_DATE="$_today"
export SCOUT_NEXT_REPORT_DATE_COMPUTED="$_next_report_date"
export SCOUT_BASELINE_DATE="$_baseline_date"
