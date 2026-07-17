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
2. Run `claude auth status` from the same environment that will launch the
   Artifact skill. Continue only when it reports `"loggedIn": true` and exits 0.
   Artifact publication additionally depends on the account's plan and
   organization policy.
3. Confirm `expect` exists at `/usr/bin/expect`. If it does not, install the
   platform's Expect package or adapt only the launcher's shebang to the verified
   binary path and report that portability change.
4. Confirm `~/.codex/skills/` exists or create it.
5. If an interactive Claude session later says that `Artifact` is unavailable,
   check the account, organization policy, and Claude Code version. Do not replace
   the publisher with `claude -p`; print mode did not expose the tool during
   discovery.

## Configure permissions

### Codex launcher approval

Artifact publication requires network access and normal Claude subscription
authentication, so Codex must run the launcher outside its command sandbox. Add
one persistent allow rule for the resolved launcher path to
`~/.codex/rules/default.rules`:

```starlark
prefix_rule(
    pattern = ["/absolute/path/to/.codex/skills/artifact/scripts/claude-artifact.exp"],
    decision = "allow",
)
```

Resolve the actual absolute path on the target machine; Starlark does not expand
`~` or shell variables. If the rule file or its parent directory does not exist,
create it. Do not add a broad rule for `claude`, `expect`, `sh`, or a shell
interpreter. The skill invokes the launcher directly with
`sandbox_permissions: "require_escalated"`, and the exact-path rule prevents a
repeated approval prompt.

This approval runs the launcher outside Codex's filesystem and network sandbox,
not merely with network access. Keep the rule limited to the launcher, review
the selected workspace and sources, and retain Claude's own permission controls.

### Claude settings hygiene

Run `claude doctor` and fix settings validation warnings before the live
shakedown. Current Claude Code versions use `Edit(path)` rules for file edits;
obsolete `Write(path)` rules produce warnings and do not match file permission
checks. Replace equivalent `Write(...)` entries with `Edit(...)`, then rerun
`claude doctor`.

The launcher loads user settings but deliberately excludes project and local
Claude settings. This prevents unrelated repository hooks, MCP servers, or
malformed project permission rules from interfering with Artifact publication.
User settings and managed organization policy still apply.

### Claude authentication and macOS Keychain

If `claude auth status` reports `"loggedIn": false`, authenticate in a normal
interactive terminal before retrying Codex:

```bash
claude auth login
claude auth status
```

On macOS, if `claude doctor` reports that the login Keychain is locked or not
writable, unlock it without placing the password in shell history, then retry
the login:

```bash
security unlock-keychain ~/Library/Keychains/login.keychain-db
claude auth login
```

Restart Codex after authentication so a newly launched process can read the
updated credential. Never paste OAuth tokens into a prompt, work order, Git
repository, Codex rule, or settings file.

For CI or another automated environment that cannot use the login Keychain, run
`claude setup-token` interactively. It prints a long-lived subscription OAuth
token without saving it. Store that token in the automation platform's secret
store and inject it as `CLAUDE_CODE_OAUTH_TOKEN` only into the launcher process.
Do not commit it or print it in validation output.

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
4. With valid paths but no usable Claude login, the launcher must fail fast with
   the authentication setup message and exit `6` rather than waiting on a model
   request.
5. Run `tools/artifact/check.sh`. Every payload line must end in `OK`.
6. Confirm `~/.codex/rules/default.rules` contains an `allow` prefix rule for the
   launcher's resolved absolute path and no broader shell or `claude` rule was
   added for this installation.
7. Start a new Codex session so the new skill catalog is loaded, then optionally
   run the live workflow in `SHAKEDOWN.md`.

## Updating

Pull the latest repository version, inspect `git diff` or the release change,
copy `files/skills/artifact/` over the installed skill, restore the launcher's
executable bit, rerun `check.sh`, and start a new Codex session if skill metadata
changed.
