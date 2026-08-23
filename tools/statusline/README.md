# Status Line

Five swappable Claude Code status lines on one fast core, plus a per-subagent line
for the agent panel and a preview harness that renders every variant against
synthetic session states so you can compare them without waiting for a live
session to reach an interesting state.

The point of the shared core: a status line re-renders on every turn end, compact,
permission change and vim toggle, debounced ~300ms, and **an in-flight run is
cancelled if it is re-triggered**. A slow script does not merely lag — it gets
killed and leaves a stale line on screen. So all five variants share one parse and
one git read, and the render path forks zero subshells.

## Variants

```
tuneup     Opus 5 (1M context) main │ $1.23 │ 5h:34% 7d:66%
           ████████░░░░░░░░░░░░ 42% │ dev/web-app

dense      Opus 5 1M · high · fast   web-app main ✓   PR #482 ✓   +1 dir
           ██████░░░░░░░░░░ 42% 428k/1M   $1.23   +120/-34   13m   $5.47/h   5h 34% ⟳2h   7d 66% ⟳50h

focus      ██████████░░░░░░░░░░░░░░  ✓ clear — context 42%, weekly 66%
           Opus 5 1M · high · main · PR #482 · $1.23 · 13m · dev/web-app

minimal    main · 42% · 7d 66% · $1.23

powerline   Opus 5 1M high ⚡  main  #482  42% 428k  $1.23  7d 66% 
```

| variant | lines | for |
|---|---|---|
| `tuneup` | 2 | a conservative default: model, branch + dirty counts, cost, usage windows, context bar |
| `dense` | 2 | everything the payload offers — worktree, agent name, PR review state, effort/fast/thinking, tokens against the real window size, burn rate, reset countdowns |
| `focus` | 2 | one prioritised headline at a time: limit critical → context critical → behind upstream → context warning → clear |
| `minimal` | 1 | branch, context %, weekly usage, spend. Nothing else |
| `powerline` | 1 | the same essentials as filled segments. Needs a Nerd Font |

Switch at any time — takes effect on the next render, no restart:

```sh
echo dense > ~/.claude/statusline/active
CC_STATUSLINE_VARIANT=focus     # env wins over the file, for one session
```

## The subagent line

`subagentStatusLine` is a separate setting that renders a line per row in the agent
panel. It receives a different payload — a `tasks[]` array — and expects **one JSON
object per line** back (`{"id": ..., "content": ...}`). Anything malformed is
silently dropped, and the whole batch is discarded on a non-zero exit, so
`subagent.sh` emits strict JSONL from a single `jq` pass.

Each task carries `tokenSamples`, a rolling window of its last 16 token counts,
which is what makes a trend possible:

```
▸ medium 24% 48k ▁▁▂▃▄▅▆█ 4h9m     climbing steadily
▸ high 85% 171k ▁▃▅▆▆▇▇█ 4h26m     85% of its window, flattening
✓ low 6% 12k 6h6m                  finished
◌                                   queued, nothing to say yet
```

The second row is the useful case: you can see an agent approaching its context
limit before its output starts degrading.

## Preview harness

```sh
cd ~/.claude/statusline
./preview.sh                    # every variant × every scenario
./preview.sh dense danger       # one cell
./preview.sh --bench            # 50 renders per variant
./preview.sh --list             # captured real sessions, newest first
./preview.sh --real             # newest capture
./preview.sh --real 3fa9 dense  # a specific session, by id prefix
```

Scenarios: `fresh` (new session, clean tree), `working` (dirty, PR open, fast mode),
`worktree` (linked worktree, subagent, changes requested, 200k window), `danger`
(context nearly full, weekly limit nearly gone), `nogit` (not a repo, no rate limits
yet).

To preview against real state, set `"CC_STATUSLINE_CAPTURE": "1"` in the `env` block
of settings.json and restart. Each session writes
`captures/<session_id>.json` plus a `.env` sidecar, mode 600, pruned after 7 days.
Keyed by session id deliberately: every concurrent session runs the same script, so
a single shared file records only whichever session rendered last — which on a
machine running dozens of sessions is a lottery. Note that `env` is injected at
session *start*, so removing the flag stops new sessions capturing while
already-running ones keep it until they restart.

## Usage-limit cache

The entry point persists the payload's `.rate_limits` to
`~/.claude/usage-limits.json` (atomic write, mode 600) before rendering. Writes only
happen when a real percentage is present, so a payload without `rate_limits` never
erases good data.

This exists because `rate_limits` is delivered *only* to the status line — nothing
else in a session can see it. If you run a preflight check that reads current usage
before expensive work, this file is how it gets the numbers. Two honest limits:
the reading is up to `refreshInterval` plus idle time old, so it is never "live";
and the status line does not run in `-p`/headless sessions, so those read whatever
the last interactive session cached.

If you have no such consumer, the file is written and harmlessly ignored.

### Relationship to `usage-preflight`

[usage-preflight](../usage-preflight/) is the consumer. It ships its own minimal
status line for people who do not have one, and its `check.sh` deliberately checks
for *the capture block wherever `.statusLine.command` points* rather than requiring
its file — so the two tools compose:

- Install this tool and `usage-preflight` together. Point `.statusLine.command` at
  `statusline.sh` from this tool, and skip `usage-preflight`'s status-line step
  (its "path A": graft into an existing status line — already done here).
- Both `check.sh` scripts then pass against the same install.

The capture block in `statusline.sh` is a **shared contract** and is byte-identical
to `usage-preflight/files/statusline-command.sh`'s. Reformat it and
`usage-preflight`'s drift check starts failing, even though the code still works.

