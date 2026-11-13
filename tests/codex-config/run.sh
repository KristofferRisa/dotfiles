#!/bin/bash
# configure_codex: merges .codex/tui.toml into ~/.codex/config.toml without
# touching what Codex wrote there itself, and never twice.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# install.sh reads these; shellcheck does not follow the source.
# shellcheck disable=SC1091,SC2034
{
  DOTFILES_SOURCE_ONLY=1 source "$HERE/../../install.sh"
  set +e
  DOTFILES_DIR="$(cd "$HERE/../.." && pwd)"
  DRY_RUN=0
}

failures=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s\n  expected: %s\n  got:      %s\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

# The [tui] table as TOML sees it: lines after the exact header, up to the next table.
tui_table() {
  awk '/^\[/ { t = ($0 == "[tui]"); next } t && NF' "$1"
}

# GNU stat -c, BSD stat -f. GNU also takes -f (file systems), so try -c first.
mode_of() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}

run_in() {
  CODEX_HOME="$1" configure_codex
}

# No ~/.codex: skipped, nothing created.
out="$(run_in "$WORK/none")"
check "no codex dir is skipped" "$(grep -c 'not installed' <<<"$out")" "1"
check "no codex dir stays absent" "$([[ -e "$WORK/none" ]] && echo yes || echo no)" "no"

# Empty dir: a fresh config.toml with [tui], mode 0600.
mkdir -p "$WORK/fresh"
run_in "$WORK/fresh" >/dev/null
check "fresh: status_line set" "$(tui_table "$WORK/fresh/config.toml" | grep -c '^status_line = \[')" "1"
check "fresh: terminal_title set" "$(tui_table "$WORK/fresh/config.toml" | grep -c '^terminal_title = \[')" "1"
check "fresh: mode 600" "$(mode_of "$WORK/fresh/config.toml")" "600"

# What Codex writes on first run: [tui] with its own key, sub-tables, projects.
mkdir -p "$WORK/codex"
cat >"$WORK/codex/config.toml" <<'EOF'
[tui]
screen_reader_detection_done = true

[tui.model_availability_nux]
"some-model" = 1

[projects."/home/someone/code/private-repo"]
trust_level = "trusted"
EOF
chmod 600 "$WORK/codex/config.toml"
run_in "$WORK/codex" >/dev/null
f="$WORK/codex/config.toml"
check "codex: one [tui] header" "$(grep -c '^\[tui\]$' "$f")" "1"
check "codex: status_line in [tui]" "$(tui_table "$f" | grep -c '^status_line = ')" "1"
check "codex: own key kept" "$(tui_table "$f" | grep -c '^screen_reader_detection_done = true')" "1"
check "codex: sub-table kept" "$(grep -c '^\[tui.model_availability_nux\]$' "$f")" "1"
check "codex: project trust kept" "$(grep -c 'trust_level = "trusted"' "$f")" "1"
check "codex: nothing under projects" "$(awk '/^\[projects/ { p = 1; next } /^\[/ { p = 0 } p && /status_line/' "$f" | wc -l | tr -d ' ')" "0"
check "codex: mode still 600" "$(mode_of "$f")" "600"

# Second run: nothing added.
before="$(cat "$f")"
out="$(run_in "$WORK/codex")"
check "second run: file unchanged" "$(cat "$f")" "$before"
check "second run: says already set" "$(grep -c 'already set' <<<"$out")" "2"

# A status line the machine chose (/statusline) wins.
mkdir -p "$WORK/mine"
printf '[tui]\nstatus_line = ["model-name"]\n' >"$WORK/mine/config.toml"
run_in "$WORK/mine" >/dev/null
check "own status_line kept" "$(tui_table "$WORK/mine/config.toml" | grep -c '^status_line = \["model-name"\]$')" "1"
check "own status_line not duplicated" "$(grep -c '^status_line' "$WORK/mine/config.toml")" "1"
check "missing key still added" "$(tui_table "$WORK/mine/config.toml" | grep -c '^terminal_title = ')" "1"

# A key in another table does not count as set in [tui].
mkdir -p "$WORK/other"
printf '[profiles.x]\nstatus_line = ["model-name"]\n' >"$WORK/other/config.toml"
run_in "$WORK/other" >/dev/null
check "other table: [tui] still added" "$(tui_table "$WORK/other/config.toml" | grep -c '^status_line = ')" "1"

# Dry run writes nothing.
mkdir -p "$WORK/dry"
out="$(DRY_RUN=1 run_in "$WORK/dry")"
check "dry run: no file" "$([[ -e "$WORK/dry/config.toml" ]] && echo yes || echo no)" "no"
check "dry run: says would" "$(grep -c 'would set' <<<"$out")" "2"

# Codex itself must accept the items (skipped where codex is not installed).
if command -v codex >/dev/null 2>&1; then
  title="$(CODEX_HOME="$WORK/fresh" codex doctor --json 2>/dev/null | jq -r '.. | objects | select(.id? == "terminal.title") | .status' | head -1)"
  check "codex doctor accepts terminal_title" "$title" "ok"
fi

if ((failures)); then
  printf '\n%d failed\n' "$failures"
  exit 1
fi
printf '\nall passed\n'
