# Simply — Install Instructions

**Audience:** an implementing agent running on any machine with zero prior
context on this tool.

**Goal:** install the Claude Code `simply` skill so a session can draft, revise,
and audit documentation against condensed Google Developer Documentation Style
Guide guidance.

Read this whole file before writing anything. Canonical file contents live under
`files/`; copy them byte-for-byte rather than retyping or paraphrasing them.

## Preflight

1. Run `claude --version` and confirm Claude Code is installed. The payload was
   verified with v2.1.238; on another version, continue but report the
   difference.
2. Confirm `~/.claude/skills/` exists or create it. Personal skills live there;
   do not install this into a repository's `.claude/skills/` unless the user asks
   for a project-scoped copy.
3. Check for a name collision. If `~/.claude/skills/simply/` already exists,
   follow **Idempotency** below before copying anything.
4. Check whether the user's own instructions already mandate a documentation
   style. If `~/.claude/CLAUDE.md` or a project `CLAUDE.md` sets writing rules
   that conflict with this skill, report the conflict. The skill's own precedence
   order puts the user's request and project style above its guidance, so no file
   edit is needed — but the user should know both exist.

No permission rules, hooks, or settings changes are required. The skill reads
only its own files and, at the user's request, public style-guide pages over the
network.

## File map

Copy this directory byte-for-byte:

| Payload | Target |
|---|---|
| `files/skills/simply/` | `~/.claude/skills/simply/` |

No file needs an executable bit.

`LICENSE` and `NOTICE.md` are part of the payload, not repository bookkeeping.
The skill is third-party MIT-licensed work (copyright (c) 2026 Daniel Green) that
condenses CC BY 4.0 Google material. Copy both files with the rest and do not
strip them.

## Idempotency

Never silently clobber an existing skill. If `~/.claude/skills/simply/` already
exists, compare it with the payload first:

```bash
diff -ru ~/.claude/skills/simply files/skills/simply
```

If there is drift, show the diff and ask before replacing the installed copy,
unless the user explicitly authorized an autonomous synchronization. In that
case, copy the canonical payload and report the replaced files afterward.

The repository payload is the source of truth. Do not merge machine-local edits
back into it implicitly. If the installed copy holds an improvement worth
keeping, say so and let the user decide whether it belongs upstream.

## Verify installation

1. Confirm the frontmatter survived the copy. `SKILL.md` must open with a YAML
   block containing only `name: simply` and a `description:` line:

   ```bash
   head -4 ~/.claude/skills/simply/SKILL.md
   ```

2. Confirm the references resolve. `SKILL.md` links to
   `references/guide.md` and `references/official-index.md`; both must exist:

   ```bash
   ls ~/.claude/skills/simply/references/
   ```

3. Run `tools/simply/check.sh`. Every payload line must end in `OK`, and the
   script must exit `0`.
4. Start a new Claude Code session so the skill catalog reloads, then run
   `/simply` and confirm the skill loads instead of reporting an unknown command.
5. Optionally run the live test in `SHAKEDOWN.md`.

## Updating

Pull the latest repository version, inspect `git diff` for payload changes, copy
`files/skills/simply/` over the installed skill, rerun `check.sh`, and start a
new Claude Code session if `SKILL.md` frontmatter changed — the catalog only
rereads `name` and `description` at session start.
