# Render the status line from Claude Code's input (.) plus precomputed
# usage ($usage[0]), cached weather ($weather[0]) and git state ($branch,
# $dirty, $ahead, $behind). Draws a panel: a header, then labelled rows in
# aligned columns, grouped into sections.
#
#   ╭─  Stavern   🌤️ 15°  feels 14°  ↗ 2 m/s  💧 82%   ·   Sun 27 Sep  11:23   ·   CC 2.1.283  ──────────
#   │
#   │  PROJECT    dotfiles   main ●3 ⇡2  Opus 5.5 · xhigh
#   │  CONTEXT   ▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  26%    256k of 1M
#   │
#   │  5 HOUR    ▰▰▰▰▰▰▰┃▰▰▱▱▱▱▱▱▱▱▱▱▱   48%   ⇡ 11%     resets 14:33      in 3h10m   ⚠ full by 13:22
#   │  7 DAY     ▰▰▰▰┃▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱   20%   ⇣ 31%     resets Wed 22:29  in 3d11h
#   │
#   │  SESSION   $6.84     $4.56/h     42.4k out    +412 −87    1h30m
#   ╰─ TODAY     $15.88    cache 98%   saved $135
#
# The right edge stays open: Claude Code does not pass the terminal width,
# so a closed box would break on any other size. A section with nothing to
# show is left out (no rate limits on API keys, no weather without sky).
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
  base: "1e1e2e", surface: "313244", overlay: "45475a", muted: "6c7086", text: "cdd6f4", subtext: "a6adc8",
  blue: "89b4fa", mauve: "cba6f7", green: "a6e3a1", yellow: "f9e2af", peach: "fab387",
  red: "f38ba8", teal: "94e2d5", lavender: "b4befe", sky: "89dceb", pink: "f5c2e7"
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

# Epoch -> "14:30" when it is within a day, "Thu 09:00" beyond that.
def clock($now):
  if . - $now < 72000 then strflocaltime("%H:%M") else strflocaltime("%a %H:%M") end;

# Green, then yellow from $warn, red from $crit.
def level($warn; $crit): if . >= $crit then C.red elif . >= $warn then C.yellow else C.green end;

def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;

# Pad plain text to a column width. Pad before coloring: escape codes
# have length but no width.
def pad($w): . + (" " * ([$w - length, 0] | max));
def col($w; $c): fg($c) + pad($w) + reset;

