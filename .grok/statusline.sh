#!/bin/bash
# Grok Build status line. Wired from ~/.grok/config.toml:
#
#   [ui.status_line]
#   type = "command"
#   command = "~/.grok/statusline.sh"
#   refresh_interval = 300
#
# Grok writes one JSON object to stdin. This prints at most three lines.
# Weather hits the network only when trigger is refresh_interval. Today's
# cost is summed from session usage files (costUsdTicks / 1e10).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROK_DIR="${GROK_HOME:-$HOME/.grok}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/grok-statusline"
USAGE_TTL="${GROK_STATUSLINE_TTL:-15}"
WEATHER_TTL=10

# GNU timeout is absent on macOS. Without it, run the command as-is.
run_bounded() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  else
    "$@"
  fi
}

# Local midnight as epoch seconds. jq handles GNU and BSD date.
local_midnight() {
  jq -n 'now | localtime | .[3] = 0 | .[4] = 0 | .[5] = 0 | mktime'
}

refresh_today() {
  local out="$1" midnight tmp computed
  if [[ -f "$out" ]]; then
    computed="$(jq -r '.computed_at // 0 | floor' "$out" 2>/dev/null || echo 0)"
    (($(date +%s) - computed < USAGE_TTL)) && return 0
  fi
  mkdir -p "$CACHE_DIR"
  midnight="$(local_midnight)"
  tmp="$(mktemp "$CACHE_DIR/.today.XXXXXX")"
  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$GROK_DIR/sessions" -name usage.json -mtime -1 -print0 2>/dev/null)

  if ((${#files[@]})); then
    jq -s --argjson midnight "$midnight" '
      reduce .[] as $f (
        {cost: 0, output: 0, input: 0, cache_read: 0, cache_write: 0, responses: 0};
        reduce ($f.turns // [])[] as $turn (.;
          ((($turn.endedAt // "")
            | sub("\\.[0-9]+"; "")
            | sub("\\+00:00$"; "Z")
            | fromdateiso8601? // 0)) as $ts
          | if $ts >= $midnight then
              .cost += (($turn.costUsdTicks // 0) / 1e10)
              | .output += ($turn.outputTokens // 0)
              | .input += ($turn.inputTokens // 0)
              | .cache_read += ($turn.cachedReadTokens // 0)
              | .cache_write += ($turn.cacheCreationTokens // 0)
              | .responses += ($turn.modelCalls // 0)
            else . end
        )
      )
      | . + {computed_at: now}
    ' "${files[@]}" >"$tmp" 2>/dev/null
  else
    jq -n '{cost: 0, output: 0, input: 0, cache_read: 0, cache_write: 0, responses: 0, computed_at: now}' >"$tmp"
  fi
  if [[ -s "$tmp" ]]; then mv -f "$tmp" "$out"; else rm -f "$tmp"; fi
}

# Synchronous on purpose: Grok kills anything still running when this exits.
refresh_weather() {
  local trigger="$1" out="$2" stamp="$CACHE_DIR/.weather-fetch" sky="${GROK_STATUSLINE_SKY:-sky}" tmp
  [[ "${GROK_STATUSLINE_WEATHER:-1}" != 0 ]] || return 0
  [[ "$trigger" == "refresh_interval" ]] || return 0
  command -v "$sky" >/dev/null 2>&1 || return 0
  [[ -n "$(find "$stamp" -mmin -"$WEATHER_TTL" 2>/dev/null)" ]] && return 0
  mkdir -p "$CACHE_DIR" && touch "$stamp"
  tmp="$(mktemp "$CACHE_DIR/.weather.XXXXXX")"
  if run_bounded 3 "$sky" current ${GROK_STATUSLINE_LOCATION:+"$GROK_STATUSLINE_LOCATION"} --format json --no-color --no-emoji >"$tmp" 2>/dev/null &&
    jq -e '.temperature' "$tmp" >/dev/null 2>&1; then
    mv -f "$tmp" "$out"
  else
    rm -f "$tmp"
  fi
}

main() {
  local input
  input="$(cat)"
  [[ -n "$input" ]] || return 0

  if ! command -v jq >/dev/null 2>&1; then
    printf 'Grok (install jq for the status line)\n'
    return 0
  fi

  if [[ -n "${GROK_STATUSLINE_DEBUG:-}" ]]; then
    mkdir -p "$CACHE_DIR" && printf '%s\n' "$input" >"$CACHE_DIR/last-input.json"
  fi

  local trigger dir branch="" dirty=0 ahead=0 behind=0
  trigger="$(jq -r '.trigger // "state"' <<<"$input" 2>/dev/null || echo state)"
  dir="$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input" 2>/dev/null || echo "")"
  branch="$(jq -r '.workspace.branch // ""' <<<"$input" 2>/dev/null || echo "")"

  if [[ -n "$dir" ]] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    local resolved counts
    resolved="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"
    [[ -n "$resolved" ]] && branch="$resolved"
    dirty="$(run_bounded 2 git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
    [[ -n "$dirty" ]] || dirty=0
    if counts="$(run_bounded 2 git -C "$dir" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)"; then
      read -r ahead behind <<<"$counts"
    fi
  fi

  local today_file="$CACHE_DIR/today.json"
  refresh_today "$today_file"
  [[ -f "$today_file" ]] || today_file=/dev/null

  local weather_file="$CACHE_DIR/weather.json"
  refresh_weather "$trigger" "$weather_file"
  if [[ "${GROK_STATUSLINE_WEATHER:-1}" == 0 || -z "$(find "$weather_file" -mmin -120 2>/dev/null)" ]]; then
    weather_file=/dev/null
  fi

  local color=1
  [[ -n "${NO_COLOR:-}" ]] && color=0

  jq -r --slurpfile today "$today_file" --slurpfile weather "$weather_file" \
    --arg branch "$branch" --arg dirty "$dirty" --arg ahead "$ahead" --arg behind "$behind" \
    --arg color "$color" -f "$HERE/statusline/render.jq" <<<"$input"
}

main "$@"
