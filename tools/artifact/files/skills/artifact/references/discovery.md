# Discovery findings

Tested with Claude Code 2.1.207 and the `sonnet` model alias on July 11, 2026.

- `claude -p` worked for ordinary inference but its initialization tool list omitted `Artifact`. Plain prompts, structured work orders, a temporary Claude-side skill, and explicit `--allowedTools Artifact` could not publish.
- Interactive Claude Code exposed `Artifact`, automatically loaded the built-in `artifact-design` skill, generated a self-contained HTML page, and published it successfully.
- `--permission-mode auto` allowed both the design skill and creator-private publication without a manual confirmation.
- `CLAUDE_CODE_ARTIFACT_AUTO_OPEN=0` prevents publication from opening a browser automatically.
- The reliable integration boundary is therefore an interactive PTY using Sonnet, not print mode and not an extra Claude-side skill.

When this behavior changes in a future Claude Code release, repeat a minimal interactive/print-mode preflight before changing the launcher.