# Context gauge: each filled cell takes the color of its own position, so the
# bar heats up toward the auto-compact end.
def gauge($pct; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | [range(0; $width) as $i
     | if $i < $n then fg(($i + 0.5) / $width * 100 | level(50; 80)) + "▰"
       else fg(C.surface) + "▱" end]
  | join("") + reset;

# Rate-limit bar with a pace marker: ┃ sits between the cells where usage
# would be if spread evenly across the window. Filled cells past the marker
# are overspend.
def pace_bar($pct; $pace; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | (($pace / 100 * $width) | round | clamp(0; $width)) as $m
  | [range(0; $width + 1) as $i
     | (if $i == $m then fg(C.lavender) + bold + "┃" + reset else "" end)
       + (if $i == $width then ""
          elif $i < $n then fg($pct | level(70; 90)) + "▰"
          else fg(C.surface) + "▱" end)]
  | join("") + reset;

# A powerline segment: text on a background, arrow into the next background.
def segment($bgc; $fgc; $text; $next):
  bg($bgc) + fg($fgc) + " \($text) " + (if $next == null then reset + fg($bgc) + "" + reset else bg($next) + fg($bgc) + "" end);

def join_segments:
  . as $segs
  | [range(0; $segs | length) as $i
     | $segs[$i] as $s
     | segment($s.bg; $s.fg; $s.text; ($segs[$i + 1].bg // null))]
  | join("");

def dim($s): fg(C.muted) + $s + reset;
def dot: fg(C.overlay) + "   ·   " + reset;

# A row: a fixed-width label, then the row's cells.
def row($label; $c; $body): {label: $label, color: $c, body: $body};

# MET Norway symbol codes (clearsky_day, lightrainshowers_night, ...).
def weather_icon:
  if test("thunder") then "⛈️"
  elif test("snow") then "🌨️"
  elif test("sleet") then "🌨️"
  elif test("rainshowers") then (if test("night") then "🌧️" else "🌦️" end)
  elif test("rain") then "🌧️"
  elif test("fog") then "🌫️"
  elif test("partlycloudy") then (if test("night") then "☁️" else "⛅" end)
  elif test("cloudy") then "☁️"
  elif test("fair") then (if test("night") then "🌙" else "🌤️" end)
  elif test("clearsky") then (if test("night") then "🌙" else "☀️" end)
  else "🌡️" end;

# Where the wind blows to: MET gives the direction it comes from.
def wind_arrow: ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][((. + 180) % 360 / 45 | round) % 8];

# One rate-limit window as a row: bar, %, pace delta, reset time, countdown,
# and when 100% hits if the current rate holds. Columns line up across rows.
def limit($label; $window; $now):
  . as $l
  | ($l.used_percentage // 0) as $used
  | ($l.resets_at // null) as $reset
  | (if $reset != null then (1 - (($reset - $now) / $window)) | clamp(0; 1) else null end) as $elapsed
  | ($used | level(70; 90)) as $lc
  | row($label; C.pink;
      (if $elapsed != null then pace_bar($used; $elapsed * 100; 20) else gauge($used; 20) + " " end)
      + "   " + bold + ("\($used | round)%" | col(6; $lc))
      + (if $elapsed != null then
           ($used - $elapsed * 100) as $d
           | if $d >= 5 then ("⇡ \($d | round)%" | col(10; C.red))
             elif $d <= -5 then ("⇣ \(-$d | round)%" | col(10; C.green))
             else ("on pace" | col(10; C.muted)) end
         else " " * 10 end)
      + (if $reset != null then
           dim("resets ") + (($reset | clock($now)) | col(11; C.text))
           + dim("in ") + ((($reset - $now) | clamp(0; infinite) | span) | col(9; C.subtext))
         else "" end)
      + (if $elapsed != null and $elapsed > 0.02 and $used >= 1 and $used < 100 then
           ($now + (100 - $used) / ($used / ($elapsed * $window))) as $full
           | if $full < $reset then fg(C.red) + bold + "⚠ full by \($full | clock($now))" + reset else "" end
         else "" end));

($usage[0] // {}) as $u
| ($weather[0] // null) as $w
| now as $now

# ---- header: where and when, and the weather there ----
| ([
    (if $w != null and $w.temperature != null then
       fg(C.blue) + bold + " " + (($w.location.name // "") | split(",")[0]) + reset + "   "
       + (($w.symbol // "") | weather_icon) + " "
       + fg(C.peach) + bold + "\($w.temperature | round)°" + reset
       + (if $w.feels_like != null and (($w.feels_like - $w.temperature) | fabs) >= 1
          then dim("  feels \($w.feels_like | round)°") else "" end)
       + (if $w.wind_speed != null then
            fg(C.teal) + "  \(($w.wind_degrees // 0) | wind_arrow) \($w.wind_speed | round) m/s" + reset
          else "" end)
       + (if ($w.precipitation // 0) > 0 then fg(C.sky) + "  ☔ \($w.precipitation) mm" + reset
          elif $w.humidity != null then fg(C.sky) + "  💧 \($w.humidity | round)%" + reset
          else "" end)
     else empty end),
    (fg(C.lavender) + ($now | strflocaltime("%a %-d %b  ")) + bold + ($now | strflocaltime("%H:%M")) + reset),
    (if .version then dim("CC ") + fg(C.blue) + .version + reset else empty end),
    (if (.output_style.name // "default") != "default" then dim("style ") + fg(C.mauve) + .output_style.name + reset else empty end),
    (if .vim.mode then fg(C.green) + bold + .vim.mode + reset else empty end)
  ] | join(dot)) as $header

# ---- workspace: what, where, and how full the context is ----
| (.workspace.current_dir // .cwd // "") as $dir
| (.context_window // {}) as $cw
| ($cw.context_window_size // null) as $size
| ($cw.current_usage // null) as $cur
| (if $cw.used_percentage != null then $cw.used_percentage
   elif $cur != null and $size != null and $size > 0 then
     (($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0)) / $size * 100
   else null end) as $ctx_pct
| (if $cur != null then ($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0) else null end) as $ctx_tokens

| [
    row("PROJECT"; C.blue; [
      (if $dir != "" then {bg: C.blue, fg: C.base, text: " \($dir | split("/") | last)"} else empty end),
      (if $branch != "" then {bg: C.surface, fg: (if $dirty != "0" then C.yellow else C.green end),
         text: (" \($branch)"
           + (if $dirty != "0" then " ●\($dirty)" else "" end)
           + (if $ahead != "0" and $ahead != "" then " ⇡\($ahead)" else "" end)
           + (if $behind != "0" and $behind != "" then " ⇣\($behind)" else "" end))} else empty end),
      {bg: C.overlay, fg: C.text,
       text: "\(.model.display_name // .model.id // "Claude")\(if .effort.level then " · \(.effort.level)" else "" end)"},
      (if .agent.name then {bg: C.mauve, fg: C.base, text: "󰚩 \(.agent.name)"} else empty end),
      (if .worktree.name then {bg: C.teal, fg: C.base, text: " \(.worktree.name)"} else empty end)
    ] | join_segments),
    (if $ctx_pct != null then
       row("CONTEXT"; C.mauve;
         gauge($ctx_pct; 24) + "   " + bold + ("\($ctx_pct | round)%" | col(6; $ctx_pct | level(60; 80)))
         + (if $ctx_tokens != null and $size != null
            then fg(C.text) + ($ctx_tokens | tokens) + dim(" of ") + fg(C.subtext) + ($size | tokens) + reset
            else "" end))
     else empty end)
  ] as $workspace

# ---- limits: subscription windows, pace, and when they reset ----
| [
    (.rate_limits.five_hour // empty | limit("5 HOUR"; 18000; $now)),
    (.rate_limits.seven_day // empty | limit("7 DAY"; 604800; $now))
  ] as $limits

# ---- money: what it costs ----
| (.cost // {}) as $cost
| ($u.session // {}) as $s
| ($u.today // {}) as $t
| ($cost.total_cost_usd // $s.cost // 0) as $session_usd
| (($t.input // 0) + ($t.cache_read // 0) + ($t.cache_write // 0)) as $t_in
| [
    # Session: Claude Code's own cost figure; tokens are fresh output, not
    # cache re-reads (which dominate any "total tokens" count). Burn rate
    # only once there is enough session to average over.
    row("SESSION"; C.yellow;
      bold + (($session_usd | usd) | col(10; C.text))
      + (if ($cost.total_duration_ms // 0) >= 300000 and $session_usd > 0
         then ("\($session_usd / ($cost.total_duration_ms / 3600000) | usd)/h" | col(12; C.yellow))
         else " " * 12 end)
      + (if ($s.output // 0) > 0 then ("\($s.output | tokens) out" | col(13; C.subtext)) else " " * 13 end)
      + (if ($cost.total_lines_added // 0) + ($cost.total_lines_removed // 0) > 0
         then (("+\($cost.total_lines_added)" | col(0; C.green)) + " " + ("−\($cost.total_lines_removed)" | col(0; C.red))
               + " " * ([12 - ("+\($cost.total_lines_added) −\($cost.total_lines_removed)" | length), 1] | max))
         else "" end)
      + (if ($cost.total_duration_ms // 0) > 60000 then (($cost.total_duration_ms / 1000) | span) | col(0; C.subtext) else "" end)),
    # Today: recomputed from every transcript with current prices.
    (if ($t.responses // 0) > 0 then
       row("TODAY"; C.peach;
         bold + (((if ($t.unpriced // 0) > 0 then "~" else "" end) + ($t.cost | usd)) | col(10; C.peach))
         + (if $t_in > 0 then ("cache \((($t.cache_read // 0) / $t_in * 100) | floor)%" | col(12; C.teal)) else " " * 12 end)
         + (if ($t.saved // 0) >= 0.01 then dim("saved ") + ($t.saved | usd | col(0; C.green)) else "" end))
     else empty end)
  ] as $money

# ---- the panel ----
| [$workspace, $limits, $money] | map(select(length > 0)) as $sections
| ([$sections | to_entries[] | (if .key > 0 then {spacer: true} else empty end), .value[]]) as $rows
| ($rows | length) as $n
| fg(C.overlay) as $frame
| ($frame + "╭─ " + reset + $header + "  " + $frame + ("─" * 10) + reset),
  (if $n > 0 then $frame + "│" + reset else empty end),
  ($rows | to_entries[]
   | .value as $r
   | (if .key == $n - 1 then "╰─ " else "│  " end) as $edge
   | if $r.spacer then $frame + "│" + reset
     else $frame + $edge + reset + fg($r.color) + bold + ($r.label | pad(10)) + reset + $r.body end)
