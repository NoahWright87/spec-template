#!/usr/bin/env bash
# prompt-assembly.sh — Assemble an agent's full prompt from tasks + manifest
#
# Reads the agent manifest file, extracts the ordered task list,
# concatenates task files, appends agent-specific content, and
# appends repo-specific overrides from the agent's .agents/ workspace.
#
# Usage: source this file, then call assemble_prompt <agent_name>
#
# Required globals:
#   AGENT_DIR   — path to worker/agents/ (e.g., /worker/agents)
#   TASK_DIR    — path to worker/tasks/  (e.g., /worker/tasks)
#   WORKSPACE   — path to target repo clone (e.g., /worker/workspace)

assemble_prompt() {
    local agent_name="$1"
    local agent_file="$AGENT_DIR/$agent_name.md"
    local prompt=""

    if [ ! -f "$agent_file" ]; then
        echo "[fleet] ERROR: Agent manifest not found: $agent_file" >&2
        return 1
    fi

    # ── 1. Extract ordered task list from "> Tasks:" line ────────────────
    local tasks_line
    tasks_line=$(grep '^> Tasks:' "$agent_file" | head -1)
    if [ -z "$tasks_line" ]; then
        echo "[fleet] ERROR: No '> Tasks:' line found in $agent_file" >&2
        return 1
    fi
    local tasks
    tasks=$(echo "$tasks_line" | sed 's/^> Tasks: //' | tr ',' '\n' | sed 's/^ *//;s/ *$//')

    # ── 2. Concatenate each task file in declared order ──────────────────
    local task_count=0
    for task_id in $tasks; do
        local task_file="$TASK_DIR/$task_id.md"
        if [ -f "$task_file" ]; then
            prompt+="$(cat "$task_file")"
            prompt+=$'\n\n---\n\n'
            task_count=$((task_count + 1))
        else
            echo "[fleet] WARNING: Task '$task_id' not found at $task_file" >&2
        fi
    done
    echo "[fleet] Assembled $task_count task(s) for agent '$agent_name'" >&2

    # ── 3. Append agent-specific content ─────────────────────────────────
    # Strip the title line and all "> " header lines; keep everything else
    local agent_body
    agent_body=$(sed '/^> /d; 1{/^# /d}' "$agent_file")
    prompt+="$agent_body"

    # ── 4. Append repo-specific agent AGENTS.md if present ───────────────
    local agent_workspace
    agent_workspace=$(grep '^> Workspace:' "$agent_file" | head -1 | sed 's/^> Workspace: //' | sed 's/^ *//;s/ *$//')
    if [ -n "$agent_workspace" ]; then
        local repo_agents_md="$WORKSPACE/$agent_workspace/AGENTS.md"
        if [ -f "$repo_agents_md" ]; then
            echo "[fleet] Found repo-specific AGENTS.md at $repo_agents_md" >&2
            prompt+=$'\n\n---\n\n## Repo-specific instructions\n\n'
            prompt+="$(cat "$repo_agents_md")"
        fi

        # ── 5. Append repo-specific config from agent's folder ───────────
        local repo_config="$WORKSPACE/$agent_workspace/config.json"
        if [ -f "$repo_config" ]; then
            echo "[fleet] Found repo-specific config at $repo_config" >&2
            prompt+=$'\n\n---\n\n## Repo-specific configuration\n\n```json\n'
            prompt+="$(cat "$repo_config")"
            prompt+=$'\n```'
        fi
    fi

    printf '%s' "$prompt"
}

# ── Helper: extract a header value from an agent manifest ────────────────
# Usage: get_agent_header <agent_file> <header_name>
# Example: get_agent_header /worker/agents/intake.md "Trigger"
get_agent_header() {
    local agent_file="$1"
    local header="$2"
    grep "^> ${header}:" "$agent_file" | head -1 | sed "s/^> ${header}: //" | sed 's/^ *//;s/ *$//'
}
