# Status Line — Install Instructions

**Audience:** an implementing agent running on any machine with zero prior context
on this tool.

**Goal:** install a swappable Claude Code status line (five variants on one shared
core), optionally a per-subagent line for the agent panel, and wire both into
`~/.claude/settings.json`.

Read this whole file before writing anything. Canonical file contents live under
`files/`; copy them byte-for-byte rather than retyping or paraphrasing them. These
are shell scripts written against a deliberately old bash — retyping them is how
they get broken.

## Preflight

1. Run `claude --version`. The payloads were verified against **2.1.238**, and the
   payload field names were extracted from that binary. On another version,
   continue but report the difference; if fields have moved, every accessor is
   `?`-guarded so the line degrades rather than blanking.
2. Run `jq --version`. **`jq` is required** — the whole payload is parsed in one jq
   call. If it is missing, stop and report; do not attempt a jq-free fallback.
3. Run `/bin/bash --version`. On macOS this is **3.2.57**, and `settings.json`
   invokes plain `bash`, so that is the interpreter these payloads must satisfy.
   This is expected, not a problem to fix. Do **not** "modernise" the scripts:
   `${var^^}`, associative arrays, `printf '%(%s)T'`, `EPOCHSECONDS`, `mapfile`, and
   negative substring offsets all fail silently or loudly under 3.2.
4. Confirm `git` is available. It is used read-only and the status line degrades
   gracefully outside a repo.
5. Note whether `~/.claude/statusline/` already exists. If it does, treat every
   target below as an existing file: show a diff and ask before overwriting.
6. Check whether the [usage-preflight](../usage-preflight/) tool is installed
   (`~/.claude/check-usage-limit.sh` exists, or `.statusLine.command` points at
   `~/.claude/statusline-command.sh`). If so, this tool **supersedes** its status
   line: point `.statusLine.command` at `statusline.sh` from this tool and leave
   everything else of usage-preflight's alone. Do not delete
   `~/.claude/statusline-command.sh` without asking — the user may want to fall
   back to it. Afterwards, `tools/usage-preflight/check.sh` must still pass; it
   follows `.statusLine.command` and looks for the capture block, which
   `statusline.sh` carries verbatim.

## File map

Create `~/.claude/statusline/` and copy:

| payload | target |
|---|---|
| `files/statusline/core.sh` | `~/.claude/statusline/core.sh` |
| `files/statusline/statusline.sh` | `~/.claude/statusline/statusline.sh` |
| `files/statusline/subagent.sh` | `~/.claude/statusline/subagent.sh` |
| `files/statusline/preview.sh` | `~/.claude/statusline/preview.sh` |
| `files/statusline/variants/tuneup.sh` | `~/.claude/statusline/variants/tuneup.sh` |
| `files/statusline/variants/dense.sh` | `~/.claude/statusline/variants/dense.sh` |
| `files/statusline/variants/focus.sh` | `~/.claude/statusline/variants/focus.sh` |
| `files/statusline/variants/minimal.sh` | `~/.claude/statusline/variants/minimal.sh` |
| `files/statusline/variants/powerline.sh` | `~/.claude/statusline/variants/powerline.sh` |

Then:

```sh
chmod +x ~/.claude/statusline/statusline.sh \
         ~/.claude/statusline/subagent.sh \
         ~/.claude/statusline/preview.sh
```

`core.sh` and the variants are sourced, not executed, and do not need the bit.

## Choose a variant

Write one word to `~/.claude/statusline/active`:

```sh
echo tuneup > ~/.claude/statusline/active
```

Use `tuneup` unless the user asked for something else — it is the conservative
two-line default. The others are `dense`, `focus`, `minimal`, `powerline`. If
`active` is missing the entry point falls back to `tuneup` anyway.

Do not pick `powerline` unless you have confirmed the user's terminal font is a
Nerd Font or Powerline-patched; its segment separators render as tofu otherwise.

## Wire up settings.json

Edit `~/.claude/settings.json` (create it as `{}` if absent). **Read the existing
file and merge** — do not overwrite it; it holds the user's permissions, model, and
plugin configuration.

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline/statusline.sh",
    "refreshInterval": 30
  },
  "subagentStatusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline/subagent.sh"
  }
}
```

Notes:

- If `~` in the command does not resolve on the target platform, substitute the
  absolute home path. Verify by rendering (below) rather than assuming.
- `refreshInterval` is **seconds**, minimum 1, and is only a backstop — the command
  already re-runs on turn end, compact, permission change, and vim toggle.
- `subagentStatusLine` is optional. Install it only if the user runs subagents;
  it takes no `refreshInterval` and has a 5s timeout.
- If a `statusLine` entry already exists, show the user the current value and the
  replacement, and preserve their existing `refreshInterval` and `padding` if set.
- Back up the file first (`cp settings.json settings.json.bak-$(date +%Y%m%d-%H%M%S)`)
  and confirm the result still parses: `jq -e . ~/.claude/settings.json`.

Settings take effect on the next render; a restart is not required.

## Idempotency

Re-running this install must be safe:

- Copying payloads over identical files is a no-op. Copying over *modified* files
  needs a diff shown to the user first — they may have customised a variant.
- Never overwrite `~/.claude/statusline/active`; it is user state. Write it only if
  absent.
- Never remove `~/.claude/statusline/captures/` or `~/.claude/usage-limits.json`.
- The settings edit must be a merge, every time.

## Verify

1. **Syntax under the real interpreter:**

   ```sh
   for f in ~/.claude/statusline/*.sh ~/.claude/statusline/variants/*.sh; do
     bash -n "$f" || echo "FAIL $f"
   done
   ```

   Expect no output.

2. **Every variant renders against every scenario:**

   ```sh
   cd ~/.claude/statusline && ./preview.sh
   ```

   Expect 25 rendered cells (5 variants × 5 scenarios), no `jq` errors, no empty
   renders. A blank render means jq failed — check `jq --version`.

3. **One cell in detail**, to confirm colour and layout:

   ```sh
   ./preview.sh dense danger
   ```

   Expect two lines: an identity line, and a line with a context bar, `91%`,
   `918k/1M`, a dollar figure, a burn rate, and red `5h`/`7d` percentages with
   `⟳` countdowns.

4. **The subagent line emits valid JSONL** (only if you installed it). Feed it a
   payload with a `tasks[]` array and confirm every output line validates:

   ```sh
   bash ~/.claude/statusline/subagent.sh < payload.json \
     | jq -e 'if (keys|sort) == ["content","id"] then true else error("bad") end'
   ```

   Malformed lines are silently dropped by the harness, so this check matters.

5. **The usage cache is written.** Render once with a payload containing
   `rate_limits`, then confirm `~/.claude/usage-limits.json` exists with mode 600
   and holds a `rate_limits` object. If the user has a preflight script that reads
   current usage, this file is its only source — `rate_limits` is delivered to the
   status line and nowhere else.

6. **Drift check**, if this repo is available on the machine:

   ```sh
   tools/statusline/check.sh
   ```

   Expect exit 0.

7. **Live**: the user's next turn should render the new line. If it does not,
   check `jq -e .statusLine ~/.claude/settings.json` and run `claude doctor` for
   settings validation warnings.

## Report back

Tell the user:

- which variant is active, and the one-line command to switch (`echo dense >
  ~/.claude/statusline/active`);
- whether the subagent line was installed;
- that `~/.claude/usage-limits.json` is now being written, and what reads it (or
  that nothing does yet, in which case it is harmless);
- any diff you showed and what they chose;
- the backup filename for `settings.json`.
