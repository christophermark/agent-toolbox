# Discovery findings

Tested with Claude Code 2.1.207 and the `sonnet` model alias on July 11, 2026.
Permission and authentication diagnostics were repeated with Claude Code 2.1.212
on July 16, 2026.

- `claude -p` worked for ordinary inference but its initialization tool list omitted `Artifact`. Plain prompts, structured work orders, a temporary Claude-side skill, and explicit `--allowedTools Artifact` could not publish.
- Interactive Claude Code exposed `Artifact`, automatically loaded the built-in `artifact-design` skill, generated a self-contained HTML page, and published it successfully.
- `--permission-mode auto` allowed both the design skill and creator-private publication without a manual confirmation.
- `CLAUDE_CODE_ARTIFACT_AUTO_OPEN=0` prevents publication from opening a browser automatically.
- The reliable integration boundary is therefore an interactive PTY using Sonnet, not print mode and not an extra Claude-side skill.
- Codex must invoke the launcher with escalated sandbox permissions because the
  Claude process needs outbound network access. A persistent Codex prefix rule
  should match only the launcher's resolved absolute path.
- `--setting-sources user` prevents unrelated project/local Claude settings,
  including malformed permission rules, from changing the publication session.
- `claude auth status` is the decisive authentication preflight. A live test from
  Codex cannot publish while it reports `loggedIn: false`; on macOS, use
  `claude doctor` to distinguish missing login from Keychain access failures.
- The July 16 live publication attempt reached the interactive launcher but was
  stopped before model execution after diagnostics confirmed `loggedIn: false`.
  The new launcher preflight now reports that condition immediately with exit 6
  instead of waiting for a model stream.

When this behavior changes in a future Claude Code release, repeat a minimal interactive/print-mode preflight before changing the launcher.
