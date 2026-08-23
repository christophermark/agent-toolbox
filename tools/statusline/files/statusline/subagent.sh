#!/usr/bin/env bash
# Per-subagent status line, rendered for each row of the agent panel.
#
#   settings.json -> "subagentStatusLine": { "type": "command",
#                      "command": "bash ~/.claude/statusline/subagent.sh" }
#
# CONTRACT (verified against the Claude Code 2.1.238 binary):
#   stdin   the base status-line payload, plus:
#             columns : terminal width, as a number
#             tasks[] : { id, name, type, status, description, label, startTime,
#                         model, effort, contextWindowSize, tokenCount,
#                         tokenSamples[], cwd }
#           tokenSamples is a rolling window of the last 16 tokenCount readings,
#           which is what makes a trend sparkline possible.
#   stdout  one JSON object per line: {"id": "<task id>", "content": "<text>"}
#           Lines that aren't valid JSON, or don't match that schema, are logged
#           as errors and dropped — so this must never print anything else.
#   limits  5s timeout. Non-zero exit discards the whole batch.
#
# Everything happens in a single jq pass: one process for the whole panel.

input=$(cat)

if [ "${CC_STATUSLINE_CAPTURE:-0}" = "1" ]; then
  HERE=$(cd "$(dirname "$0")" && pwd)
  printf '%s\n' "$input" > "$HERE/last-subagent-payload.json" 2>/dev/null
  chmod 600 "$HERE/last-subagent-payload.json" 2>/dev/null
fi

jq -c '
  def esc: "\u001b[";
  def c(n): esc + n + "m";
  def dim:   c("2");    def reset: c("0");
  def red:   c("31");   def grn: c("32");  def yel: c("33");
  def cyn:   c("36");   def mag: c("35");  def gry: c("90");

  # 8-level sparkline over the rolling token-count window. Flat or absent
  # samples produce nothing rather than a misleading flat line.
  def spark:
    (map(select(type == "number")) // []) as $s
    | if ($s | length) < 2 then ""
      else
        ($s | min) as $lo | ($s | max) as $hi
        | if $hi <= $lo then ""
          else ($s | map(
                 ((. - $lo) * 7 / ($hi - $lo)) | floor
                 | ["▁","▂","▃","▄","▅","▆","▇","█"][.]
               ) | join(""))
          end
      end;

  def human:
    if . == null then ""
    elif . >= 1000000 then
      ((. / 100000) | floor) as $t
      | if ($t % 10) == 0 then "\($t / 10 | floor)M" else "\($t / 10 | floor).\($t % 10)M" end
    elif . >= 1000 then "\((. / 1000) | floor)k"
    else "\(.)" end;

  def elapsed(now):
    if . == null or . == 0 then ""
    else ((now - (. / 1000)) | floor) as $s
      | if $s < 0 then ""
        elif $s >= 3600 then "\(($s / 3600) | floor)h\((($s % 3600) / 60) | floor)m"
        elif $s >= 60 then "\(($s / 60) | floor)m"
        else "\($s)s" end
    end;

  def statusmark:
    if   . == "running"   then grn + "▸" + reset
    elif . == "completed" then gry + "✓" + reset
    elif . == "failed"    then red + "✗" + reset
    elif . == "cancelled" then gry + "⊘" + reset
    elif . == "queued"    then dim + "◌" + reset
    else dim + "·" + reset end;

  (now | floor) as $now
  | .tasks[]?
  | . as $t
  | (if ($t.contextWindowSize // 0) > 0 and ($t.tokenCount // 0) > 0
     then (($t.tokenCount * 100 / $t.contextWindowSize) | floor) else null end) as $pct
  | (if $pct == null then ""
     else (if $pct >= 80 then red elif $pct >= 60 then yel else grn end)
          + "\($pct)%" + reset
     end) as $pctseg
  | ($t.tokenSamples // [] | spark) as $sp
  | ($t.tokenCount // 0 | human) as $tok
  | ($t.startTime | elapsed($now)) as $el
  | [ ($t.status // "" | statusmark)
    , (if ($t.effort // "") != "" then mag + $t.effort + reset else empty end)
    , (if $pctseg != "" then $pctseg else empty end)
    , (if $tok != "" and $tok != "0" then dim + $tok + reset else empty end)
    , (if $sp != "" then cyn + $sp + reset else empty end)
    , (if $el != "" then gry + $el + reset else empty end)
    ]
  | join(" ")
  | { id: $t.id, content: . }
' <<<"$input" 2>/dev/null

exit 0
