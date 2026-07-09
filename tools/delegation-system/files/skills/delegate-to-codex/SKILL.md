---
name: delegate-to-codex
description: Use when delegating work to the Codex CLI from Claude Code — very large read-heavy investigations, bulk patch drafting, bounded mechanical implementation, or a cross-model second opinion on a design or diff. Claude keeps design, review, verification, and all git operations.
---

# Delegate To Codex

Use this skill only from Claude Code. Never ask Codex to delegate back to Claude or
to spawn its own delegation chains.

## When Codex beats a Claude subagent

- The job would burn a very large amount of context on file reading or repetitive
  analysis (whole-module audits, sweeping migrations) — Codex runs it fully out of
  band with zero token cost to the Claude session.
- You want a genuine second opinion from a different model family on a design,
  a diff, or a suspected bug.
- Bulk patch drafting across many files where Claude will review and apply.

Prefer Claude subagents when the task needs session context, MCP tools, or tight
interaction with the orchestrator. Keep in Claude entirely: judgment, architecture,
secrets, commits/pushes/releases, destructive operations, final review.

## Modes

- `research` (default) — read-only sandbox. Investigation, audits, second opinions.
- `patch` — read-only sandbox. Codex returns a unified diff plus verification notes;
  Claude reviews it like a pull request, then applies it with its own editing tools
  (or `git apply` on a saved patch file).
- `write` — workspace-write sandbox. Bounded implementation with a frozen approach
  and narrow file scope only. Requires the target to be a git repository so the diff
  is reviewable and reversible. Claude reviews the full diff afterward. Pass
  `--network` only if the task genuinely needs outbound network (e.g. installing
  a dependency to run tests).

## Work order contract

Codex starts with zero session context. Write the prompt to a file first, including:
goal and success criteria; absolute repo path; relevant files/symbols/logs/commands
already known; constraints and non-goals (including files not to touch); expected
proof (exact test command, or "no commands needed"); and the required output shape.

## Invocation

Always use the wrapper (never hand-write `codex exec`):

```bash
~/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh \
  --repo /absolute/path/to/repo \
  --mode research|patch|write \
  --prompt-file /path/to/work-order.md \
  --output /path/to/result.md \
  [--model MODEL] [--effort minimal|low|medium|high|xhigh] [--network]
```

The model and reasoning effort default to whatever `~/.codex/config.toml` sets;
override with `--model`/`--effort` only when the task warrants it. Codex runs take
minutes: run the wrapper as a background Bash task and keep working; read the
output file when it completes.
Never use `--yolo`, `--dangerously-bypass-approvals-and-sandbox`, or
`danger-full-access`.

## Review and integrate

1. Read the output file; verify important claims against the source before relying
   on them.
2. Patches get inspected like a pull request before applying with normal Claude
   editing tools. Write-mode diffs get fully reviewed and re-verified (use the
   `verifier` subagent for substantial changes).
3. One precise follow-up work order is fine; after two poor rounds, stop delegating
   and take over.
4. Close out as Claude: summarize what changed, cite files, report verification.
