# Render the status line from Claude Code's input (.) plus precomputed
# usage ($usage[0]) and git state ($branch, $dirty). Prints two lines:
#
#   dir | branch | model · effort | context bar          (powerline segments)
#   session $ · lines · time | today $ · cache | 5h % | 7d %
#
# Colors are Catppuccin Mocha, matching the Ghostty theme. $color == "0"
# (NO_COLOR) drops all escape codes.

def esc($code): if $color == "1" then "\u001b[\($code)m" else "" end;
def rgb($hex):
  $hex | [.[0:2], .[2:4], .[4:6]] | map(explode | map(if . > 96 then . - 87 elif . > 64 then . - 55 else . - 48 end) | .[0] * 16 + .[1]) | join(";");
def fg($hex): esc("38;2;\(rgb($hex))");
def bg($hex): esc("48;2;\(rgb($hex))");
def reset: esc("0");
def bold: esc("1");

def C: {
  base: "1e1e2e", surface: "313244", overlay: "45475a", text: "cdd6f4", subtext: "a6adc8",
  blue: "89b4fa", mauve: "cba6f7", green: "a6e3a1", yellow: "f9e2af", peach: "fab387",
  red: "f38ba8", teal: "94e2d5", lavender: "b4befe"
};

# 1234 -> 1.2k, 1234567 -> 1.2M
def tokens:
  if . >= 1e6 then "\((. / 1e5 | floor) / 10)M"
  elif . >= 1e3 then "\((. / 1e2 | floor) / 10)k"
  else "\(. | floor)" end;

# 7.1 -> $7.10, 1234.5 -> $1235
def usd:
  if . == null then "?"
  elif . >= 99.995 then "$\(. | round)"
  else (. * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)" end;

# Seconds -> 45m, 1h20m, 3d4h. Rounds up: a countdown says "within".
def span:
  ((. / 60) | ceil) as $m
  | if $m < 60 then "\($m)m"
    elif $m < 1440 then "\(($m / 60) | floor)h\($m % 60)m"
    else "\(($m / 1440) | floor)d\((($m % 1440) / 60) | floor)h" end;

# Green, then yellow from $warn, red from $crit.
def level($warn; $crit): if . >= $crit then C.red elif . >= $warn then C.yellow else C.green end;

def bar($pct; $width):
  (($pct / 100 * $width) | round | if . > $width then $width elif . < 0 then 0 else . end) as $n
  | ("▰" * $n) + ("▱" * ($width - $n));

# A powerline segment: text on a background, arrow into the next background.
def segment($bgc; $fgc; $text; $next):
  bg($bgc) + fg($fgc) + " \($text) " + (if $next == null then reset + fg($bgc) + "" + reset else bg($next) + fg($bgc) + "" end);

def join_segments:
  . as $segs
  | [range(0; $segs | length) as $i
     | $segs[$i] as $s
     | segment($s.bg; $s.fg; $s.text; ($segs[$i + 1].bg // null))]
  | join("");

def sep: fg(C.overlay) + " │ " + reset;

($usage[0] // {}) as $u
| now as $now

# ---- line 1: where am I, what model, how full is the context ----
| (.workspace.current_dir // .cwd // "") as $dir
| (.context_window // {}) as $cw
| ($cw.context_window_size // null) as $size
| ($cw.current_usage // null) as $cur
| (if $cw.used_percentage != null then $cw.used_percentage
   elif $cur != null and $size != null and $size > 0 then
     (($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0)) / $size * 100
   else null end) as $ctx_pct
| (if $cur != null then ($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0) else null end) as $ctx_tokens

| ([
    (if $dir != "" then {bg: C.blue, fg: C.base, text: " \($dir | split("/") | last)"} else empty end),
    (if $branch != "" then {bg: C.surface, fg: (if $dirty != "0" then C.yellow else C.green end),
       text: " \($branch)\(if $dirty != "0" then " ●\($dirty)" else "" end)"} else empty end),
    {bg: C.overlay, fg: C.text,
     text: "\(.model.display_name // .model.id // "Claude")\(if .effort.level then " · \(.effort.level)" else "" end)"},
    (if .agent.name then {bg: C.mauve, fg: C.base, text: "󰚩 \(.agent.name)"} else empty end),
    (if .worktree.name then {bg: C.teal, fg: C.base, text: " \(.worktree.name)"} else empty end),
    (if $ctx_pct != null then
       {bg: C.surface, fg: ($ctx_pct | level(60; 80)),
        text: "\(bar($ctx_pct; 8)) \($ctx_pct | round)%\(if $ctx_tokens != null and $size != null then fg(C.subtext) + " \($ctx_tokens | tokens)/\($size | tokens)" else "" end)"}
     else empty end)
  ] | join_segments) as $line1

# ---- line 2: what it costs, and how close the limits are ----
| (.cost // {}) as $cost
| ($u.session // {}) as $s
| ($u.today // {}) as $t
| ($cost.total_cost_usd // $s.cost // 0) as $session_usd
| (($t.input // 0) + ($t.cache_read // 0) + ($t.cache_write // 0)) as $t_in
| ([
    # Session: Claude Code's own cost figure; tokens are fresh output, not
    # cache re-reads (which dominate any "total tokens" count).
    ( fg(C.subtext) + "session " + reset + bold + fg(C.text) + ($session_usd | usd) + reset
      + fg(C.subtext)
      + (if ($s.output // 0) > 0 then " · \($s.output | tokens) out" else "" end)
      + (if ($cost.total_lines_added // 0) + ($cost.total_lines_removed // 0) > 0
         then " · " + fg(C.green) + "+\($cost.total_lines_added)" + fg(C.subtext) + "/" + fg(C.red) + "-\($cost.total_lines_removed)" + fg(C.subtext)
         else "" end)
      + (if ($cost.total_duration_ms // 0) > 60000 then " · \(($cost.total_duration_ms / 1000) | span)" else "" end)
      + reset ),
    # Today: recomputed from every transcript with current prices.
    ( if ($t.responses // 0) > 0 then
        fg(C.subtext) + "today " + reset + bold + fg(C.peach)
        + (if ($t.unpriced // 0) > 0 then "~" else "" end) + ($t.cost | usd) + reset
        + fg(C.subtext)
        + (if $t_in > 0 then " · cache \((($t.cache_read // 0) / $t_in * 100) | floor)%" else "" end)
        + (if ($t.saved // 0) >= 0.01 then " (saved \($t.saved | usd))" else "" end)
        + reset
      else empty end ),
    # Subscription rate limits, when Claude Code provides them.
    ( .rate_limits.five_hour // empty
      | fg(C.subtext) + "5h " + reset + fg(.used_percentage | level(70; 90)) + "\(.used_percentage | round)%" + reset
        + (if .resets_at then fg(C.subtext) + " ↻\((.resets_at - $now) | if . < 0 then 0 else . end | span)" + reset else "" end) ),
    ( .rate_limits.seven_day // empty
      | fg(C.subtext) + "7d " + reset + fg(.used_percentage | level(70; 90)) + "\(.used_percentage | round)%" + reset
        + (if .resets_at then fg(C.subtext) + " ↻\((.resets_at - $now) | if . < 0 then 0 else . end | span)" + reset else "" end) )
  ] | join(sep)) as $line2

| $line1, " " + $line2
