#!/bin/bash
# Antigravity CLI (agy) status line. Needs bash and jq, nothing else.
#
#   ~/.gemini/antigravity-cli/settings.json:
#     "statusLine": {"type": "command", "command": "bash ~/.gemini/antigravity-cli/statusline.sh", "padding": 0}
#
#   statusline.sh --compact        shorter panel (or AGY_STATUSLINE_COMPACT=1)
#   AGY_STATUSLINE_DEBUG=1         save raw input to $CACHE_DIR/last-input.json
#   AGY_STATUSLINE_WEATHER=0       hide the weather
#   AGY_STATUSLINE_LOCATION=x      sky location name (default: sky's default location)
#   SYNAPSE_STATUSLINE=0           skip Synapse context cache refresh
#
# Antigravity pipes a JSON description of the session to stdin on every state
# change (rate-limited to 300 ms, 5 s timeout). Weather and Synapse context
# refresh asynchronously in the background so a redraw costs one jq run.
set -uo pipefail

# A status line runs via `sh -c` without shell rc files, so Homebrew, sky,
# and synapse are not on the default PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${PATH}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agy-statusline"
# Minutes. MET Norway updates hourly; sky caches for 10 minutes itself.
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

# First 16 hex chars. macOS has shasum; GNU coreutils has sha1sum.
sha1_16() {
  if command -v shasum >/dev/null 2>&1; then
    shasum | cut -c1-16
  else
    sha1sum | cut -c1-16
  fi
}

# Same key as `synapse context` (commands/context.ts, cacheKey).
synapse_cache_path() {
  local sid="$1" cwd="$2" key sum
  if [[ "$sid" =~ ^[A-Za-z0-9._:-]{1,100}$ ]]; then
    key="$sid"
  else
    sum="$(printf '%s' "$cwd" | sha1_16 || true)"
    [[ -n "$sum" ]] || sum="unknown"
    key="cwd-${sum}"
  fi
  printf '%s/synapse/context/%s.json' "${XDG_CACHE_HOME:-$HOME/.cache}" "$key"
}

# Weather comes from the sky CLI (github.com/KristofferRisa/sky-cli). It runs
# in the background and the render uses whatever is cached, so a slow or
# offline fetch never delays the status line.
refresh_weather() {
  local out="$1" stamp="$CACHE_DIR/.weather-fetch" sky="${AGY_STATUSLINE_SKY:-sky}"

  [[ "${AGY_STATUSLINE_WEATHER:-1}" != 0 ]] || return 0
  command -v "$sky" >/dev/null 2>&1 || return 0
  [[ -n "$(find "$stamp" -mmin -"$WEATHER_TTL" 2>/dev/null)" ]] && return 0

  mkdir -p "$CACHE_DIR" && touch "$stamp"
  (
    tmp="$(mktemp "$CACHE_DIR/.weather.XXXXXX")"
    if run_bounded 3 "$sky" current ${AGY_STATUSLINE_LOCATION:+"$AGY_STATUSLINE_LOCATION"} --format json --no-color --no-emoji >"$tmp" 2>/dev/null &&
      jq -e '.temperature' "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$out"
    else
      rm -f "$tmp"
    fi
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

# Invoke `synapse context status` with `--harness agy`, falling back to `grok`
# for older synapse checkouts that do not know `agy` yet.
run_synapse_status() {
  local bin="$1" payload="$2"
  shift 2
  printf '%s' "$payload" | run_bounded 4 "$bin" context status --stdin --harness agy --cache --format none "$@" >/dev/null 2>&1 ||
    printf '%s' "$payload" | run_bounded 4 "$bin" context status --stdin --harness grok --cache --format none "$@" >/dev/null 2>&1 ||
    true
}

# Refresh the Synapse context cache without blocking redraws on the network.
refresh_synapse() {
  local cache="$1" payload="$2" bin ttl mtime age lock
  [[ "${SYNAPSE_STATUSLINE:-1}" != 0 ]] || return 0
  bin="${SYNAPSE_BIN:-}"
  if [[ -z "$bin" ]]; then
    if [[ -x "${HOME}/.local/bin/synapse" ]]; then
      bin="${HOME}/.local/bin/synapse"
    elif command -v synapse >/dev/null 2>&1; then
      bin="$(command -v synapse)"
    else
      return 0
    fi
  fi
  ttl="${SYNAPSE_STATUSLINE_TTL:-20}"
  mkdir -p "$(dirname "$cache")"
  if [[ ! -f "$cache" ]]; then
    # First draw: local facts now; network check on the next stale refresh.
    run_synapse_status "$bin" "$payload" --offline
    return 0
  fi
  mtime="$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)"
  age=$(($(date +%s) - mtime))
  ((age >= ttl)) || return 0

  lock="$(dirname "$cache")/.$(basename "$cache" .json).lock"
  [[ -d "$lock" && -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]] && rmdir "$lock" 2>/dev/null || true
  if mkdir "$lock" 2>/dev/null; then
    (
      run_synapse_status "$bin" "$payload"
      rmdir "$lock" 2>/dev/null || true
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

main() {
  local input
  input="$(cat)"
  [[ -n "$input" ]] || return 0

  if ! command -v jq >/dev/null 2>&1; then
    printf 'AGY (install jq for the status line)\n'
    return 0
  fi

  if [[ -n "${AGY_STATUSLINE_DEBUG:-}" ]]; then
    mkdir -p "$CACHE_DIR" && printf '%s\n' "$input" >"$CACHE_DIR/last-input.json"
  fi

  local dir sid
  dir="$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input" 2>/dev/null || echo "")"
  sid="$(jq -r '.session_id // .conversation_id // ""' <<<"$input" 2>/dev/null || echo "")"

  # Weather older than two hours (offline for a while) is hidden, not shown stale.
  local weather_file="$CACHE_DIR/weather.json"
  refresh_weather "$weather_file"
  if [[ "${AGY_STATUSLINE_WEATHER:-1}" == 0 || -z "$(find "$weather_file" -mmin -120 2>/dev/null)" ]]; then
    weather_file=/dev/null
  fi

  local branch="" dirty=0 ahead=0 behind=0 counts
  if [[ -n "$dir" ]] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"
    # --no-optional-locks: never contend with the git commands the agent runs.
    dirty="$(run_bounded 2 git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
    [[ -n "$dirty" ]] || dirty=0
    if counts="$(run_bounded 2 git -C "$dir" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)"; then
      read -r ahead behind <<<"$counts"
    fi
  fi

  local synapse_cache synapse_arg=null
  synapse_cache="$(synapse_cache_path "$sid" "$dir")"
  refresh_synapse "$synapse_cache" "$input"
  if [[ -f "$synapse_cache" ]]; then
    synapse_arg="$(jq -c . "$synapse_cache" 2>/dev/null || echo null)"
  fi

  local color=1 compact="${AGY_STATUSLINE_COMPACT:-0}"
  [[ -n "${NO_COLOR:-}" ]] && color=0
  [[ "${1:-}" == "--compact" ]] && compact=1

  jq -r --slurpfile weather "$weather_file" --argjson synapse "$synapse_arg" \
    --arg branch "$branch" --arg dirty "$dirty" --arg ahead "$ahead" --arg behind "$behind" \
    --arg color "$color" --arg compact "$compact" -f "$HERE/statusline/render.jq" <<<"$input"
}

main "$@"
