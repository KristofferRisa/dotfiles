# Sum token usage and cost from Claude Code transcripts.
#
#   jq -nR --slurpfile prices pricing.json --arg sid SESSION -f usage.jq FILE...
#
# Reads raw lines so a half-written last line (a transcript mid-stream) is
# skipped instead of failing the whole run. Emits one object with "today"
# and "session" buckets.

($prices[0] | to_entries | map(select(.key | startswith("_") | not))) as $table

# Longest matching key wins: claude-opus-5-5 must not price as claude-opus-5.
| def price_for($model):
    [$table[] | select(.key as $k | $model | startswith($k))]
    | max_by(.key | length) | .value // null;

# Claude Code writes one line per content block; every line of a response
# repeats the same final usage. Count each response once.
def response_key: "\(.message.id // "")|\(.requestId // "")";

def empty_bucket:
  {cost: 0, saved: 0, unpriced: 0, responses: 0,
   input: 0, output: 0, cache_read: 0, cache_write: 0, models: {}};

def add_to($bucket; $c):
  $bucket
  | .responses += 1
  | .input += $c.input | .output += $c.output
  | .cache_read += $c.cache_read | .cache_write += $c.cache_write
  | if $c.cost == null then .unpriced += 1
    else .cost += $c.cost | .saved += $c.saved end
  | .models[$c.model] |= ((. // {responses: 0, cost: 0, output: 0, priced: ($c.cost != null)})
      | .responses += 1 | .output += $c.output | .cost += ($c.cost // 0));

# USD for one response. null when the model (or its fast-mode rate) is unknown.
def cost_of($model; $u):
  price_for($model) as $p
  | ($u.input_tokens // 0) as $in
  | ($u.output_tokens // 0) as $out
  | ($u.cache_read_input_tokens // 0) as $read
  | ($u.cache_creation_input_tokens // 0) as $write
  | ($u.cache_creation.ephemeral_1h_input_tokens // 0) as $write_1h
  | ($write - $write_1h) as $write_5m
  | (if ($u.speed // "standard") == "fast" then $p.fast // null else 1 end) as $mult
  | {model: $model, input: $in, output: $out, cache_read: $read, cache_write: $write}
  + if $p == null or $mult == null then {cost: null, saved: 0}
    else {
      cost: ((($in * $p.input) + ($out * $p.output)
              + ($write_5m * $p.input * 1.25) + ($write_1h * $p.input * 2)
              + ($read * $p.cache_read)) / 1e6 * $mult),
      # What the cached reads would have cost as plain input.
      saved: ($read * ($p.input - $p.cache_read) / 1e6 * $mult)
    } end;

# Local midnight as epoch seconds.
(now | localtime) as $t
| (now - ($t[3] * 3600 + $t[4] * 60 + $t[5])) as $midnight

| reduce (inputs | fromjson? // empty
          | select(.type == "assistant" and .message.usage != null)
          | select((.message.model // "<synthetic>") != "<synthetic>")) as $e (
    {seen: {}, today: empty_bucket, session: empty_bucket};
    ($e | response_key) as $key
    | if .seen[$key] then .
      else
        .seen[$key] = true
        | ($e.message.model | sub("^anthropic\\."; "") | sub("\\[.*\\]$"; "")) as $model
        | cost_of($model; $e.message.usage) as $c
        | (($e.timestamp // "") | sub("\\.[0-9]+Z$"; "Z") | (fromdateiso8601? // 0)) as $ts
        | if $ts >= $midnight then .today = add_to(.today; $c) else . end
        | if $e.sessionId == $sid then .session = add_to(.session; $c) else . end
      end
  )
| {today, session, computed_at: now}
