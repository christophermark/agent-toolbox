# Usage-limit preflight

Lets an agent check how much subscription quota is left *before* it starts work
that burns a lot of it — a subagent fan-out, a comprehensive security review, a
Dynamic Workflow, a long autonomous implementation.

The problem it solves is narrow and specific: Claude Code shows usage to the
human in the status line, but the model driving the session has no way to read
it. So an agent asked to "audit the whole repo" will happily start a ten-agent
fan-out at 94% of the weekly window and hit the wall halfway through. This tool
gives the model a number to look at, and a policy for what to do with each
reading.

## How it works

Three pieces and a cache file:

| Component | File | Role |
|---|---|---|
| Capture | `files/statusline-command.sh` | The official status-line payload carries `.rate_limits`. The status line is the only place it surfaces, so the capture block persists it to a cache file on every render |
| Read + policy | `files/check-usage-limit.sh` | Reads the cache, applies thresholds, emits one JSON object on stdout and signals the verdict through the exit code |
| Skill | `files/skills/usage-preflight/SKILL.md` | Tells the agent to run the script and how to interpret each `status` value |
| Policy hook | `files/claude-md/usage-preflight.md` | A `## Usage-limit preflight` section for `~/.claude/CLAUDE.md` — the always-loaded line that makes the agent reach for the skill unprompted |

Data flows one way: status line renders → cache written → agent runs the script
→ skill says what the verdict means.

### Verdicts

| `status` | Exit | Meaning |
|---|---|---|
| `ok` | 0 | Proceed normally |
| `warning` | 10 | Reduce optional parallelism, avoid unnecessary subagents |
| `critical` | 20 | Don't begin expensive optional work without explicit approval |
| `unknown` | 30 | No usable data — report as undetermined, **never** as 0% |
| `stale` | 31 | Data older than the freshness window — report the values *and their age* |

Thresholds: five-hour window ≥75 warning, ≥85 critical. Weekly windows
(`seven_day` plus the model-specific `seven_day_opus` / `seven_day_sonnet`)
≥90 warning, ≥95 critical. The worst window wins.

## Design principles

1. **Missing data is never zero usage.** The most dangerous failure mode is an
   agent reading an empty cache as "0% used" and launching the fan-out anyway.
   `unknown` and `stale` are first-class statuses with their own exit codes, and
   the skill spends most of its words on them.
2. **Stale readings still carry their verdict.** A cache that is 40 minutes old
   and says 96% is worth acting on. Collapsing that to a bare `stale` throws away
   the signal, so `stale_policy_status` reports what the cached numbers imply,
   separately from the freshness warning.
3. **Honest about what it can't know.** The reading can be up to
   `refreshInterval` (30s) plus idle time old, and the status line doesn't run in
   `-p`/headless sessions at all — those read the cross-session cache but never
   refresh it. Both limits are stated in the skill rather than papered over. This
   is a preflight signal, not a guarantee that quota remains to *finish*.
4. **Never erase good data.** The capture block only writes when a real
   percentage is present, and writes atomically via `mktemp` + `mv`. A payload
   without `rate_limits` (a brand-new session, before the first API response)
   leaves the previous cache intact.
5. **The status line is yours, the capture block is ours.** Most people already
   have a status line they like. The payload ships a complete working one, but
   the installable contract is the capture block — graft it into whatever you
   already run. `check.sh` verifies the block, not the whole file.

## Install

Give an implementing agent this prompt:

```
Read tools/usage-preflight/INSTALL.md and install as described. Show me diffs
before overwriting anything that already exists.
```

## Validate

Two layers:

- **Static** — `./check.sh` diffs the installed files against the latest payloads
  published on GitHub `main`. Four `OK` lines plus a populated-cache line means
  no drift. Pass `--local` to compare against this checkout's `files/` instead —
  offline, or when iterating on unpushed payload changes. The final cache line is
  a `NOTE`, not a failure: the cache is written at runtime by the status line, so
  a fresh install legitimately has none until an interactive session renders one.
- **Dynamic** — [SHAKEDOWN.md](SHAKEDOWN.md) exercises the full loop against
  synthetic caches, checking every verdict including the two that matter most
  (`unknown` and `stale`).

## Relationship to the delegation system

These are separate tools that compose. [delegation-system](../delegation-system/)
decides *how* to route expensive work; this decides *whether there's room to
start it*. The preflight gates the same operations delegation makes cheap to
launch — subagent fan-outs and `Workflow` calls — which is exactly why it wants
its own always-loaded CLAUDE.md line rather than living as a bullet inside the
delegation policy.

Install either without the other.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Always `unknown`, cache never appears | Status line not configured, or capture block not grafted in | Check `settings.json` `statusLine.command`; run `check.sh` |
| Always `unknown` in a `-p`/headless run | Status line doesn't run there by design | Expected. Prime the cache from an interactive session first |
| `unknown` in a brand-new session | Payload carries `rate_limits` only after the first API response | Expected. Resolves after one turn |
| Cache exists but `status` is `stale` | Older than `CLAUDE_USAGE_STALE_AFTER` (default 1800s) | Expected after idle time. Report the age; don't treat as current |
| Script exits 30 with a one-line JSON fallback | `jq` missing or the cache is malformed | Install `jq`; delete the cache and let the status line rewrite it |
| Verdicts look wrong for your plan | Thresholds are hardcoded | Edit the `sev(w; c)` calls in `check-usage-limit.sh`, then sync the payload |

## Design notes & maintenance

- Overrides: `CLAUDE_USAGE_CACHE` (cache path) and `CLAUDE_USAGE_STALE_AFTER`
  (freshness window, seconds) are honored by both the capture block and the
  reader, which is what makes the shakedown able to test against synthetic
  caches without touching the real one.
- The cache is written `chmod 600`. It holds usage percentages and reset
  timestamps — no credentials — but it describes account activity, so it stays
  out of version control and off shared paths.
- `.rate_limits` is an official status-line payload field, but the *set* of
  windows inside it has grown (the model-specific weekly windows arrived after
  the original five-hour/seven-day pair). Both the capture block and the reader
  store and evaluate the whole object rather than named fields, so a new window
  starts being enforced without a payload change.
- The reader emits valid JSON on every path, including the "jq itself failed"
  path. An agent that can't parse the output has no verdict at all, which is
  worse than a pessimistic one.
