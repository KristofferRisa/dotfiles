#!/bin/bash
# Grok status line rows. Without a Synapse cache the panel stays three lines.
# A cache adds SYNAPSE, and IMPACT when the area has receipts.
# shellcheck disable=SC2016
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../.grok/statusline.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home" GROK_HOME="$WORK/grok" XDG_CACHE_HOME="$WORK/cache"
export NO_COLOR=1 GROK_STATUSLINE_WEATHER=0 SYNAPSE_STATUSLINE=0
mkdir -p "$HOME" "$GROK_HOME" "$WORK/proj"

failures=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s\n  expected: %s\n  got:      %s\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

lines_of() { printf '%s\n' "$1" | wc -l | tr -d ' '; }

payload() {
  local sid="$1"
  printf '%s' "{\"session_id\":\"${sid}\",\"trigger\":\"state\",\"version\":\"1.2.3\",\"cwd\":\"${WORK}/proj\",\"workspace\":{\"current_dir\":\"${WORK}/proj\"},\"model\":{\"display_name\":\"Grok 4\"},\"context_window\":{\"used_percentage\":42,\"context_window_size\":200000,\"context_tokens\":84000},\"cost\":{\"total_cost_usd\":0.18}}"
}

render() { bash "$SCRIPT"; }

out="$(payload s1 | render)"
check "lines without synapse" "$(lines_of "$out")" "3"
check "project row" "$(grep -c 'PROJECT' <<<"$out")" "1"
check "context percent" "$(grep -c '42%' <<<"$out")" "1"
check "session cost" "$(grep -c '\$0\.18' <<<"$out")" "1"
check "cost closes the frame" "$(grep -c '^╰─ COST' <<<"$out")" "1"
check "no synapse row" "$(grep -c 'SYNAPSE' <<<"$out" || true)" "0"

mkdir -p "$XDG_CACHE_HOME/synapse/context"
cat >"$XDG_CACHE_HOME/synapse/context/s2.json" <<'EOF'
{"status":{"repo":null,"synapse":null,"impact":null}}
EOF
out="$(payload s2 | render)"
check "lines with no area" "$(lines_of "$out")" "4"
check "no area text" "$(grep -c 'ikke i et repo' <<<"$out")" "1"
check "no impact without receipts" "$(grep -c 'IMPACT' <<<"$out" || true)" "0"
check "synapse closes the frame" "$(grep -c '^╰─ SYNAPSE' <<<"$out")" "1"

cat >"$XDG_CACHE_HOME/synapse/context/s3.json" <<'EOF'
{"status":{"repo":"firmakart","mode":"dynamisk","synapse":{"slug":"firmakart-no","size":"medium","chars":1000,"tokens":250,"via":"hook","servedAt":1,"editionDate":null,"live":{"title":"Firmakart","generatedAt":1,"newer":false,"due":false,"dueReason":null,"checkedAt":1}},"impact":{"week":4,"ended":2,"wroteBack":1,"avgChars":8000}}}
EOF
out="$(payload s3 | render)"
check "lines with impact" "$(lines_of "$out")" "5"
check "area slug" "$(grep -c 'firmakart-no' <<<"$out")" "1"
check "edition is current" "$(grep -c '✓ nyeste' <<<"$out")" "1"
check "wrote back" "$(grep -c '50% skrev tilbake' <<<"$out")" "1"
check "average size" "$(grep -c 'snitt 2k' <<<"$out")" "1"
check "week" "$(grep -c '4 økter/7d' <<<"$out")" "1"
check "synapse is a middle row" "$(grep -c '^│  SYNAPSE' <<<"$out")" "1"
check "impact closes the frame" "$(grep -c '^╰─ IMPACT' <<<"$out")" "1"
check "context still on project" "$(grep -c '42%' <<<"$out")" "1"

if ((failures)); then
  printf '%s failed\n' "$failures"
  exit 1
fi
printf 'grok status line ok\n'
