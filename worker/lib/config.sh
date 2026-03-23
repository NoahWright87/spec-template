#!/usr/bin/env bash
# config.sh — Read agent fleet configuration from target repo
#
# Checks .agents/config.json first (preferred), falls back to
# .claude/worker-config.yaml (legacy), then uses defaults.
#
# Required globals:
#   WORKSPACE          — path to target repo clone
#   CLAUDE_CONFIG_PATH — relative path to .claude/ in target repo (default: .claude)
#
# Sets:
#   MAX_OPEN_PRS — maximum number of open worker PRs (default: 1)
#   AGENTS       — newline-separated list of agent names to run

read_fleet_config() {
    local agents_config="$WORKSPACE/.agents/config.json"
    local legacy_config="$WORKSPACE/$CLAUDE_CONFIG_PATH/worker-config.yaml"

    # ── Check for FLEET_AGENTS env var override (set by k8s overlay) ─────
    if [ -n "${FLEET_AGENTS:-}" ]; then
        echo "[fleet] Using FLEET_AGENTS env var override: $FLEET_AGENTS"
        AGENTS=$(echo "$FLEET_AGENTS" | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    fi

    # ── Preferred: .agents/config.json ───────────────────────────────────
    if [ -f "$agents_config" ]; then
        echo "[fleet] Reading fleet config: $agents_config"
        MAX_OPEN_PRS=$(jq -r '.max_open_prs // 1' "$agents_config" 2>/dev/null || echo "1")

        # Only read agents from config if FLEET_AGENTS wasn't set
        if [ -z "${FLEET_AGENTS:-}" ]; then
            # Collect enabled agents from per-agent folders
            # An agent is enabled if its config.json exists and doesn't have "enabled": false
            local _config_agents=""
            for agent_dir in "$WORKSPACE/.agents"/*/; do
                [ -d "$agent_dir" ] || continue
                local _aname
                _aname=$(basename "$agent_dir")
                local _agent_config="$agent_dir/config.json"
                if [ -f "$_agent_config" ]; then
                    local _enabled
                    _enabled=$(jq -r '.enabled // true' "$_agent_config" 2>/dev/null || echo "true")
                    if [ "$_enabled" = "true" ]; then
                        _config_agents="${_config_agents}${_aname}\n"
                    else
                        echo "[fleet] Agent '$_aname' disabled in config"
                    fi
                else
                    # Agent folder exists but no config — treat as enabled
                    _config_agents="${_config_agents}${_aname}\n"
                fi
            done
            if [ -n "$_config_agents" ]; then
                AGENTS=$(printf '%b' "$_config_agents" | sed '/^$/d')
            fi
        fi
        return 0
    fi

    # ── Legacy fallback: .claude/worker-config.yaml ──────────────────────
    if [ -f "$legacy_config" ]; then
        echo "[fleet] Reading legacy config: $legacy_config (migrate to .agents/config.json)"
        MAX_OPEN_PRS=$(python3 -c "
import sys, re
text = open('$legacy_config').read()
m = re.search(r'^max_open_prs:\s*(\d+)', text, re.MULTILINE)
print(m.group(1) if m else '1')
" 2>/dev/null || echo "1")

        if [ -z "${FLEET_AGENTS:-}" ]; then
            AGENTS=$(python3 -c "
import sys, re
text = open('$legacy_config').read()
agents = re.findall(r'^\s+-\s+(\S+)', text[text.find('agents:'):], re.MULTILINE) if 'agents:' in text else []
print('\n'.join(agents))
" 2>/dev/null || echo "")
        fi
        return 0
    fi

    # ── No config found — use defaults ───────────────────────────────────
    echo "[fleet] No fleet config found — using defaults."
    MAX_OPEN_PRS="${MAX_OPEN_PRS:-1}"
    return 0
}

# ── Set defaults for anything not configured ─────────────────────────────
apply_config_defaults() {
    MAX_OPEN_PRS="${MAX_OPEN_PRS:-1}"
    if [ -z "${AGENTS:-}" ]; then
        AGENTS="intake
knock-out-todos"
    fi
    echo "[fleet] Max open PRs: $MAX_OPEN_PRS"
    echo "[fleet] Agents: $(echo "$AGENTS" | tr '\n' ' ')"
}