## Payload reference

Verified against the Claude Code **2.1.238** binary. Fields marked ○ appear only in
some sessions.

| path | notes |
|---|---|
| `session_id`, `session_name`, `prompt_id`, `transcript_path`, `cwd`, `version` | |
| `model.id`, `model.display_name` | |
| `workspace.current_dir`, `.project_dir`, `.added_dirs[]` | |
| `workspace.repo` ○ | `{host, owner, name}`, parsed from the remote |
| `workspace.git_worktree` ○ | worktree name, string |
| `output_style.name` | |
| `cost.total_cost_usd`, `.total_duration_ms`, `.total_api_duration_ms`, `.total_lines_added`, `.total_lines_removed` | |
| `context_window.used_percentage`, `.remaining_percentage`, `.context_window_size`, `.total_input_tokens`, `.total_output_tokens`, `.current_usage` | `context_window_size` is how you tell a 1M window from 200k |
| `exceeds_200k_tokens` | |
| `fast_mode` ○ | |
| `effort.level` ○ | |
| `thinking.enabled` | |
| `vim.mode` ○ | pair with `hideVimModeIndicator` so it is not shown twice |
| `agent.name` ○ | set when the session is itself an agent |
| `remote.session_id` ○ | |
| `pr` ○ | `{number, url, review_state, kind}` |
| `worktree` ○ | `{name, path, branch, original_cwd, original_branch}` |
| `rate_limits` ○ | `five_hour`, `seven_day`, `seven_day_opus`, each `{used_percentage, resets_at}`. Subscribers only, and absent until the first API response of a session |

`context_window.used_percentage` counts input + cache tokens and **excludes output
tokens**, so the bar slightly understates real context pressure. That is Claude
Code's own figure and is reported as-is rather than silently "corrected".

Because `rate_limits` is absent before the first API response, `focus` renders
`weekly —` rather than `weekly 0%` in that window. "0%" would read as *nothing used
this week*, which is a reassuring claim the data does not support.

Subagent payload (`subagentStatusLine`): the base payload plus `columns` and
`tasks[]`, each task carrying `{id, name, type, status, description, label,
startTime, model, effort, contextWindowSize, tokenCount, tokenSamples[], cwd}`.

## Settings that interact with this

| setting | effect |
|---|---|
| `statusLine.refreshInterval` | seconds, min 1. A *backstop* — the command already re-runs on events |
| `statusLine.padding` | `0` removes the left indent |
| `hideVimModeIndicator` | hides the built-in `-- INSERT --` line; useful if your variant already shows `vim.mode` |
| `subagentStatusLine` | `{type, command}` only — no `refreshInterval`. 5s timeout |
| `disableAllHooks` | also disables status line execution |

## Requirements and constraints

- **`jq`** is required. Every accessor in the parse is `?`-guarded, so one changed
  field cannot blank the whole line on a future release — but jq itself is not
  optional.
- **bash 3.2 compatible.** macOS `/bin/bash` is 3.2.57 and `settings.json` invokes
  plain `bash`, so the payloads avoid `${var^^}`, associative arrays,
  `printf '%(%s)T'`, `EPOCHSECONDS`, `mapfile`, and negative substring offsets.
  This is the single easiest way to break this tool.
- **Budget: one `jq`, one `git status`, one `date` per render.** Git results are
  cached per repo for `CC_GIT_TTL` seconds (default 3) under
  `$TMPDIR/cc-statusline`, because the line re-renders far more often than a branch
  changes. Helpers assign to `REPLY` rather than printing, so callers avoid a
  `$(...)` fork; the render path forks zero subshells.
- **Width:** `dense` and `powerline` truncate to `$COLUMNS` when it is set,
  appending `…` plus a reset so no colour bleeds past the cut. Truncation counts
  characters, not columns, so a line containing `⚡` (and possibly `⑂ ✓ ✗ ⟳` in
  CJK-locale terminals) cuts a column or two early. Deliberately not solved — a
  wcwidth table is not worth the code here.

## Troubleshooting

**Nothing renders.** `jq` missing, or a syntax error under bash 3.2. Run
`bash -n ~/.claude/statusline/statusline.sh`, then feed it a payload by hand:
`./preview.sh dense working`.

**`statusline: unknown variant 'x'`.** `active` names a file that is not in
`variants/`. `ls ~/.claude/statusline/variants/`.

**The line is stale or flickers.** The harness cancels an in-flight render when
re-triggered. Check `./preview.sh --bench`, and confirm the git cache directory is
writable — an unwritable `$TMPDIR/cc-statusline` means a full `git status` on every
render.

**Colour bleeds past the right edge.** A variant emitted a colour without a reset.
Every segment must end in `${R}`.

**Subagent rows are blank.** The harness drops lines that are not valid
`{id, content}` JSON and discards the batch on a non-zero exit. Test it directly:
`bash ~/.claude/statusline/subagent.sh < a-captured-subagent-payload.json` and
validate each line with `jq -e`.

## Extending

A variant is one file defining `render()`, which prints one or two lines and
nothing else. Every payload field is already in a `CC_*` variable and every helper
assigns to `REPLY`:

```sh
render() {
  cc_int "$CC_CTX_PCT"; pct=$REPLY
  cc_bar_c "$GRN" "$pct" 20
  printf '%s %s%%' "$REPLY" "$pct"
}
```

Drop it in `variants/`, `echo <name> > active`, and it is live on the next render.
Add a matching scenario to `preview.sh` if it keys off a field the existing
scenarios do not exercise.
