#!/usr/bin/env bash
# check-usage-limit.sh — agent-readable Claude Code subscription usage preflight.
#
# Emits a single JSON object on stdout in every case (including error cases) and
# signals the policy verdict through the exit code:
#
#   0   ok       proceed normally
#   10  warning  reduce optional parallelism, avoid unnecessary subagents
#   20  critical do not begin expensive optional work without explicit approval
#   30  unknown  no usable usage data — report as undetermined, NEVER as 0%
#   31  stale    data older than the freshness window — report the values and
#                their age, but do not treat them as current
#
# Thresholds (five-hour window):  >=75 warning, >=85 critical
# Thresholds (weekly windows):    >=90 warning, >=95 critical
# Weekly thresholds are applied to seven_day and, when present, to the
# model-specific seven_day_opus / seven_day_sonnet windows.
#
# DATA SOURCE
# The official Claude Code status-line payload field `.rate_limits`, captured by
# ~/.claude/statusline-command.sh. Two consequences worth knowing:
#   * The payload only carries rate_limits "for subscribers after first API
#     response", so a brand-new session has not populated it yet.
#   * The status line does not run in -p / headless sessions, so those read the
#     cache but never refresh it.
# This is a preflight signal, not a guarantee that quota remains to finish a
# workflow. Values can be up to (statusLine refreshInterval + idle time) old.
#
# Overrides: CLAUDE_USAGE_CACHE (path), CLAUDE_USAGE_STALE_AFTER (seconds).

cache_file="${CLAUDE_USAGE_CACHE:-${HOME}/.claude/usage-limits.json}"
stale_after="${CLAUDE_USAGE_STALE_AFTER:-1800}" # 30 minutes

# Treat a missing or malformed cache the same way: no usable data.
if [ -f "$cache_file" ] && cache="$(jq '.' "$cache_file" 2>/dev/null)" \
  && [ -n "$cache" ]; then
  :
else
  cache='null'
fi

# Guard against a non-numeric override reaching --argjson.
case "$stale_after" in
'' | *[!0-9]*) stale_after=1800 ;;
esac

output="$(
  jq -n \
    --argjson cache "$cache" \
    --argjson stale_after "$stale_after" '
  def sev(w; c):
    if . == null then null
    elif . >= c then "critical"
    elif . >= w then "warning"
    else "ok" end;
  def rank: if . == "critical" then 2 elif . == "warning" then 1 else 0 end;
  # resets_at is documented as Unix epoch seconds; tolerate a string form too.
  def iso: if . == null then null
    elif type == "number" then (floor | todate)
    else . end;
  def pct: if type == "number" then . else null end;

  $cache as $c
  | (if ($c | type) == "object" then $c else {} end) as $c
  | (if ($c.rate_limits | type) == "object" then $c.rate_limits else {} end) as $r
  | ($r.five_hour.used_percentage         | pct) as $p5
  | ($r.seven_day.used_percentage         | pct) as $p7
  | ($r.seven_day_opus.used_percentage    | pct) as $p7o
  | ($r.seven_day_sonnet.used_percentage  | pct) as $p7s
  | ([($p5 | sev(75; 85)), ($p7 | sev(90; 95)),
      ($p7o | sev(90; 95)), ($p7s | sev(90; 95))]
     | map(select(. != null))) as $sevs
  | (if ($c.captured_at | type) == "number"
     then ((now | floor) - ($c.captured_at | floor)) else null end) as $age
  | (($sevs | length) == 0) as $no_data
  | (if $age == null then null else ($age > $stale_after) end) as $is_stale
  | (if $no_data then null else ($sevs | max_by(rank)) end) as $policy
  | (if $no_data then "unknown"
     elif $is_stale == true then "stale"
     else $policy end) as $status
  | {
      status: $status,
      stale: (if $no_data then null else ($is_stale // false) end),
      age_seconds: $age,
      captured_at_iso: ($c.captured_at_iso // null),
      model: ($c.model // null),
      five_hour_used_percentage: $p5,
      five_hour_resets_at: ($r.five_hour.resets_at // null),
      five_hour_resets_at_iso: ($r.five_hour.resets_at | iso),
      seven_day_used_percentage: $p7,
      seven_day_resets_at: ($r.seven_day.resets_at // null),
      seven_day_resets_at_iso: ($r.seven_day.resets_at | iso),
      seven_day_opus_used_percentage: $p7o,
      seven_day_opus_resets_at_iso: ($r.seven_day_opus.resets_at | iso),
      seven_day_sonnet_used_percentage: $p7s,
      # What the cached numbers imply, surfaced separately so a critical
      # reading is not lost behind a "stale" status.
      stale_policy_status: (if $status == "stale" then $policy else null end),
      recommendation: (
        if $status == "ok" then "continue"
        elif $status == "warning"
          then "reduce optional parallelism and avoid unnecessary subagents"
        elif $status == "critical"
          then "do not begin expensive optional work without explicit user approval"
        elif $status == "unknown"
          then "report that usage could not be determined"
        else "report the last known values and their age, but do not treat them as current"
        end
      ),
    }
' 2>/dev/null
)"

# If jq itself failed, still emit valid JSON rather than nothing.
if [ -z "$output" ]; then
  printf '%s\n' '{"status":"unknown","stale":null,"age_seconds":null,"recommendation":"report that usage could not be determined"}'
  exit 30
fi

printf '%s\n' "$output"

case "$(printf '%s' "$output" | jq -r '.status')" in
ok) exit 0 ;;
warning) exit 10 ;;
critical) exit 20 ;;
stale) exit 31 ;;
*) exit 30 ;;
esac
