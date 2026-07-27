# Usage-limit Preflight Shakedown

A live, end-to-end validation that an installed preflight actually works: the
capture block persists real data, every verdict is reachable, and the two
failure statuses (`unknown`, `stale`) report honestly instead of collapsing to
"0% used".

Use `check.sh` to answer "are the right files installed?" Use this shakedown to
answer "does the policy behave?" Run it after first install, after upgrading
Claude Code, and any time the status-line payload schema might have changed. It
takes about five minutes and costs almost nothing — no subagents, no model calls
beyond the session you run it in.

Everything below drives synthetic caches through `CLAUDE_USAGE_CACHE`. The real
`~/.claude/usage-limits.json` is never written, so a failed shakedown cannot
corrupt your live reading.

## How to run

Paste the prompt into any Claude Code session that has the tool installed.

## The prompt

```
Usage-limit preflight shakedown. Work in a scratch directory; set
CLAUDE_USAGE_CACHE to a file inside it on every invocation so the real
~/.claude/usage-limits.json is never touched. Report the JSON status and the
exit code for each step.

1. Live capture: read ~/.claude/usage-limits.json (do not modify it) and confirm
   it has captured_at, captured_at_iso, and a rate_limits object with at least
   one window carrying a numeric used_percentage. Report how old captured_at is.
2. ok: write a synthetic cache with captured_at = now, five_hour 10%,
   seven_day 20%. Expect status "ok", exit 0.
3. warning: five_hour 80%. Expect status "warning", exit 10.
4. critical: five_hour 90%. Expect status "critical", exit 20.
5. Weekly thresholds: five_hour 5%, seven_day 92%. Expect "warning" (weekly
   thresholds are 90/95, not 75/85). Then seven_day_opus 97% with everything
   else low — expect "critical". Confirm the worst window wins, not the first.
6. unknown — missing cache: point CLAUDE_USAGE_CACHE at a nonexistent path.
   Expect status "unknown", exit 30, and five_hour_used_percentage null.
   Explicitly confirm it is null and NOT 0.
7. unknown — malformed cache: write "{not json" to the cache. Expect status
   "unknown", exit 30, and valid JSON still on stdout.
8. unknown — empty windows: write a well-formed cache whose rate_limits is {}.
   Expect "unknown", not "ok".
9. stale: write a cache with five_hour 90% and captured_at set 3600 seconds in
   the past. Expect status "stale", exit 31, stale_policy_status "critical",
   and a non-null age_seconds. Confirm the critical reading survives in
   stale_policy_status rather than being lost behind the stale status.
10. Freshness override: same cache, but CLAUDE_USAGE_STALE_AFTER=7200. Expect
    the status to return to "critical" (exit 20) — the data is no longer stale
    under the wider window.
11. Non-numeric override guard: same cache with CLAUDE_USAGE_STALE_AFTER=abc.
    Expect it to fall back to the 1800s default and report "stale", not crash.
12. Skill wiring: confirm ~/.claude/skills/usage-preflight/SKILL.md exists and
    that ~/.claude/CLAUDE.md contains a "## Usage-limit preflight" section
    naming the skill.

Finish with a scorecard table: step | expected status/exit | actual | pass/fail.
Then delete the scratch directory. Do not modify ~/.claude/usage-limits.json,
~/.claude/settings.json, or the status line at any point.
```

## Pass criteria

- **Twelve steps green**, each matching its expected `status` *and* exit code.
  The exit code matters independently: a hook or script may branch on it without
  parsing the JSON.
- **Step 1 proves the loop closes.** A populated real cache with a recent
  `captured_at` is the only evidence that the capture block is actually wired
  into the status line that runs. Steps 2–11 test policy against synthetic data
  and would all pass with the capture block missing entirely.
- **Never zero.** Steps 6–8 must report `null` percentages with status
  `unknown`. A `0` anywhere in those three steps is a hard fail — that is the
  precise failure this tool exists to prevent.
- **Valid JSON on every path**, including the malformed-cache step.
- **Stale keeps its verdict.** Step 9's `stale_policy_status` must be
  `critical`. A `stale` status that discards the underlying reading is a fail.
- **No side effects.** The real cache, `settings.json`, and the status line are
  unchanged; the scratch directory is gone.

## Failure modes to flag

| Symptom | Likely cause | First move |
|---|---|---|
| Step 1 finds no cache, or one hours old | Capture block not grafted into the status line that actually runs | Run `check.sh`; verify `statusLine.command` points at the script holding the block |
| Steps 6–8 report `0` instead of `null` | Reader payload drifted from canonical | `check.sh`; restore `files/check-usage-limit.sh` |
| Every step reports `unknown` | `jq` missing | Install `jq`; the reader has no fallback parser by design |
| Step 5 picks the first window instead of the worst | `max_by(rank)` selection broken | Compare against the payload; this is a reader bug, not a config issue |
| Step 9 loses the critical reading | `stale_policy_status` not populated | Restore the payload |
| Real cache populated but always stale in your workflow | Long idle gaps between renders | Expected. The skill already requires reporting age; consider a lower `refreshInterval` |
| Step 12 passes but the agent never runs the preflight on its own | Skill installed, CLAUDE.md section missing or reworded | Re-sync the section from `files/claude-md/usage-preflight.md` |

## Reference run

First executed 2026-07-27 against the packaged payloads (Claude Code v2.1.220,
`jq` 1.8.1, macOS): twelve steps green. Live cache was 2s old with `five_hour`
and `seven_day` populated — the model-specific weekly windows were absent from
the real payload, so step 5b exercised `seven_day_opus` synthetically and
confirmed the worst window wins rather than the first. Steps 6–8 returned `null`
percentages under status `unknown` with no `0` anywhere, including the
malformed-cache path, which still emitted parseable JSON. Step 9 kept
`stale_policy_status: "critical"` alongside `age_seconds: 3600`; widening
`CLAUDE_USAGE_STALE_AFTER` to 7200 returned it to `critical`/20 and a
non-numeric override fell back to the 1800s default rather than crashing. No
side effects — the real cache's `captured_at_iso` was unchanged at the end.
