# Delegation System Shakedown

A live, end-to-end validation that an installed delegation system actually
works: correct model routing, real parallelism, briefs instead of dumps, and a
verifier — not the orchestrator — certifying the result.

Use `check.sh` to answer "are the right files installed?" Use this shakedown to
answer "does the system behave?" Run it after first install, after upgrading
Claude Code or the Codex CLI, or whenever routing feels off. It takes about ten
minutes and costs a handful of Sonnet subagent runs plus one Codex run.

## How to run

Paste the prompt below into a Claude Code session running on a premium
main-loop model (the orchestrator). Then watch the subagent panel while it
runs — the panel is ground truth for which model each lane actually used; the
scorecard's model claims should match it.

## The prompt

```
Delegation system shakedown. Orchestrate only — do all work below through
delegation, no main-thread fixes. Set up: have the implementer subagent create
a throwaway git repo at /tmp/delegation-shakedown containing README.md,
src/stats.js with exported functions sum(xs) and average(xs) — where average
has a subtle planted bug (divides by xs.length + 1) — and test.js that checks
both with node:assert (run via `node test.js`). If global git config forces
commit signing and no key is available, the implementer should set
commit.gpgsign=false locally in the throwaway repo only. Confirm the tests
fail before proceeding — the broken state is the fixture.

Then exercise each lane. Sequencing rule: every read/audit lane (1–3) must
observe the buggy state before any lane changes it, so hold lane 4 until 1–3
have read the file.

1. Codex (background): write a work order asking for a bug audit of
   src/stats.js, run the delegate-to-codex skill in research mode as a
   background task, and continue immediately.
2. Explore: ask the Explore subagent where average is defined and what calls
   it, expecting path:line evidence.
3. researcher: ask the researcher subagent to root-cause why `node test.js`
   fails, returning path:line evidence and the offending expression.
4. implementer: after 1–3 have read the buggy file, have the implementer
   subagent fix the bug and make `node test.js` pass, staying inside
   src/stats.js. Use a fresh implementer instance, not the one that planted
   the bug.
5. verifier: have the verifier subagent independently confirm the fix against
   the spec "average(xs) returns sum/length; all tests pass", running the
   tests itself. The verifier certifies — the orchestrator must not
   self-certify.
6. Integrate the Codex result from step 1 and note whether it found the
   xs.length + 1 bug independently.

Finish with a scorecard table: lane | agent and model actually used |
pass/fail | one-line evidence. Then clean up /tmp/delegation-shakedown.
```

## Pass criteria

- **Six lanes green**, each returning a short evidence-backed brief with
  `path:line` references — never raw file dumps or process narration.
- **Routing:** Explore, researcher, implementer, and verifier all ran on
  **Sonnet** (confirm in the subagent panel, not just the scorecard). Nothing
  delegated ran on the premium session model.
- **Codex lane:** ran as a background task (lanes 2–3 executed while it
  worked), found the planted bug independently, and its task output ends with
  the wrapper's provenance line — `codex-delegate: mode=research model=…
  effort=…` — naming the model that actually ran.
- **Separation of duties:** the orchestrator wrote work orders, sequenced,
  integrated, and reported; a fresh implementer fixed; the **verifier**
  certified.
- **Cleanup:** the fixture repo is gone at the end.

## Failure modes to flag

| Symptom | Likely cause | First move |
|---|---|---|
| A lane ran on the wrong model | Agent frontmatter drifted, or `CLAUDE_CODE_SUBAGENT_MODEL` is set | Run `check.sh`; check the env var |
| Codex lane blocked the orchestrator | Wrapper not run as a background task | Re-read the skill's invocation section |
| A subagent went idle without delivering its brief | Finished without messaging the orchestrator | Nudge via SendMessage; if recurring, confirm the agent prompt ends with its report-back rule (`check.sh` catches drift) |
| Fixture commit failed with a GPG error | Global `commit.gpgsign=true`, no key | The prompt already tells the implementer to disable signing locally |
| A lane returned a raw dump | Work order missing a return-shape contract | Tighten the work order; this is an orchestrator bug, not an agent bug |
| The audit lanes saw an already-fixed file | Fix dispatched before read lanes finished | Re-run honoring the sequencing rule |

## Reference run

First executed 2026-07-09 (Claude Code v2.1.205, Codex CLI 0.142.5): six lanes
green — fixture at a single commit, Codex (gpt-5.5, config default) found the
planted bug with the same failing input and fix as the researcher, the
implementer's diff was one line, and the verifier's independent PASS included
an out-of-suite spot check. One wrinkle observed — Explore going idle without
reporting — became this tool's report-back rule and the SendMessage row above.
