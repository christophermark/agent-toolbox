# Status Line — Live Shakedown

Static checks catch drift; they do not catch a status line that renders wrong, or
slowly, or that silently stops feeding the usage cache. This exercises the
installed tool end to end.

Give a fresh Claude Code session this prompt, from inside a git repository with at
least one uncommitted change:

```text
Shake down the installed status line at ~/.claude/statusline. Report a scorecard
against the pass criteria below. Do not fix anything you find — report it.

1. SYNTAX UNDER THE REAL INTERPRETER
   /bin/bash --version, then `bash -n` every .sh under ~/.claude/statusline
   (including variants/). Report the bash version.
   PASS: no syntax errors. Note whether bash is 3.x — that is expected, and the
   scripts must work under it.

2. EVERY VARIANT × EVERY SCENARIO
   cd ~/.claude/statusline && ./preview.sh
   PASS: 25 cells (5 variants × 5 scenarios). Every cell renders. No jq errors, no
   empty output, no literal "null" anywhere.

3. THRESHOLD COLOURS ACTUALLY CHANGE
   ./preview.sh focus fresh, then ./preview.sh focus danger
   PASS: `fresh` shows a green all-clear headline; `danger` shows a red weekly-limit
   headline naming a reset time. If both look the same, severity logic is broken.

4. MISSING IS NOT ZERO
   Feed a payload with no rate_limits:
     jq 'del(.rate_limits)' <a captured or synthetic payload> \
       | CC_STATUSLINE_VARIANT=focus bash ~/.claude/statusline/statusline.sh
   PASS: the headline reads "weekly —", NOT "weekly 0%". Absent data must not
   render as a reassuring number.

5. CLONE DISAMBIGUATION
   If two clones of the same remote exist, render dense with cwd set to each:
     jq --arg c <clone path> '.cwd=$c' <payload> \
       | CC_STATUSLINE_VARIANT=dense bash ~/.claude/statusline/statusline.sh
   PASS: the first line names each CHECKOUT DIRECTORY, and the two differ. If both
   show the same name, it regressed to workspace.repo.name (from the remote URL).
   Also render from a deep subdirectory of a repo.
   PASS: still shows the repo root's directory name, not the subdirectory's.

6. WIDTH TRUNCATION AND NO COLOUR BLEED
   COLUMNS=60 ./preview.sh dense worktree, then COLUMNS=200 for the same cell.
   PASS: at 60 the lines are cut and end in "…"; at 200 they are not cut. Pipe the
   truncated output through `od -c | tail -3` and confirm it ends in an escape
   reset (ESC [ 0 m) with nothing after it.

7. GIT DEGRADATION
   Render with cwd set to a directory that is NOT a git repo (e.g. $HOME).
   PASS: renders without a branch segment and without errors.

8. PERFORMANCE AND THE FORK BUDGET
   ./preview.sh --bench
   Then count external processes for one render:
     PS4='+' bash -x ~/.claude/statusline/statusline.sh < payload 2>&1 | grep -cE '^\+ (jq|git|date|cksum|cut|find)'
   PASS: at most one jq, one git status, one date per render. The render path must
   contain no $(...) in any variant: grep '\$(' ~/.claude/statusline/variants/*.sh
   returns nothing. Report the bench table, but do not treat wall-clock as
   authoritative if the shell is sandboxed — report the process counts as the real
   signal.

9. USAGE CACHE CONTRACT
   Render once with a payload containing rate_limits, pointing the cache at a temp
   file: CLAUDE_USAGE_CACHE=/tmp/shakedown-usage.json
   PASS: the file exists, is mode 600, and contains a rate_limits object with
   captured_at_iso. Then render again with rate_limits deleted from the payload.
   PASS: the file still holds the OLD good data — a payload without rate_limits
   must never erase the cache.

10. SUBAGENT LINE EMITS VALID JSONL (skip if subagentStatusLine is not installed)
    Feed a payload with a tasks[] array to ~/.claude/statusline/subagent.sh and
    validate every line:
      | jq -e 'if (keys|sort) == ["content","id"] then true else error("bad") end'
    PASS: every line validates. A task with fewer than 2 distinct tokenSamples must
    render no sparkline rather than a flat misleading one. A queued task with no
    model or window must render without errors.

11. VARIANT SWITCHING
    Note the current contents of ~/.claude/statusline/active. Set it to each
    variant in turn and render. Restore the original value when done.
    PASS: each switch takes effect on the next render. An `active` file naming a
    nonexistent variant prints "statusline: unknown variant" and exits 0 — it must
    never crash the line.

12. DRIFT CHECK (if the agent-toolbox repo is on this machine)
    tools/statusline/check.sh
    PASS: exit 0.

Report a table: check number, PASS/FAIL, and the evidence. For any FAIL, quote the
actual output. State explicitly which files you touched and that you restored them.
```

## What a good result looks like

All twelve PASS, with the bench table and process counts included as evidence
rather than a bare assertion. Checks 4, 5, and 9 are the ones that catch real
regressions — they encode decisions that are easy to "simplify" away later:

- **4** — absent rate-limit data is not zero usage.
- **5** — the checkout directory, not the remote's repo name.
- **9** — a payload without `rate_limits` must not clobber a good cache.
