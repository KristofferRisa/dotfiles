#!/bin/bash
# Antigravity CLI (agy) status line and installer merge tests.
# shellcheck disable=SC2016
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$HERE/../.."
SCRIPT="$REPO/.agy/statusline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home" XDG_CACHE_HOME="$WORK/cache"
export NO_COLOR=1 AGY_STATUSLINE_WEATHER=0 SYNAPSE_STATUSLINE=0
mkdir -p "$HOME" "$WORK/proj"

failures=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s\n  expected: %s\n  got:      %s\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

payload() {
  local sid="$1"
  jq -cn --arg sid "$sid" --arg dir "$WORK/proj" '{
    session_id: $sid,
    conversation_id: $sid,
    cwd: $dir,
    workspace: { current_dir: $dir, project_dir: $dir },
    version: "1.5.7",
    plan_tier: "Pro",
    cycle_mode: "auto",
    sandbox: { enabled: true },
    model: { id: "Gemini 4 Argon (Medium)", display_name: "Gemini 4 Argon (Medium)", effort: "medium" },
    context_window: {
      total_input_tokens: 88244,
      total_output_tokens: 61074,
      context_window_size: 1000000,
      used_percentage: 26,
      current_usage: { input_tokens: 180000, output_tokens: 400, cache_creation_input_tokens: 0, cache_read_input_tokens: 80000 }
    },
    quota: {
      "gemini-weekly": { remaining_fraction: 0.75, reset_in_seconds: 302400 }
    },
    subagents: [{ name: "research", role: "Researcher", status: "running" }],
    task_count: 1,
    artifact_count: 2,
    cost: { total_usd: 0.42, subagent_usd: 0, estimated: true }
  }'
}

# ---- full panel ----
out="$(payload s1 | bash "$SCRIPT")"
check "header version and tier" "$(head -1 <<<"$out" | grep -c 'AGY 1\.5\.7 Pro')" "1"
check "header mode and sandbox" "$(head -1 <<<"$out" | grep -c 'auto.*sandbox')" "1"
check "model does not duplicate effort" "$(grep -c 'Gemini 4 Argon (Medium) · medium' <<<"$out" || true)" "0"
check "model label present" "$(grep -c 'Gemini 4 Argon (Medium)' <<<"$out")" "1"
check "context row" "$(grep -c 'CONTEXT.*26%.*260k of 1M' <<<"$out")" "1"
check "weekly quota row" "$(grep -c '7 DAY.*25%' <<<"$out")" "1"
check "session cost estimated" "$(grep -c 'SESSION.*~\$0\.42.*61k out.*cache 30%.*1 sub.*1 task.*2 art' <<<"$out")" "1"
check "no synapse without cache" "$(grep -c 'SYNAPSE' <<<"$out" || true)" "0"

# Effort is appended when not already in display_name.
out="$(echo '{"model":{"display_name":"Gemini 4 Neon","effort":"high"}}' | bash "$SCRIPT")"
check "effort appended when distinct" "$(grep -c 'Gemini 4 Neon · high' <<<"$out")" "1"

# Over-pace quota projects full-by time.
out="$(jq -n '{quota:{"5h":{remaining_fraction:0.10,reset_in_seconds:5400}}}' | bash "$SCRIPT")"
check "5h over pace" "$(grep -c '5 HOUR.*90%.*⇡ 20%.*full by' <<<"$out")" "1"

# ---- compact mode ----
out="$(payload s1 | bash "$SCRIPT" --compact)"
check "compact has 4 lines" "$(wc -l <<<"$out" | tr -d ' ')" "4"
check "compact context on project" "$(grep -c 'PROJECT.*26%' <<<"$out")" "1"
check "compact quota row" "$(grep -c 'QUOTA.*7d.*25%' <<<"$out")" "1"
check "compact cost closes frame" "$(grep -c '^╰─ COST' <<<"$out")" "1"
check "compact via env" "$(payload s1 | AGY_STATUSLINE_COMPACT=1 bash "$SCRIPT" | wc -l | tr -d ' ')" "4"

# ---- weather from cache ----
mkdir -p "$XDG_CACHE_HOME/agy-statusline"
echo '{"location":{"name":"Stavern, Norway"},"temperature":14.7,"feels_like":11.2,"humidity":82.3,"wind_speed":2.1,"wind_degrees":232,"precipitation":0,"symbol":"clearsky_day"}' \
  >"$XDG_CACHE_HOME/agy-statusline/weather.json"
