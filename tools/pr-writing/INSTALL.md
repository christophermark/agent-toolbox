# PR Writing — Install Instructions

**Audience:** an implementing agent running on any machine with zero prior
context on this tool.

**Goal:** install the Claude Code `pr-writing` skill so a session writes PR
titles and descriptions a human can triage in 30 seconds, with any agent
handoff material folded into a collapsed section at the end.

Read this whole file before writing anything. The canonical file lives under
`files/`; copy it byte-for-byte rather than retyping or paraphrasing it.

## Preflight

1. Run `claude --version` and confirm Claude Code is installed. The payload was
   verified with v2.1.238; on another version, continue but report the
   difference.
2. Confirm `~/.claude/skills/` exists or create it. Personal skills live there;
   do not install this into a repository's `.claude/skills/` unless the user asks
   for a project-scoped copy.
3. Check for a name collision. If `~/.claude/skills/pr-writing/` already exists,
   follow **Idempotency** below before copying anything.
4. Check whether the user already routes PR drafting somewhere else (for
   example a `CLAUDE.md` rule that delegates PR writing to Codex). No file edit
   is needed: the skill is written to be handed to a delegate verbatim. Tell the
   user both exist so they can wire the delegate's work order to include it.

No permission rules, hooks, or settings changes are required.

## File map

Copy this directory byte-for-byte:

| Payload | Target |
|---|---|
| `files/skills/pr-writing/` | `~/.claude/skills/pr-writing/` |

No file needs an executable bit.

## Idempotency

Never silently clobber an existing skill. If `~/.claude/skills/pr-writing/`
already exists, compare it with the payload first:

```bash
diff -ru ~/.claude/skills/pr-writing files/skills/pr-writing
```

If there is drift, show the diff and ask before replacing the installed copy,
unless the user explicitly authorized an autonomous synchronization. In that
case, copy the canonical payload and report the replaced files afterward.

The repository payload is the source of truth. Do not merge machine-local edits
back into it implicitly. If the installed copy holds an improvement worth
keeping, say so and let the user decide whether it belongs upstream.

## Verify installation

1. Confirm the frontmatter survived the copy. `SKILL.md` must open with a YAML
   block containing only `name: pr-writing` and a `description:` line:

   ```bash
   head -4 ~/.claude/skills/pr-writing/SKILL.md
   ```

2. Run `tools/pr-writing/check.sh`. Every payload line must end in `OK`, and the
   script must exit `0`.
3. Start a new Claude Code session so the skill catalog reloads, then run
   `/pr-writing` and confirm the skill loads instead of reporting an unknown
   command.

## Updating

Pull the latest repository version, inspect `git diff` for payload changes, copy
`files/skills/pr-writing/` over the installed skill, rerun `check.sh`, and start
a new Claude Code session if `SKILL.md` frontmatter changed. The catalog only
rereads `name` and `description` at session start.
