#!/bin/bash
# Dollar signs in patterns and expected output are literal amounts.
# shellcheck disable=SC2016
# Status line tests: cost math against hand-worked amounts, and rendering.
#
# Fixture responses (USD per million tokens from pricing.json):
#   m1  Opus 5.5, logged twice (one line per content block), counted once:
#       1M in $4 + 1M out $20 + 1M cache read $0.20
#       + 1M 5-minute write ($4 x 1.25 = $5) + 1M 1-hour write ($4 x 2 = $8)  = $37.20
#   m2  Opus 5, fast mode: 1M out x $25 x 2                                  = $50.00
#   m9  Haiku 4.5 in a nested subagent file: 1M in x $1                      =  $1.00
#   m4  Sonnet 5, another session today: 1M out x $10                        = $10.00
#   m3  unknown model: counted, not priced, flagged
#   m0  2020, this session only: 1M in x $4                                  =  $4.00
#   m5  <synthetic>: ignored. Last line is half-written: skipped.
#
#   today   = 37.20 + 50 + 1 + 10  = 98.20   (5 responses, 1 unpriced)
#   session = 37.20 + 50 + 1 + 4   = 92.20
#   saved   = 1M cache read x ($4 - $0.20) = 3.80
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.claude/statusline/statusline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Stamp "today" into the fixture: an hour ago, or just after local
# midnight when the day is younger than that.
now=$(date +%s)
midnight=$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date '+%Y-%m-%d') 00:00:00" +%s 2>/dev/null ||
  date -d "$(date '+%Y-%m-%d') 00:00:00" +%s)
stamp=$((now - 3600 > midnight ? now - 3600 : midnight + 1))
today="$(date -u -r "$stamp" '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || date -u -d "@$stamp" '+%Y-%m-%dT%H:%M:%S.000Z')"
cp -R "$HERE/fixture/projects" "$WORK/"
find "$WORK/projects" -name '*.jsonl' -exec sed -i.bak "s/@TODAY@/$today/g" {} \; -exec rm -f {}.bak \;

export CLAUDE_CONFIG_DIR="$WORK" XDG_CACHE_HOME="$WORK/cache" NO_COLOR=1
failures=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

out="$(echo '{"session_id":"s1","cwd":"/","model":{"display_name":"Opus 5.5"}}' | bash "$SCRIPT")"
usage="$WORK/cache/claude-statusline/usage-s1.json"

check "today cost" "$(jq '.today.cost * 100 | round' "$usage")" 9820
check "today responses" "$(jq '.today.responses' "$usage")" 5
check "today unpriced" "$(jq '.today.unpriced' "$usage")" 1
check "session cost" "$(jq '.session.cost * 100 | round' "$usage")" 9220
check "cache savings" "$(jq '.today.saved * 100 | round' "$usage")" 380
check "Opus 5.5 priced as Opus 5.5" "$(jq '.today.models["claude-opus-5-5"].cost * 100 | round' "$usage")" 3720
check "rendered today" "$(grep -o 'today [~$0-9.]*' <<<"$out")" 'today ~$98.20'
check "rendered session" "$(grep -o 'session [$0-9.]*' <<<"$out")" 'session $92.20'

# Claude Code's own session figure wins over the recomputed one.
out="$(echo '{"session_id":"s1","cost":{"total_cost_usd":12.5}}' | bash "$SCRIPT")"
check "uses Claude Code session cost" "$(grep -o 'session [$0-9.]*' <<<"$out")" 'session $12.50'

# Rate limits and context render; missing fields don't break anything.
out="$(jq -n --argjson t "$(($(date +%s) + 5400))" '{session_id:"s1", context_window:{context_window_size:1000000, used_percentage:85}, rate_limits:{five_hour:{used_percentage:42, resets_at:$t}}}' | bash "$SCRIPT")"
check "context" "$(grep -o '[0-9]*% [0-9.kM]*/[0-9.kM]*\|[0-9]*%' <<<"$out" | head -1)" '85%'
check "5h limit" "$(grep -o '5h [0-9]*% ↻[0-9hm]*' <<<"$out")" '5h 42% ↻1h30m'
check "empty input" "$(echo '{}' | bash "$SCRIPT" >/dev/null && echo ok)" ok

((failures == 0)) || {
  echo "$failures failed"
  exit 1
}
echo "all passed"
