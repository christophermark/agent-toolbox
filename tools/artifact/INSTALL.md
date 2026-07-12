# Artifact — Install Instructions

**Audience:** an implementing agent running on any machine with zero prior
context on this tool.

**Goal:** install the Codex `artifact` skill so Codex can ask Claude Sonnet to
create or update creator-private hosted Claude Code Artifacts.

Read this whole file before writing anything. Canonical file contents live under
`files/`; copy them byte-for-byte rather than retyping or paraphrasing them.

## Preflight

1. Run `claude --version` and confirm Claude Code is installed. The payload was
   tested with v2.1.207; on another version, continue but report the difference.
2. Run `claude auth status`. Ordinary subscription inference must work from the
   user's normal terminal environment. Artifact publication additionally depends
   on the account's plan and organization policy.
3. Confirm `expect` exists at `/usr/bin/expect`. If it does not, install the
   platform's Expect package or adapt only the launcher's shebang to the verified
   binary path and report that portability change.
4. Confirm `~/.codex/skills/` exists or create it.
5. If an interactive Claude session later says that `Artifact` is unavailable,
   check the account, organization policy, and Claude Code version. Do not replace
   the publisher with `claude -p`; print mode did not expose the tool during
   discovery.

## File map

Copy this directory byte-for-byte:

| Payload | Target |
|---|---|
| `files/skills/artifact/` | `~/.codex/skills/artifact/` |

After copying, run:

```bash
chmod +x ~/.codex/skills/artifact/scripts/claude-artifact.exp
```

## Idempotency

Never silently clobber an existing skill. If `~/.codex/skills/artifact/` already
exists, compare it with the payload first:

```bash
diff -ru ~/.codex/skills/artifact files/skills/artifact
```

If there is drift, show the diff and ask before replacing the installed copy,
unless the user explicitly authorized an autonomous synchronization. In that
case, copy the canonical payload and report the replaced files afterward.

The repository payload is the source of truth. Do not merge machine-local edits
back into it implicitly.

## Verify installation

1. Run the Codex skill validator when available:

   ```bash
   python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
     ~/.codex/skills/artifact
   ```

   Expected: `Skill is valid!`. If that system validator is not installed, verify
   that `SKILL.md` has only `name` and `description` in its YAML frontmatter.
2. Confirm the launcher is executable:

   ```bash
   test -x ~/.codex/skills/artifact/scripts/claude-artifact.exp && echo OK
   ```

3. Run the launcher with no arguments. It must print usage and exit `2`.
4. Run `tools/artifact/check.sh`. Every payload line must end in `OK`.
5. Start a new Codex session so the new skill catalog is loaded, then optionally
   run the live workflow in `SHAKEDOWN.md`.

## Updating

Pull the latest repository version, inspect `git diff` or the release change,
copy `files/skills/artifact/` over the installed skill, restore the launcher's
executable bit, rerun `check.sh`, and start a new Codex session if skill metadata
changed.
