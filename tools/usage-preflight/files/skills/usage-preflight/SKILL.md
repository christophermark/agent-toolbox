---
name: usage-preflight
description: Check remaining Claude Code usage before starting work likely to consume substantial model usage — launching multiple subagents, running a comprehensive security review or workflow, broad repository-wide analysis, an extended autonomous implementation, or retrying a large workflow after interruption. Reads the cached status-line rate-limit payload and says how to interpret each status value.
---

# Usage-limit preflight

Run:

    ~/.claude/check-usage-limit.sh

Interpret the `status` field:

- `ok` — proceed normally.
- `warning` — proceed conservatively, reduce optional parallelism, and avoid
  unnecessary subagents.
- `critical` — do not start additional expensive optional work without first
  telling the user the current usage percentages and reset times.
- `unknown` — tell the user usage-limit information is unavailable.
- `stale` — tell the user only stale information is available, including how old
  it is. `stale_policy_status` shows what the cached numbers imply; report it,
  but do not present it as the current state.

Never interpret missing data as zero usage.

The data comes from the official status-line payload (`.rate_limits`), cached by
`~/.claude/statusline-command.sh`. Two limits follow from that, and both must be
stated honestly rather than papered over:

- The reading can be up to the status-line `refreshInterval` (30s) plus idle time
  old. Never describe a cached figure as live.
- The status line does not run in `-p`/headless sessions, and the payload only
  carries `rate_limits` "for subscribers after first API response" — so a fresh
  or headless session reads the cross-session cache rather than current data.

This is a preflight signal, not a guarantee that enough quota remains to finish a
workflow. Usage can change while work is running.
