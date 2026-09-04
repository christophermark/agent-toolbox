---
name: pr-writing
description: Write or rewrite a pull request title and description optimized for fast human review. Use whenever creating a PR, drafting or editing a PR title/body, or preparing a PR-drafting work order for a delegate (e.g. Codex) — hand the delegate these rules verbatim, plus any personal writing rules (e.g. ~/.claude/WRITING.md) if present.
---

# PR titles and descriptions for fast human review

Goal: a reviewer reading only the title and the visible description can answer,
in 30 seconds: what does this do, why, how risky is it, and where should I look
hardest. Everything else is secondary.

## Title

- Imperative mood. Test: "If merged, this PR will ___" must read as a sentence
  ("Fix Swiss tax rounding for 2026 rates", not "Fixed…"/"Fixing…"/"Tax updates").
- Specific enough to be findable in a search a year from now. Never "Fix bug",
  "Cleanup", "Phase 1", "Misc changes".
- Aim for ≤ 70 characters; no trailing period.
- Follow the repo's existing prefix convention (ticket IDs, `feat:`/`fix:`) if
  one is in use; don't introduce one.
- If you can't summarize the PR in one specific line, the PR is probably too
  big — say so to the user instead of writing a vague title.

## Visible description (the human part)

Hard limit: fits on one screen without scrolling (~15 lines / ~150 words).
For a small PR, 2–4 sentences of plain prose with no headers is ideal.
The diff already shows *what* changed — the description's job is what the diff
can't show. In order:

1. **Why, then what** (1–3 sentences): the problem or motivation, and what is
   different after this merges. This is the only mandatory part.
2. **Risk / where to look** (1–3 lines): trust boundaries touched (auth, money,
   migrations, prod data, new dependencies), behavior changes, and which files
   carry the real logic vs. mechanical churn. If genuinely low risk, one line
   saying so and why ("docs only", "behind flag X, off by default").
3. **How it was verified** (1–3 lines): actual commands or steps and their
   outcomes. "CI is green" alone doesn't count. Before/after screenshots for
   UI changes.
4. **Open questions** (optional): anything you're unsure about. An honest gap
   directs review attention and builds trust; never leave this falsely absent
   when uncertainty exists.

### Never

- Narrate changes file-by-file or restate the diff.
- Leave empty template boilerplate or "N/A" sections — delete them.
- Pad with headers, emoji, or bullet storms; small change, small description.
- Claim anything the diff doesn't actually do. Write the description from the
  **final diff** (`git diff <base>...HEAD`), not from memory of the work —
  description-to-diff drift is the #1 measured failure of agent-written PRs.

## Collapsed agent/audit section (optional, always last)

Exhaustive material goes behind a fold, after the human section:

```markdown
<details>
<summary>Agent handoff notes</summary>

- Full change list: ...
- Implementation notes / decisions: ...
- Raw test output: ...
- Plan / thread / session links: ...
</details>
```

- The blank line after `</summary>` is required — without it GitHub renders the
  inner markdown as raw text.
- Belongs inside: exhaustive change lists, implementation decisions, raw test
  output, provenance, links to plans or delegate threads.
- Never put anything a human reviewer *needs* only inside the fold.
- Skip the section entirely if there's no genuinely useful handoff material.

## Procedure

1. Read the final diff against the merge base — not your memory of the session.
2. Write the title.
3. Write the visible section; check every sentence against the diff.
4. Add the `<details>` fold only if there is handoff material a reviewer would otherwise lack.
5. If the repo has a PR template, honor its required sections briefly and
   delete the rest — a tailored short description beats a filled-in form.
6. When delegating the drafting (e.g. to Codex), include this file's rules in
   the work order, plus any personal writing rules the user keeps (e.g.
   `~/.claude/WRITING.md`) if present, and review the draft against them before
   posting.

## Example

> **Title:** Fix duplicate order emails when payment webhook retries
>
> Stripe retries webhooks on timeout, and we sent a confirmation email per
> delivery. This dedupes on the webhook event ID so each order emails once.
>
> **Risk:** touches the payment webhook path (`webhooks/stripe.py`); the other
> 6 files are test fixtures. No schema change — dedupe uses the existing
> `processed_events` table.
> **Verified:** `pytest tests/webhooks/ -k retry` (12 passed); replayed a real
> duplicate event in staging — one email sent.
>
> <details><summary>Agent handoff notes</summary>…</details>
