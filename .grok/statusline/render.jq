# Compact Grok status line. At most five lines: Grok drops the rest.
# Colors are Catppuccin Mocha. $color == "0" drops escapes.
#
# stdin is the Grok status payload. $weather[0] and $today[0] are caches.
# $branch, $dirty, $ahead, $behind come from git.
# $synapse is the synapse context cache ({status, ...}) or null. The window
# stays on PROJECT and the session cost on COST. SYNAPSE and IMPACT are added
# only when that cache has something to say.

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

# Labels share a 10-column gutter. jq 1.6 has no string multiply.
def rowlabel($name; $hex):
  fg($hex) + bold + $name + reset + ("          "[($name | length):]);

def framed:
  length as $n
  | [range(0; $n) as $i
     | fg(C.overlay)
       + (if $i == 0 then "╭─ " elif $i == ($n - 1) then "╰─ " else "│  " end)
       + reset
       + .[$i]]
  | .[];

# Area from the cache. No area still gets a row, so the line is visibly there.
def synapse_body:
  (.synapse // null) as $syn
  | if $syn == null then
      dim(if (.repo // "") != "" then "ikke noe område for \(.repo)" else "ikke i et repo" end)
    else
      ($syn.live // null) as $live
      | [
          fg(C.mauve) + bold + "◆ \($syn.slug)@\($syn.size)" + reset,
          (if $syn.via == "antatt" then dim("antatt") else "" end),
          (if $live == null then dim("ikke sjekket")
           elif ($live.error // "") != "" then fg(C.yellow) + "⚠ svarer ikke" + reset
           elif $live.newer == true then fg(C.yellow) + bold + "↻ ny utgave" + reset
           elif $live.due == true then fg(C.teal) + "⏳ oppdateres" + reset
           else fg(C.green) + "✓ nyeste" + reset
           end)
        ] | join_present
    end;

# Last 7 days: sessions that received the area, and how many wrote back.
def impact_body:
  . as $i
  | (if ($i.ended // 0) > 0 then ($i.wroteBack / $i.ended) else null end) as $share
  | [
      fg(C.text) + "\($i.week // 0) \(if ($i.week // 0) == 1 then "økt" else "økter" end)/7d" + reset,
      (if $share == null then dim("ingen avsluttet ennå")
       else fg(if $share < 0.5 then C.yellow else C.green end) + "\(($share * 100) | round)% skrev tilbake" + reset
       end),
      (if ($i.ended // 0) > 0 then dim("\($i.wroteBack) av \($i.ended)") else "" end),
      (if $i.avgChars != null then fg(C.subtext) + "snitt \(($i.avgChars / 4) | tokens)" + reset else "" end)
    ] | join_present;

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

| (if ($synapse | type) == "object" then ($synapse.status // null) else null end) as $st
| (
    [$header,
     rowlabel("PROJECT"; C.blue) + $project,
     rowlabel("COST"; C.yellow) + (if $cost == "" then dim("—") else $cost end)]
    + (if $st == null then []
       else
         [rowlabel("SYNAPSE"; C.mauve) + ($st | synapse_body)]
         + (if ($st.impact // null) == null then []
            else [rowlabel("IMPACT"; C.teal) + ($st.impact | impact_body)] end)
       end)
  )
| framed
