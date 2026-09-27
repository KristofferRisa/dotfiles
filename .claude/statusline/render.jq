# Render the status line from Claude Code's input (.) plus precomputed
# usage ($usage[0]), cached weather ($weather[0]) and git state ($branch,
# $dirty, $ahead, $behind). Prints up to four lines:
#
#    Stavern  ☀️ 15° feels 14° ↗2 m/s 💧82%  │  Sun 27 Sep 11:20  │  CC 2.1.283
#    dotfiles   main ●1 ⇡2   Opus 5.5 · xhigh   ▰▰▰▱▱▱▱▱▱▱▱▱ 26% 256k/1M
#   5h ▰▰▰▰┃▰▱▱▱▱▱ 48% ⇡8% · resets 14:30 (3h10m) │ 7d ▰▰▱▱▱┃▱▱▱▱▱ 20% ⇣21% · resets Thu 09:00
#   session $6.84 · $4.10/h · 112k out · +412/-87 · 1h30m │ today $7.52 · cache 98% (saved $63.15)
#
# A line with nothing to show is left out (no rate limits on API keys, no
# weather without the sky CLI). Colors are Catppuccin Mocha, matching the
# Ghostty theme. $color == "0" (NO_COLOR) drops all escape codes.

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
  red: "f38ba8", teal: "94e2d5", lavender: "b4befe", sky: "89dceb"
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

