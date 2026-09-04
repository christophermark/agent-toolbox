# PR Writing

A Claude Code skill that writes pull request titles and descriptions for fast
human review. It exists because agent-created PRs arrive in volume, and the
descriptions that come with them tend to be long, confident, and loosely tied to
the diff. Reviewers then read the code cold, which is the slow path.

The skill inverts that. The visible description must fit on one screen and lead
with why the change exists, then where the risk is, then how it was verified.
Anything exhaustive (full change lists, implementation notes, raw test output,
provenance for an agent-to-agent handoff) goes into a collapsed `<details>`
section at the end, where a human can ignore it and a follow-up agent can find it.

The rules are distilled from Google's engineering practices, GitHub's own PR
guidance, Chris Beams on commit messages, and 2026 studies of agent-authored
PRs, which found description-to-diff drift to be the most common failure. The
skill therefore requires writing from the final diff, not from memory of the
session.

## When it applies

Creating a PR, drafting or editing a PR title or body, or preparing a work order
for a delegate (such as Codex) that will draft one. Natural-language requests
like "open a PR for this" trigger it.

## Install

Give an implementing agent this prompt:

```text
Read tools/pr-writing/INSTALL.md and install as described. Show me diffs before
overwriting anything that already exists.
```

## Use

Invoke it directly:

```text
/pr-writing Draft the title and description for the current branch against main.
```

Or rewrite an existing one:

```text
/pr-writing Rewrite the description of PR #142 so a reviewer can triage it in
30 seconds. Keep the agent notes but fold them.
```

## What a result looks like

```markdown
Fix duplicate order emails when payment webhook retries

Stripe retries webhooks on timeout, and we sent a confirmation email per
delivery. This dedupes on the webhook event ID so each order emails once.

**Risk:** touches the payment webhook path (`webhooks/stripe.py`); the other
6 files are test fixtures. No schema change.
**Verified:** `pytest tests/webhooks/ -k retry` (12 passed); replayed a real
duplicate event in staging, one email sent.

<details>
<summary>Agent handoff notes</summary>

- Full change list, decisions, raw test output, links to plans or threads.
</details>
```

## Validate

`./check.sh` detects drift between the canonical payload and
`~/.claude/skills/pr-writing/`.

## Requirements

- Claude Code with personal skills support (`~/.claude/skills/`).
- No network access, hooks, or settings changes.

## Related

If you keep personal writing rules (for example a `~/.claude/WRITING.md` that
your `CLAUDE.md` imports), the skill tells the agent to include them alongside
its own rules when delegating PR drafting. It works without them.
