#!/bin/bash
# Claude Code status line. Needs bash and jq, nothing else.
#
#   settings.json: "statusLine": {"type": "command", "command": "bash ~/.claude/statusline/statusline.sh"}
#
#   statusline.sh --report         today's usage by model, as a table
#   CLAUDE_STATUSLINE_DEBUG=1      also save the raw input to $CACHE_DIR/last-input.json
#
# Claude Code pipes a JSON description of the session to stdin on every
# refresh. Usage across all transcripts is recomputed at most every
# USAGE_TTL seconds and cached, so a refresh normally costs one jq run.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
USAGE_TTL="${CLAUDE_STATUSLINE_TTL:-15}"

# Recompute usage for session $1 into $2 when the cached copy is stale.
refresh_usage() {
  local sid="$1" out="$2" transcript="${3:-}" computed tmp

  if [[ -f "$out" ]]; then
    computed="$(jq -r '.computed_at // 0 | floor' "$out" 2>/dev/null || echo 0)"
    (($(date +%s) - computed < USAGE_TTL)) && return 0
  fi

  mkdir -p "$CACHE_DIR"
  tmp="$(mktemp "$CACHE_DIR/.usage.XXXXXX")"
  # Files touched in the last day hold everything "today" can include.
  # Subagent transcripts live in nested folders, hence the recursive find.
  {
    find "$CLAUDE_DIR/projects" -name '*.jsonl' -mtime -1 -print0 2>/dev/null
    [[ -n "$transcript" && -f "$transcript" ]] && printf '%s\0' "$transcript"
  } | sort -zu | xargs -0 jq -nR --slurpfile prices "$HERE/pricing.json" --arg sid "$sid" \
    -f "$HERE/usage.jq" >"$tmp" 2>/dev/null

  # Renders can overlap; rename keeps readers from seeing a partial file.
  if [[ -s "$tmp" ]]; then mv -f "$tmp" "$out"; else rm -f "$tmp"; fi
}

report() {
  local out="$CACHE_DIR/usage-report.json"
  rm -f "$out"
  refresh_usage "" "$out"
  jq -r '
    def usd: (. * 100 | round) as $c | "\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)";
    .today as $t
    | "Today: $\($t.cost | usd) over \($t.responses) responses; cache reads saved $\($t.saved | usd)",
      "",
      (["model", "responses", "output tokens", "cost"] | @tsv),
      ($t.models | to_entries | sort_by(-.value.cost)[]
       | [.key, .value.responses, .value.output, (if .value.priced then "$" + (.value.cost | usd) else "unknown price" end)] | @tsv)
  ' "$out" | column -t -s $'\t'
}

main() {
  if [[ "${1:-}" == "--report" ]]; then
    report
    return
  fi

  local input
  input="$(cat)"

  if ! command -v jq >/dev/null 2>&1; then
    printf 'Claude (install jq for the full status line)\n'
    return
  fi

  if [[ -n "${CLAUDE_STATUSLINE_DEBUG:-}" ]]; then
    mkdir -p "$CACHE_DIR" && printf '%s\n' "$input" >"$CACHE_DIR/last-input.json"
  fi

  local sid transcript dir
  sid="$(jq -r '.session_id // ""' <<<"$input")"
  transcript="$(jq -r '.transcript_path // ""' <<<"$input")"
  dir="$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")"

  local usage_file="$CACHE_DIR/usage-${sid:-none}.json"
  refresh_usage "$sid" "$usage_file" "$transcript"
  [[ -f "$usage_file" ]] || usage_file=/dev/null

  local branch="" dirty=0
  if [[ -n "$dir" ]] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
    # --no-optional-locks: never contend with the git commands Claude runs.
    dirty="$(git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  fi

  local color=1
  [[ -n "${NO_COLOR:-}" ]] && color=0

  jq -r --slurpfile usage "$usage_file" --arg branch "$branch" --arg dirty "$dirty" \
    --arg color "$color" -f "$HERE/render.jq" <<<"$input"
}

main "$@"
