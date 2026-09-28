# Compact Grok status line. At most three lines: Grok shows five and drops
# the rest. Colors are Catppuccin Mocha. $color == "0" drops escapes.
#
# stdin is the Grok status payload. $weather[0] and $today[0] are caches.
# $branch, $dirty, $ahead, $behind come from git.

def esc($code): if $color == "1" then "\u001b[\($code)m" else "" end;
def rgb($hex):
  $hex | [.[0:2], .[2:4], .[4:6]]
  | map(explode | map(if . > 96 then . - 87 elif . > 64 then . - 55 else . - 48 end) | .[0] * 16 + .[1])
  | join(";");
def fg($hex): esc("38;2;\(rgb($hex))");
def reset: esc("0");
def bold: esc("1");

def C: {
  overlay: "45475a", muted: "6c7086", text: "cdd6f4", subtext: "a6adc8",
  blue: "89b4fa", mauve: "cba6f7", green: "a6e3a1", yellow: "f9e2af", peach: "fab387",
  red: "f38ba8", teal: "94e2d5", lavender: "b4befe", sky: "89dceb", surface: "313244",
  base: "1e1e2e"
};

def tokens:
  if . == null then ""
  elif . >= 1e6 then "\((. / 1e5 | floor) / 10)M"
  elif . >= 1e3 then "\((. / 1e2 | floor) / 10)k"
  else "\(. | floor)" end;

def usd:
  if . == null then ""
  elif . >= 99.995 then "$\(. | round)"
  else (. * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)" end;

def span:
  if . == null or . < 60 then ""
  else
    ((. / 60) | floor) as $m
    | if $m < 60 then "\($m)m"
      elif $m < 1440 then "\(($m / 60) | floor)h\($m % 60)m"
      else "\(($m / 1440) | floor)d\((($m % 1440) / 60) | floor)h" end
  end;

def level($warn; $crit): if . >= $crit then C.red elif . >= $warn then C.yellow else C.green end;
def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;

def gauge($pct; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | [range(0; $width) as $i
     | if $i < $n then fg(($i + 0.5) / $width * 100 | level(50; 80)) + "▰"
       else fg(C.surface) + "▱" end]
  | join("") + reset;

def dim($s): fg(C.muted) + $s + reset;
def dot: fg(C.overlay) + "  ·  " + reset;

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

def wind_arrow: ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][((. + 180) % 360 / 45 | round) % 8];

def join_present: map(select(. != null and . != "")) | join(dot);

($weather[0] // null) as $w
| ($today[0] // {}) as $t
| now as $now
| (.workspace.current_dir // .cwd // "") as $dir
| (.context_window // {}) as $cw
| ($cw.used_percentage // null) as $ctx_pct
| ($cw.context_window_size // null) as $size
| ($cw.context_tokens // null) as $ctx_tokens
| ($cw.session_output_tokens // $cw.session_usage.output_tokens // null) as $out_tokens
| ($cw.session_usage // {}) as $su
| (($su.input_tokens // 0) + ($su.cache_read_input_tokens // 0) + ($su.cache_creation_input_tokens // 0)) as $sess_in
| (.cost.total_cost_usd // null) as $session_usd
| (.cost.total_duration_ms // null) as $dur_ms
| (.model.display_name // .model.id // "") as $model
| (.effort.level // "") as $effort
| (.worktree.name // .workspace.git_worktree // "") as $worktree

| ([
    (if $w != null and ($w.temperature != null) then
       fg(C.blue) + bold + (($w.location.name // "") | split(",")[0]) + reset
       + " " + (($w.symbol // "") | weather_icon)
       + " " + fg(C.peach) + bold + "\($w.temperature | round)°" + reset
       + (if $w.wind_speed != null then
            fg(C.teal) + " \(($w.wind_degrees // 0) | wind_arrow) \($w.wind_speed | round) m/s" + reset
          else "" end)
     else null end),
    (fg(C.lavender) + ($now | strflocaltime("%a %-d %b  ")) + bold + ($now | strflocaltime("%H:%M")) + reset),
    (if .version then dim("Grok ") + fg(C.blue) + .version + reset else null end)
  ] | join_present) as $header

| (
    fg(C.blue) + bold + (if $dir != "" then ($dir | split("/") | last) else "—" end) + reset
    + (if $branch != "" then
         "  " + fg(if $dirty != "0" then C.yellow else C.green end)
         + $branch
         + (if $dirty != "0" then " ●\($dirty)" else "" end)
         + (if $ahead != "0" and $ahead != "" then " ⇡\($ahead)" else "" end)
         + (if $behind != "0" and $behind != "" then " ⇣\($behind)" else "" end)
         + reset
       else "" end)
    + (if $worktree != "" then "  " + fg(C.teal) + $worktree + reset else "" end)
    + (if $model != "" then
         "  " + fg(C.text) + $model + (if $effort != "" then " · \($effort)" else "" end) + reset
       else "" end)
    + (if $ctx_pct != null then
         "   " + gauge($ctx_pct; 10)
         + " " + fg($ctx_pct | level(60; 80)) + bold + "\($ctx_pct | round)%" + reset
         + (if $ctx_tokens != null and $size != null then
              "  " + fg(C.text) + ($ctx_tokens | tokens) + dim("/") + fg(C.subtext) + ($size | tokens) + reset
            else "" end)
       else "" end)
  ) as $project

| (
    [
      (if $session_usd != null and $session_usd >= 0.005 then
         fg(C.text) + bold + ($session_usd | usd) + reset + dim(" session")
       else null end),
      (if $session_usd != null and $session_usd >= 0.005 and ($dur_ms // 0) >= 300000 then
         fg(C.yellow) + "\($session_usd / ($dur_ms / 3600000) | usd)/h" + reset
       else null end),
      (if ($out_tokens // 0) > 0 then fg(C.subtext) + "\($out_tokens | tokens) out" + reset else null end),
      (if ($dur_ms // 0) >= 60000 then fg(C.subtext) + (($dur_ms / 1000) | span) + reset else null end),
      (if ($t.responses // 0) > 0 or ($t.cost // 0) >= 0.005 then
         fg(C.peach) + bold + ($t.cost | usd) + reset + dim(" today")
       else null end),
      (if $sess_in > 0 then
         fg(C.teal) + "cache \((($su.cache_read_input_tokens // 0) / $sess_in * 100) | floor)%" + reset
       elif ($t.input // 0) + ($t.cache_read // 0) + ($t.cache_write // 0) > 0 then
         fg(C.teal) + "cache \((($t.cache_read // 0) / (($t.input + $t.cache_read + $t.cache_write)) * 100) | floor)%" + reset
       else null end)
    ] | join_present
  ) as $cost

| fg(C.overlay) as $frame
| ($frame + "╭─ " + reset + $header),
  ($frame + "│  " + reset + fg(C.blue) + bold + "PROJECT" + reset + "   " + $project),
  ($frame + "╰─ " + reset + fg(C.yellow) + bold + "COST" + reset + "      " + (if $cost == "" then dim("—") else $cost end))
