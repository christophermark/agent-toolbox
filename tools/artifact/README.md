# Artifact

A Codex skill that delegates substantial reports, dashboards, comparisons,
timelines, walkthroughs, and other visual explanations to Claude Sonnet, then
returns a creator-private page hosted at `claude.ai/code/artifact/...`.

Claude chooses the presentation itself unless the request includes design
constraints. The skill screens source files before delegation, keeps new
artifacts private to their creator, and can update an existing Artifact in place.

## Why the launcher is interactive

Discovery against Claude Code 2.1.207 found that `claude -p` supports ordinary
inference but does not expose the `Artifact` publishing tool. Interactive Claude
Code does expose it, automatically loads its built-in `artifact-design` skill,
and permits creator-private publication through auto mode. The included Expect
launcher provides the required PTY, pins Claude to Sonnet, detects confirmed
publication, extracts the URL, and exits cleanly.

No additional Claude-side skill is installed.

## Install

Give an implementing agent this prompt:

```text
Read tools/artifact/INSTALL.md and install as described. Show me diffs before
overwriting anything that already exists.
```

## Use

Start a new Codex session after first installation, then invoke the skill directly:

```text
$artifact Turn these support metrics into a decision-ready visual report for the
operations lead. Let Claude choose the presentation.
```

Natural-language requests for a Claude-hosted report or visualization can also
trigger it. To revise an existing page, include its Artifact URL.

## Validate

- `./check.sh` detects drift between the canonical payload and
  `~/.codex/skills/artifact/`.
- [SHAKEDOWN.md](SHAKEDOWN.md) contains an agent-runnable create-and-update test
  for the live hosted workflow.

## Requirements

- Codex with personal skills support.
- Claude Code with the `Artifact` tool enabled for the signed-in account.
- A Claude plan and organization policy that permit Claude Code Artifacts.
- `expect` on `PATH` (the payload uses `/usr/bin/expect`).

## Privacy

New pages remain creator-private. The skill never operates Claude's sharing
controls unless the user separately requests that external write. Only files
explicitly needed for the report should be sent to Claude.ai.

## Sources

- [Claude Code Artifact documentation](https://code.claude.com/docs/en/artifacts)
- [Claude Help Center: artifacts](https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them)
