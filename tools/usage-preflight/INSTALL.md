# Usage-limit preflight — Install Instructions

**Audience:** an implementing agent running on any machine with zero prior
context on this tool.

**Goal:** give the agent driving a Claude Code session a way to read remaining
subscription usage before starting expensive work, and a policy for what each
reading means.

Read this whole file before writing anything. Canonical file contents live under
`files/`; copy them byte-for-byte rather than retyping or paraphrasing them.

## Preflight

1. Run `claude --version` and confirm Claude Code is installed. The payload was
   tested with v2.1.220; on another version, continue but report the difference.
2. Run `jq --version`. Both the capture block and the reader require `jq`. If it
   is missing, stop and tell the user to install it — without `jq` the tool
   reports `unknown` forever.
3. Confirm `~/.claude/` exists. Create `~/.claude/skills/` if it does not exist.
4. Read `~/.claude/settings.json` and note whether `statusLine` is already
   configured, and if so, what script it runs. This determines which of the two
   status-line paths below applies. If the file has no `statusLine` key, path B
   applies.

## File map

| Payload | Target | Notes |
|---|---|---|
| `files/skills/usage-preflight/SKILL.md` | `~/.claude/skills/usage-preflight/SKILL.md` | Byte-for-byte |
| `files/check-usage-limit.sh` | `~/.claude/check-usage-limit.sh` | Byte-for-byte, then `chmod +x` |
| `files/claude-md/usage-preflight.md` | Appended as a section of `~/.claude/CLAUDE.md` | See "CLAUDE.md section" below |
| `files/statusline-command.sh` | `~/.claude/statusline-command.sh` **or** grafted into the existing status line | See "Status line" below |

After copying:

```bash
chmod +x ~/.claude/check-usage-limit.sh
```

## Status line

The status line is the only place Claude Code surfaces `.rate_limits`, so the
capture block is what makes the whole tool work. It is also a personal display
preference, so there are two paths. Pick based on preflight step 4.

### Path A — a status line already exists

Do **not** overwrite it. Graft in the capture block: copy the block from
`files/statusline-command.sh` that runs from the line

```
# ── usage-limit capture ──────────────────────────────────────────────────────
```

through the last line before `# ── colours`, and insert it into the existing
script **immediately after** the line that reads the payload into `input`
(typically `input=$(cat)`). The block must come before anything that consumes or
overwrites `$input`.

Copy the block verbatim, comments included. `check.sh` verifies it as a literal
substring, and the atomic-write and non-erasing behavior described in the
comments is load-bearing — a reformatted or "simplified" copy is how good cached
data gets wiped by a payload that lacks `rate_limits`.

If the existing status line does not read stdin into a variable at all, report
that to the user rather than guessing where the block goes.

### Path B — no status line configured

Copy `files/statusline-command.sh` to `~/.claude/statusline-command.sh`,
`chmod +x` it, and register it in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh",
  "refreshInterval": 30
}
```

Resolve `~` to the actual home directory if the running Claude Code version does
not expand it in this field — verify by rendering a status line, not by
assumption. Do not hardcode another user's home directory.

Note that this payload also displays model, git state, session cost, and a
context bar. That is a preference, not a requirement; the user may prefer path A
against a status line of their own design.

## CLAUDE.md section

`files/claude-md/usage-preflight.md` is a complete `## Usage-limit preflight`
section. Append it to `~/.claude/CLAUDE.md`, separated from the previous section
by exactly one blank line. Create the file if it does not exist.

If a `## Usage-limit preflight` section is already present, do not append a
second one — diff the existing section against the payload and follow the
idempotency rule below.

The section is what makes the agent reach for the skill unprompted. Installing
the skill without it means the tool only runs when a human remembers to ask,
which defeats the purpose.

## Idempotency

Never silently clobber existing files. For each target that already exists,
compare it with the payload first:

```bash
diff -u files/check-usage-limit.sh ~/.claude/check-usage-limit.sh
diff -u files/skills/usage-preflight/SKILL.md ~/.claude/skills/usage-preflight/SKILL.md
```

If there is drift, show the diff and ask before replacing the installed copy,
unless the user explicitly authorized an autonomous synchronization. In that
case, copy the canonical payload and report the replaced files afterward.

The repository payload is the source of truth. Do not merge machine-local edits
back into it implicitly.

## Verify installation

1. Run `tools/usage-preflight/check.sh --local`. Expected: `OK` on all four
   payload lines. The trailing cache line may read `NOTE ... not populated yet`
   on a fresh install — that is expected until an interactive session renders a
   status line.
2. Confirm the reader is executable and emits JSON:

   ```bash
   ~/.claude/check-usage-limit.sh; echo "exit $?"
   ```

   Expected: a single JSON object on stdout in every case. On a machine with no
   cache yet, `status` is `unknown` and the exit code is 30 — that is correct
   behavior, not a failure.
3. Confirm the unknown path never reports zero:

   ```bash
   CLAUDE_USAGE_CACHE=/nonexistent ~/.claude/check-usage-limit.sh | jq '.status, .five_hour_used_percentage'
   ```

   Expected: `"unknown"` and `null`. If it prints `0`, stop and report it — that
   is the failure mode the whole tool exists to prevent.
4. Start an interactive Claude Code session, let the status line render, then
   confirm the cache populated:

   ```bash
   jq '.captured_at_iso, (.rate_limits | keys)' ~/.claude/usage-limits.json
   ```

5. Re-run `check.sh --local`; the cache line should now read `OK ... (populated)`.
6. Confirm the skill is discoverable: in a new session, `/usage-preflight` should
   appear in the skill list. If it does not, restart Claude Code once — skills
   added mid-session are not picked up until the next start.
7. Optionally run the live workflow in `SHAKEDOWN.md`.

## Updating

Pull the latest repository version, inspect `git diff` or the release change,
copy the changed payloads over the installed files, restore the executable bit
on `check-usage-limit.sh`, re-sync the `## Usage-limit preflight` section of
`~/.claude/CLAUDE.md` if it changed, rerun `check.sh`, and start a new session if
skill metadata changed.