# Context bar: each filled cell takes the color of its own position, so the
# bar reads as a gauge that heats up toward the auto-compact end.
def gauge($pct; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | [range(0; $width) as $i
     | if $i < $n then fg(($i + 0.5) / $width * 100 | level(50; 80)) + "▰"
       else fg(C.overlay) + "▱" end]
  | join("") + reset;

# Rate-limit bar with a pace marker: ┃ sits between the cells where usage
# would be if spread evenly across the window. Filled cells past the marker
# are overspend.
def pace_bar($pct; $pace; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | (($pace / 100 * $width) | round | clamp(0; $width)) as $m
  | [range(0; $width + 1) as $i
     | (if $i == $m then fg(C.lavender) + "┃" else "" end)
       + (if $i == $width then ""
          elif $i < $n then fg($pct | level(70; 90)) + "▰"
          else fg(C.overlay) + "▱" end)]
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

def sep: fg(C.overlay) + " │ " + reset;
def dim($s): fg(C.subtext) + $s + reset;

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

# One rate-limit window: bar, %, pace delta, reset time, and when 100% hits
# if the current rate holds.
def limit($label; $window; $now):
  . as $l
  | ($l.used_percentage // 0) as $used
  | ($l.resets_at // null) as $reset
  | (if $reset != null then (1 - (($reset - $now) / $window)) | clamp(0; 1) else null end) as $elapsed
  | dim($label + " ")
    + (if $elapsed != null then pace_bar($used; $elapsed * 100; 10) + " " else "" end)
    + fg($used | level(70; 90)) + bold + "\($used | round)%" + reset
    + (if $elapsed != null then
         ($used - $elapsed * 100) as $d
         | if $d >= 5 then fg(C.red) + " ⇡\($d | round)%" + reset
           elif $d <= -5 then fg(C.green) + " ⇣\(-$d | round)%" + reset
           else dim(" on pace") end
       else "" end)
    + (if $reset != null then
         dim(" · resets ") + fg(C.text) + ($reset | clock($now)) + reset
         + dim(" (\(($reset - $now) | clamp(0; infinite) | span))")
       else "" end)
    + (if $elapsed != null and $elapsed > 0.02 and $used >= 1 and $used < 100 then
         ($now + (100 - $used) / ($used / ($elapsed * $window))) as $full
         | if $full < $reset then fg(C.red) + " · 100% at \($full | clock($now))" + reset else "" end
       else "" end);

($usage[0] // {}) as $u
| ($weather[0] // null) as $w
| now as $now

# ---- line 1: where and when, and the weather there ----
| ([
    (if $w != null and $w.temperature != null then
       fg(C.blue) + " " + (($w.location.name // "") | split(",")[0]) + reset + "  "
       + (($w.symbol // "") | weather_icon) + " "
       + fg(C.peach) + bold + "\($w.temperature | round)°" + reset
       + (if $w.feels_like != null and (($w.feels_like - $w.temperature) | fabs) >= 1
          then dim(" feels \($w.feels_like | round)°") else "" end)
       + (if $w.wind_speed != null then
            fg(C.teal) + " \(($w.wind_degrees // 0) | wind_arrow)\($w.wind_speed | round) m/s" + reset
          else "" end)
       + (if ($w.precipitation // 0) > 0 then fg(C.sky) + " \($w.precipitation)mm" + reset
          elif $w.humidity != null then fg(C.sky) + " 💧\($w.humidity | round)%" + reset
          else "" end)
     else empty end),
    (fg(C.lavender) + ($now | strflocaltime("%a %-d %b ")) + bold + ($now | strflocaltime("%H:%M")) + reset),
    (if .version then dim("CC ") + fg(C.blue) + .version + reset else empty end),
    (if (.output_style.name // "default") != "default" then dim("style ") + fg(C.mauve) + .output_style.name + reset else empty end),
    (if .vim.mode then fg(C.green) + .vim.mode + reset else empty end)
  ] | join(sep)) as $line1

# ---- line 2: what, where, and how full the context is ----
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
       text: (" \($branch)"
         + (if $dirty != "0" then " ●\($dirty)" else "" end)
         + (if $ahead != "0" and $ahead != "" then " ⇡\($ahead)" else "" end)
         + (if $behind != "0" and $behind != "" then " ⇣\($behind)" else "" end))} else empty end),
    {bg: C.overlay, fg: C.text,
     text: "\(.model.display_name // .model.id // "Claude")\(if .effort.level then " · \(.effort.level)" else "" end)"},
    (if .agent.name then {bg: C.mauve, fg: C.base, text: "󰚩 \(.agent.name)"} else empty end),
    (if .worktree.name then {bg: C.teal, fg: C.base, text: " \(.worktree.name)"} else empty end),
    (if $ctx_pct != null then
       {bg: C.surface, fg: ($ctx_pct | level(60; 80)),
        text: "\(gauge($ctx_pct; 12))\(bg(C.surface) + fg($ctx_pct | level(60; 80))) \($ctx_pct | round)%\(if $ctx_tokens != null and $size != null then fg(C.subtext) + " \($ctx_tokens | tokens)/\($size | tokens)" else "" end)"}
     else empty end)
  ] | join_segments) as $line2

# ---- line 3: subscription limits, pace, and when they reset ----
| ([
    (.rate_limits.five_hour // empty | limit("5h"; 18000; $now)),
    (.rate_limits.seven_day // empty | limit("7d"; 604800; $now))
  ] | join(sep)) as $line3

# ---- line 4: what it costs ----
| (.cost // {}) as $cost
| ($u.session // {}) as $s
| ($u.today // {}) as $t
| ($cost.total_cost_usd // $s.cost // 0) as $session_usd
| (($t.input // 0) + ($t.cache_read // 0) + ($t.cache_write // 0)) as $t_in
| ([
    # Session: Claude Code's own cost figure; tokens are fresh output, not
    # cache re-reads (which dominate any "total tokens" count).
    ( dim("session ") + bold + fg(C.text) + ($session_usd | usd) + reset
      + fg(C.subtext)
      # Burn rate only once there is enough session to average over.
      + (if ($cost.total_duration_ms // 0) >= 300000 and $session_usd > 0
         then " · " + fg(C.yellow) + "\($session_usd / ($cost.total_duration_ms / 3600000) | usd)/h" + fg(C.subtext) else "" end)
      + (if ($s.output // 0) > 0 then " · \($s.output | tokens) out" else "" end)
      + (if ($cost.total_lines_added // 0) + ($cost.total_lines_removed // 0) > 0
         then " · " + fg(C.green) + "+\($cost.total_lines_added)" + fg(C.subtext) + "/" + fg(C.red) + "-\($cost.total_lines_removed)" + fg(C.subtext)
         else "" end)
      + (if ($cost.total_duration_ms // 0) > 60000 then " · \(($cost.total_duration_ms / 1000) | span)" else "" end)
      + reset ),
    # Today: recomputed from every transcript with current prices.
    ( if ($t.responses // 0) > 0 then
        dim("today ") + bold + fg(C.peach)
        + (if ($t.unpriced // 0) > 0 then "~" else "" end) + ($t.cost | usd) + reset
        + fg(C.subtext)
        + (if $t_in > 0 then " · cache \((($t.cache_read // 0) / $t_in * 100) | floor)%" else "" end)
        + (if ($t.saved // 0) >= 0.01 then " (saved \($t.saved | usd))" else "" end)
        + reset
      else empty end )
  ] | join(sep)) as $line4

| ($line1, $line2, $line3, $line4) | select(. != "") | " " + .