out="$(echo '{}' | AGY_STATUSLINE_WEATHER=1 AGY_STATUSLINE_SKY=/nonexistent bash "$SCRIPT")"
check "weather renders" "$(head -1 <<<"$out" | grep -o 'Stavern.*%' | tr -s ' ')" 'Stavern ☀️ 15° feels 11° ↗ 2 m/s 💧 82%'

# ---- Synapse rows ----
mkdir -p "$XDG_CACHE_HOME/synapse/context"
cat >"$XDG_CACHE_HOME/synapse/context/s2.json" <<'EOF'
{"status":{"repo":"kristofferrisa/synapse","mode":"begge","files":[{"label":"AGENTS.md","scope":"repo","tokens":500,"git":"clean","read":true,"stale":false},{"label":"CLAUDE.md","scope":"repo","tokens":900,"git":"clean","read":false,"stale":false}],"synapse":{"slug":"synapse","size":"medium","chars":4000,"tokens":1000,"via":"hook","servedAt":1,"editionDate":null,"live":{"title":"Synapse","generatedAt":1,"newer":false,"due":false,"dueReason":null,"checkedAt":1}},"impact":{"week":4,"ended":2,"wroteBack":1,"avgChars":8000}}}
EOF
out="$(payload s2 | bash "$SCRIPT")"
check "synapse row full" "$(grep -c 'SYNAPSE.*dynamisk + statisk.*◆ synapse@medium.*1k tok.*via hook.*✓ nyeste' <<<"$out")" "1"
check "agents row full" "$(grep -c 'AGENTS.*AGENTS\.md 500.*CLAUDE\.md (leses ikke)' <<<"$out")" "1"
check "impact row closes frame" "$(grep -c '^╰─ IMPACT.*4 økter/7d.*50% skrev tilbake.*snitt 2k' <<<"$out")" "1"

out="$(payload s2 | bash "$SCRIPT" --compact)"
check "synapse compact closes frame" "$(grep -c '^╰─ SYNAPSE.*◆ synapse@medium.*✓ nyeste' <<<"$out")" "1"
check "compact hides agents row" "$(grep -c 'AGENTS' <<<"$out" || true)" "0"

check "empty input safe" "$(echo '{}' | bash "$SCRIPT" >/dev/null && echo ok)" "ok"

# ---- configure_agy in install.sh ----
# shellcheck source=/dev/null
DOTFILES_SOURCE_ONLY=1 source "$REPO/install.sh"

AGY_DIR="$WORK/agy-test"
export AGY_CONFIG_DIR="$AGY_DIR"

# Dry run changes nothing.
# shellcheck disable=SC2034
DRY_RUN=1
configure_agy >/dev/null
check "dry-run creates nothing" "$(test ! -e "$AGY_DIR" && echo ok || echo created)" "ok"

# Fresh install creates settings.json with 0600 permissions.
# shellcheck disable=SC2034
DRY_RUN=0
configure_agy >/dev/null
check "creates settings.json" "$(jq -r '.statusLine.command' "$AGY_DIR/settings.json")" "bash ~/.gemini/antigravity-cli/statusline.sh"
mode="$(stat -f %Lp "$AGY_DIR/settings.json" 2>/dev/null || stat -c %a "$AGY_DIR/settings.json")"
check "settings.json mode 600" "$mode" "600"

# Existing keys are preserved when merging statusLine.
printf '{"agentMode":"auto","trustedWorkspaces":["/tmp/repo"]}\n' >"$AGY_DIR/settings.json"
chmod 600 "$AGY_DIR/settings.json"
configure_agy >/dev/null
check "preserves agentMode" "$(jq -r '.agentMode' "$AGY_DIR/settings.json")" "auto"
check "preserves trustedWorkspaces" "$(jq -r '.trustedWorkspaces[0]' "$AGY_DIR/settings.json")" "/tmp/repo"
check "merges statusLine" "$(jq -r '.statusLine.command' "$AGY_DIR/settings.json")" "bash ~/.gemini/antigravity-cli/statusline.sh"

# Second run is a no-op and preserves custom statusLine.
printf '{"statusLine":{"type":"command","command":"custom.sh"}}\n' >"$AGY_DIR/settings.json"
configure_agy >/dev/null
check "keeps custom statusLine" "$(jq -r '.statusLine.command' "$AGY_DIR/settings.json")" "custom.sh"

# Invalid JSON is never overwritten.
printf '{not json' >"$AGY_DIR/settings.json"
configure_agy >/dev/null 2>&1
check "keeps invalid json untouched" "$(cat "$AGY_DIR/settings.json")" "{not json"

if ((failures)); then
  printf '%s failed\n' "$failures"
  exit 1
fi
printf 'agy status line ok\n'
