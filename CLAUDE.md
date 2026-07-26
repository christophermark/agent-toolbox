# agent-toolbox

Portable tooling for Claude Code setups. Each tool lives in `tools/<name>/` and is
self-contained: an `INSTALL.md` written for an implementing agent, canonical file
payloads under `files/`, and a `check.sh` that diffs installed copies against them.

## Conventions that aren't obvious from the code

- **`files/` is canonical; `~/.claude/` is the installed copy.** Never edit an
  installed copy without syncing the change back here (and vice versa). Run the
  tool's `check.sh` after either — every line should end `OK`.
- **Dated verification claims are load-bearing.** README `Provenance`/`Sources`
  sections state *when* facts were re-verified and against *which* versions
  (`claude --version`, `codex --version`, live doc fetches). Never bump a date or
  version string without actually re-verifying — a bumped date on an unchecked
  claim is worse than a stale one.
- **Docs and changelogs can disagree; live behavior wins.** Example: on
  2026-07-25 the sub-agents reference page still said nested spawning was off by
  default, while the v2.1.219 changelog (and an empirical test — spawn a subagent,
  check whether it holds the Agent tool) showed it re-enabled to depth 3. When
  sources conflict, resolve empirically on the installed version and record which
  source was stale.
- **Researcher memory is deliberately untracked.** Per-project findings live in
  `tools/<name>/.claude/agent-memory-local/researcher/` and are gitignored
  (`**/.claude/agent-memory-local/`) so codebase-specific "facts" never leak
  between projects. Durable, repo-relevant conclusions belong in the tool's
  README, not only in memory.
- **Commits explain the why.** Summary line in the imperative; body records what
  was verified or what motivated the change, since the READMEs make dated claims
  that later sessions will audit.
