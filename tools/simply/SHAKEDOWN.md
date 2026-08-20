# Simply — Shakedown

**Audience:** an agent in a fresh Claude Code session, run after installation or
after any payload change.

**Goal:** prove the installed skill triggers on documentation work, improves the
prose, and — the part that regresses silently — preserves facts, hedging, and
technical tokens.

Run all four probes, then report the scorecard. Do not fix the skill mid-run;
record what happened.

## Probe 1 — the skill triggers

Prompt: `/simply` with this input:

```text
Rewrite for a developer following this the first time:

"Before you can be in a position to deploy, it should be noted that the
migration must be run. Running `pnpm db:migrate --env=staging` is what is done
by the operator. It might fail if the pool is saturated."
```

Pass criteria:

- The skill loads (its guidance appears in the session, not an unknown-command
  error).
- The result puts the condition before the instruction, names the actor, and uses
  an imperative.
- `pnpm db:migrate --env=staging` appears character-for-character.
- The hedge survives: the failure stays possible (*might*, *can*), not certain
  and not deleted.

## Probe 2 — audit means audit

Prompt: `/simply Audit this, don't rewrite it:` followed by any two-paragraph
release note containing a superlative claim.

Pass criteria:

- The output is findings in priority order, not a revision.
- The superlative is flagged as an unsupported claim.

## Probe 3 — no invention

Prompt: `/simply Tighten this: "The cache reduces load. We measured a
improvement in p99 latency during the June test."`

Pass criteria:

- The typo (`a improvement`) is fixed.
- No number, percentage, or measurement is invented to fill the gap.
- If the missing figure is raised at all, it is raised as a question or a gap,
  not filled in.

## Probe 4 — scope restraint

Prompt: `/simply` with two sentences of deliberately personal or fictional prose
(for example, a line of dialogue with a distinctive voice).

Pass criteria:

- The skill either declines to impose documentation conventions or applies them
  only where the user asked, and it does not flatten the voice.

## Scorecard

Report one line per probe: `PASS` / `FAIL` plus the specific observation that
decided it. For any `FAIL`, quote the offending output and name the `SKILL.md`
rule that should have prevented it — that pairing is what makes the failure
actionable upstream.
