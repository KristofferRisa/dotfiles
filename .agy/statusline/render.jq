# Render the Antigravity CLI (agy) status line from agy's JSON input (.),
# cached weather ($weather[0]), optional Synapse context ($synapse), and git
# state ($branch, $dirty, $ahead, $behind).
#
# Matches the Claude Code panel (Catppuccin Mocha, labelled rows in aligned
# columns, powerline segments on PROJECT). $compact == "1" (--compact or
# AGY_STATUSLINE_COMPACT=1) folds the panel into compact rows. $color == "0"
# (NO_COLOR) drops all escape codes.

def esc($code): if $color == "1" then "\u001b[\($code)m" else "" end;
def rgb($hex):
  $hex | [.[0:2], .[2:4], .[4:6]]
  | map(explode | map(if . > 96 then . - 87 elif . > 64 then . - 55 else . - 48 end) | .[0] * 16 + .[1])
  | join(";");
def fg($hex): esc("38;2;\(rgb($hex))");
def bg($hex): esc("48;2;\(rgb($hex))");
def reset: esc("0");
def bold: esc("1");

def C: {
  base: "1e1e2e", surface: "313244", overlay: "45475a", muted: "6c7086", text: "cdd6f4", subtext: "a6adc8",
  blue: "89b4fa", mauve: "cba6f7", green: "a6e3a1", yellow: "f9e2af", peach: "fab387",
  red: "f38ba8", teal: "94e2d5", lavender: "b4befe", sky: "89dceb", pink: "f5c2e7"
};

# Portable across jq 1.6 and 1.7 (jq 1.6 has no string multiply).
def spaces($n): if $n <= 0 then "" else [range(0; $n) | " "] | join("") end;
def dashes($n): if $n <= 0 then "" else [range(0; $n) | "─"] | join("") end;

# 1234 -> 1.2k, 1234567 -> 1.2M
def tokens:
  if . == null then ""
  elif . >= 1e6 then "\((. / 1e5 | floor) / 10)M"
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

def level($warn; $crit): if . >= $crit then C.red elif . >= $warn then C.yellow else C.green end;
def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;

# Pad plain text to a column width before coloring (escapes have length but no width).
def pad($w): . + spaces($w - length);
def col($w; $c): fg($c) + pad($w) + reset;

def gauge($pct; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | [range(0; $width) as $i
     | if $i < $n then fg(($i + 0.5) / $width * 100 | level(50; 80)) + "▰"
       else fg(C.surface) + "▱" end]
  | join("") + reset;

def pace_bar($pct; $pace; $width):
  (($pct / 100 * $width) | round | clamp(0; $width)) as $n
  | (($pace / 100 * $width) | round | clamp(0; $width)) as $m
  | [range(0; $width + 1) as $i
     | (if $i == $m then fg(C.lavender) + bold + "┃" + reset else "" end)
       + (if $i == $width then ""
          elif $i < $n then fg($pct | level(70; 90)) + "▰"
          else fg(C.surface) + "▱" end)]
  | join("") + reset;

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
def sdot: fg(C.overlay) + "  ·  " + reset;
def join_present($sep): map(select(. != null and . != "")) | join($sep);
def row($label; $c; $body): {label: $label, color: $c, body: $body};

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

# Infer quota window duration in seconds from bucket name for pace calculation.
def quota_window:
  ascii_downcase
  | if test("weekly|7d|week") then 604800
    elif test("daily|24h|day") then 86400
    elif test("5h|five") then 18000
    elif test("hourly|1h") then 3600
    else null end;

def quota_label:
  ascii_downcase as $k
  | if ($k | test("weekly|7d|week")) then "7 DAY"
    elif ($k | test("daily|24h|day")) then "DAILY"
    elif ($k | test("5h|five")) then "5 HOUR"
    elif ($k | test("hourly|1h")) then "1 HOUR"
    else (ascii_upcase | gsub("[^A-Z0-9]+"; " ") | .[0:9]) end;

def quota_short_label:
  ascii_downcase as $k
  | if ($k | test("weekly|7d|week")) then "7d"
    elif ($k | test("daily|24h|day")) then "1d"
    elif ($k | test("5h|five")) then "5h"
    elif ($k | test("hourly|1h")) then "1h"
    else (.[0:8]) end;

def quota_row($now):
  .key as $k
  | .value as $q
  | ((1 - $q.remaining_fraction) * 100 | clamp(0; 100)) as $used
  | ($q.reset_in_seconds // null) as $in_s
  | (if $in_s != null then $now + $in_s else null end) as $reset
  | ($k | quota_window) as $win
  | (if $in_s != null and $win != null then (1 - ($in_s / $win)) | clamp(0; 1) else null end) as $elapsed
  | ($used | level(70; 90)) as $lc
  | row($k | quota_label; C.pink;
      (if $elapsed != null then pace_bar($used; $elapsed * 100; 20) else gauge($used; 20) + " " end)
      + "   " + bold + ("\($used | round)%" | col(6; $lc))
      + (if $elapsed != null then
           ($used - $elapsed * 100) as $d
           | if $d >= 5 then ("⇡ \($d | round)%" | col(10; C.red))
             elif $d <= -5 then ("⇣ \(-$d | round)%" | col(10; C.green))
             else ("on pace" | col(10; C.muted)) end
         else spaces(10) end)
      + (if $reset != null then
           dim("resets ") + (($reset | clock($now)) | col(11; C.text))
           + dim("in ") + (($in_s | clamp(0; infinite) | span) | col(9; C.subtext))
         else "" end)
      + (if $elapsed != null and $elapsed > 0.02 and $used >= 1 and $used < 100 then
           ($now + (100 - $used) / ($used / ($elapsed * $win))) as $full
           | if $full < $reset then fg(C.red) + bold + "⚠ full by \($full | clock($now))" + reset else "" end
         else "" end));

def quota_short($now):
  .key as $k
  | .value as $q
  | ((1 - $q.remaining_fraction) * 100 | clamp(0; 100)) as $used
  | ($q.reset_in_seconds // null) as $in_s
  | (if $in_s != null then $now + $in_s else null end) as $reset
  | ($k | quota_window) as $win
  | (if $in_s != null and $win != null then (1 - ($in_s / $win)) | clamp(0; 1) else null end) as $elapsed
  | dim(($k | quota_short_label) + " ")
    + (if $elapsed != null then pace_bar($used; $elapsed * 100; 10) else gauge($used; 10) end)
    + " " + fg($used | level(70; 90)) + bold + "\($used | round)%" + reset
    + (if $elapsed != null then
         ($used - $elapsed * 100) as $d
         | if $d >= 5 then fg(C.red) + " ⇡\($d | round)%" + reset
           elif $d <= -5 then fg(C.green) + " ⇣\(-$d | round)%" + reset
           else "" end
       else "" end)
    + (if $reset != null then dim(" ↻") + fg(C.text) + ($reset | clock($now)) + reset else "" end)
    + (if $elapsed != null and $elapsed > 0.02 and $used >= 1 and $used < 100 then
         ($now + (100 - $used) / ($used / ($elapsed * $win))) as $full
         | if $full < $reset then fg(C.red) + bold + " ⚠\($full | clock($now))" + reset else "" end
       else "" end);

# Mode badge matching Synapse's own context/render.ts.
def mode_badge:
  if . == "dynamisk" then bg(C.mauve) + fg(C.base) + " dynamisk " + reset
  elif . == "begge" then bg(C.blue) + fg(C.base) + " dynamisk + statisk " + reset
  elif . == "statisk" then bg(C.peach) + fg(C.base) + " statisk " + reset
  elif . == "ingen" then bg(C.red) + fg(C.base) + " ingen kontekst " + reset
  else "" end;

def synapse_body($is_compact):
  (.synapse // null) as $syn
  | (.mode // null) as $mode
  | (if $mode != null then ($mode | mode_badge) + " " else "" end) as $badge
  | if $syn == null then
      $badge + dim(if (.repo // "") != "" then "ikke noe område for \(.repo)" else "ikke i et repo" end)
    else
      ($syn.live // null) as $live
      | $badge + ([
          fg(C.mauve) + bold + "◆ \($syn.slug)@\($syn.size)" + reset,
          (if ($is_compact != "1") and (($syn.chars // 0) > 0) then fg(C.text) + "\($syn.tokens | tokens) tok" + reset else null end),
          (if $syn.via == "antatt" then dim("antatt")
           elif ($is_compact != "1") and (($syn.via // "") != "") then dim("via \($syn.via)")
           else null end),
          (if $live == null then dim("ikke sjekket")
           elif ($live.error // "") != "" then fg(C.yellow) + "⚠ svarer ikke" + reset
           elif $live.newer == true then fg(C.yellow) + bold + "↻ ny utgave" + reset
           elif $live.due == true then fg(C.teal) + "⏳ oppdateres" + reset
           else fg(C.green) + "✓ nyeste" + reset
           end)
        ] | join_present(sdot))
    end;

def file_mark:
  (if .read then fg(C.text) + .label + reset + fg(C.subtext) + " \(.tokens | tokens)" + reset
   else dim("\(.label) (leses ikke)") end)
  + (if .stale then " " + fg(C.yellow) + "✎" + reset else "" end)
  + (if .git == "modified" or .git == "untracked" then (if .stale then "" else " " end) + fg(C.yellow) + "●" + reset else "" end);

def agents_body:
  (.files // []) as $all
  | ([$all[] | select(.read)] + [$all[] | select((.read | not) and .scope != "global")]) as $list
  | ($list[0:6]) as $shown
  | if ($shown | length) > 0 then
      ($shown | map(file_mark) | join(sdot))
      + (if ($list | length) > ($shown | length) then dim("  +\(($list | length) - ($shown | length))") else "" end)
    else null end;

def impact_body:
  . as $i
  | (if ($i.ended // 0) > 0 then ($i.wroteBack / $i.ended) else null end) as $share
  | [
      fg(C.text) + "\($i.week // 0) \(if ($i.week // 0) == 1 then "økt" else "økter" end)/7d" + reset,
      (if $share == null then dim("ingen avsluttet ennå")
       else fg(if $share < 0.5 then C.yellow else C.green end) + "\(($share * 100) | round)% skrev tilbake" + reset
       end),
      (if ($i.ended // 0) > 0 then dim("\($i.wroteBack) av \($i.ended)") else null end),
      (if $i.avgChars != null then fg(C.subtext) + "snitt \(($i.avgChars / 4) | tokens)" + reset else null end)
    ] | join_present(sdot);

($weather[0] // null) as $w
| now as $now

# ---- header: weather, date/time, AGY version, mode/sandbox ----
| ([
    (if $w != null and $w.temperature != null then
       fg(C.blue) + bold + " " + (($w.location.name // "") | split(",")[0]) + reset + "   "
       + (($w.symbol // "") | weather_icon) + " "
       + fg(C.peach) + bold + "\($w.temperature | round)°" + reset
       + (if $w.feels_like != null and (($w.feels_like - $w.temperature) | fabs) >= 1 and $compact != "1"
          then dim("  feels \($w.feels_like | round)°") else "" end)
       + (if $w.wind_speed != null then
            fg(C.teal) + "  \(($w.wind_degrees // 0) | wind_arrow) \($w.wind_speed | round) m/s" + reset
          else "" end)
       + (if $compact == "1" then ""
          elif ($w.precipitation // 0) > 0 then fg(C.sky) + "  ☔ \($w.precipitation) mm" + reset
          elif $w.humidity != null then fg(C.sky) + "  💧 \($w.humidity | round)%" + reset
          else "" end)
     else empty end),
    (fg(C.lavender) + ($now | strflocaltime("%a %-d %b  ")) + bold + ($now | strflocaltime("%H:%M")) + reset),
    (if .version then
       dim("AGY ") + fg(C.blue) + .version + reset
       + (if (.plan_tier // "") != "" then dim(" \(.plan_tier)") else "" end)
     else dim("AGY") end),
    (if (.cycle_mode // "") != "" then
       fg(if .cycle_mode == "plan" then C.mauve elif .cycle_mode == "auto" then C.green else C.teal end) + bold + .cycle_mode + reset
     else empty end),
    (if .sandbox.enabled == true then fg(C.teal) + "sandbox" + reset else empty end),
    (if (.vim.mode // "") != "" then fg(C.green) + bold + .vim.mode + reset else empty end)
  ] | join(dot)) as $header

# ---- workspace: directory, git, model + effort, context window ----
| (.workspace.current_dir // .cwd // "") as $dir
| (.model.display_name // .model.id // "") as $model_name
| (.model.effort // "") as $effort
| (if $model_name == "" then "AGY"
   elif $effort != "" and (($model_name | ascii_downcase) | contains($effort | ascii_downcase) | not) then
     "\($model_name) · \($effort)"
   else $model_name end) as $model_label
| (.context_window // {}) as $cw
| (if ($cw.context_window_size // 0) > 0 then $cw.context_window_size else null end) as $size
| ($cw.current_usage // null) as $cur
| (if $cur != null then
     ($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0)
   else null end) as $cur_tokens
| (if $cw.used_percentage != null then $cw.used_percentage
   elif $cur_tokens != null and $size != null then ($cur_tokens / $size * 100)
   else null end) as $ctx_pct
| (if $cur_tokens != null and $cur_tokens > 0 then $cur_tokens
   elif $ctx_pct != null and $size != null then ($ctx_pct / 100 * $size)
   else null end) as $ctx_tokens

| [
    row("PROJECT"; C.blue; [
      (if $dir != "" then {bg: C.blue, fg: C.base, text: " \($dir | split("/") | last)"} else empty end),
      (if $branch != "" then {bg: C.surface, fg: (if $dirty != "0" then C.yellow else C.green end),
         text: (" \($branch)"
           + (if $dirty != "0" then " ●\($dirty)" else "" end)
           + (if $ahead != "0" and $ahead != "" then " ⇡\($ahead)" else "" end)
           + (if $behind != "0" and $behind != "" then " ⇣\($behind)" else "" end))} else empty end),
      {bg: C.overlay, fg: C.text, text: $model_label},
      (if (.agent.name // "") != "" then {bg: C.mauve, fg: C.base, text: "󰚩 \(.agent.name)"} else empty end)
    ] | join_segments
      + (if $compact == "1" and $ctx_pct != null then
           "   " + gauge($ctx_pct; 10) + " " + fg($ctx_pct | level(60; 80)) + bold + "\($ctx_pct | round)%" + reset
         else "" end)),
    (if $ctx_pct != null and $compact != "1" then
       row("CONTEXT"; C.mauve;
         gauge($ctx_pct; 24) + "   " + bold + ("\($ctx_pct | round)%" | col(6; $ctx_pct | level(60; 80)))
         + (if $ctx_tokens != null and $size != null then
              fg(C.text) + ($ctx_tokens | tokens) + dim(" of ") + fg(C.subtext) + ($size | tokens) + reset
            else "" end))
     else empty end)
  ] as $workspace

# ---- quotas: active buckets with pace bar and reset countdown ----
| ((.quota // {}) | to_entries
   | map(select((.value.disabled // false) != true and .value.remaining_fraction != null))
   | sort_by(.key)) as $quotas
| (if ($quotas | length) == 0 then []
   elif $compact == "1" then
     [row("QUOTA"; C.pink; ($quotas | map(quota_short($now)) | join(dot)))]
   else
     [$quotas[] | quota_row($now)]
   end) as $limits

# ---- session: estimated cost, output tokens, cache hit rate, live activity ----
| (.cost // null) as $cost
| ($cw.total_output_tokens // 0) as $out_tok
| (if $cur != null then
     (($cur.input_tokens // 0) + ($cur.cache_read_input_tokens // 0) + ($cur.cache_creation_input_tokens // 0)) as $in_tot
     | if $in_tot > 0 then (($cur.cache_read_input_tokens // 0) / $in_tot * 100) | floor else null end
   else null end) as $cache_pct
| ((.subagents // []) | map(select(.status == "running")) | length) as $sub_run
| ((.subagents // []) | length) as $sub_all
| (.task_count // 0) as $tasks
| (.artifact_count // 0) as $arts
| (.pending_input_count // 0) as $queued
| ([
    (if $cost != null and ($cost.total_usd // 0) >= 0.005 then
       fg(C.text) + bold + (if $cost.estimated == true then "~" else "" end) + ($cost.total_usd | usd) + reset
       + (if $compact == "1" then dim(" session") else "" end)
     else null end),
    (if $out_tok > 0 then fg(C.subtext) + "\($out_tok | tokens) out" + reset else null end),
    (if $cache_pct != null and $cache_pct > 0 then fg(C.teal) + "cache \($cache_pct)%" + reset else null end),
    (if $sub_run > 0 then fg(C.mauve) + "\($sub_run) sub" + reset
     elif $sub_all > 0 and $compact != "1" then dim("\($sub_all) sub") else null end),
    (if $tasks > 0 then fg(C.yellow) + "\($tasks) \(if $tasks == 1 then "task" else "tasks" end)" + reset else null end),
    (if $arts > 0 then fg(C.sky) + "\($arts) art" + reset else null end),
    (if $queued > 0 then fg(C.peach) + "\($queued) queued" + reset else null end)
  ] | join_present(if $compact == "1" then dot else sdot end)) as $session_body
| (if $session_body != "" then
     [row(if $compact == "1" then "COST" else "SESSION" end; C.yellow; $session_body)]
   else [] end) as $money

# ---- synapse: area, static instruction files, and 7-day impact ----
| (if ($synapse | type) == "object" then ($synapse.status // null) else null end) as $st
| (if $st == null then []
   else
     [row("SYNAPSE"; C.mauve; ($st | synapse_body($compact)))]
     + (if $compact != "1" then
          ($st | agents_body) as $ab
          | if $ab != null then [row("AGENTS"; C.peach; $ab)] else [] end
        else [] end)
     + (if $compact != "1" and ($st.impact // null) != null then
          [row("IMPACT"; C.teal; ($st.impact | impact_body))]
        else [] end)
   end) as $synapse_rows

# ---- assemble framed panel ----
| [$workspace, $limits, $money, $synapse_rows] | map(select(length > 0)) as $sections
| ([$sections | to_entries[] | (if .key > 0 and $compact != "1" then {spacer: true} else empty end), .value[]]) as $rows
| ($rows | length) as $n
| fg(C.overlay) as $frame
| ($frame + "╭─ " + reset + $header + (if $compact == "1" then "" else "  " + $frame + dashes(10) + reset end)),
  (if $n > 0 and $compact != "1" then $frame + "│" + reset else empty end),
  ($rows | to_entries[]
   | .value as $r
   | (if .key == $n - 1 then "╰─ " else "│  " end) as $edge
   | if $r.spacer then $frame + "│" + reset
     else $frame + $edge + reset + fg($r.color) + bold + ($r.label | pad(10)) + reset + $r.body end)
