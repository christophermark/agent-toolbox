# Simply

A Claude Code skill that drafts, revises, and audits reader-first technical and
product documentation. It puts the result first, names the actor, puts conditions
before instructions, and strips throat-clearing — while preserving the source's
facts, hedges, quotations, and technical tokens.

The guidance is condensed from the [Google Developer Documentation Style
Guide](https://developers.google.com/style). The skill loads its detailed
reference only when the artifact needs it (procedures, code, UI labels, tables,
images, accessibility, or a line-level audit), and consults the official pages
only when a task turns on a specialized rule or asks for explicit compliance.

An explicit precedence order keeps it from overriding you: your request and the
destination's requirements come first, then source fidelity, then project style,
then this skill's guidance.

## When it applies

Developer docs, procedures, release notes, technical explanations, help-center
content, and UI copy — anywhere clarity, source fidelity, accessibility, or
global readability matters.

It does not apply itself to marketing, legal, academic, fictional, or personal
writing. Ask for it by name when you want that style there anyway.

## Install

Give an implementing agent this prompt:

```text
Read tools/simply/INSTALL.md and install as described. Show me diffs before
overwriting anything that already exists.
```

## Use

Invoke it directly:

```text
/simply Rewrite docs/deploy.md for an on-call engineer who has never run this
procedure. Keep every command and version pin exact.
```

Ask for an audit when you want findings instead of a rewrite:

```text
/simply Audit this release note. Report problems in priority order; don't rewrite it.
```

Documentation work described in natural language can also trigger it.

## Validate

- `./check.sh` detects drift between the canonical payload and
  `~/.claude/skills/simply/`.
- [SHAKEDOWN.md](SHAKEDOWN.md) contains an agent-runnable test that checks the
  skill triggers, improves prose, and preserves facts and hedging.

## Requirements

- Claude Code with personal skills support (`~/.claude/skills/`).
- No network access is required. Web access only widens step 11 of the skill,
  which opens official style pages for specialized rules.

## Attribution

The payload under `files/skills/simply/` is third-party work by Daniel Green,
redistributed under the MIT license it ships with. `LICENSE` is reproduced
verbatim, and both `LICENSE` and `NOTICE.md` travel with the skill — keep them in
place.

The MIT license permits modification, so this copy renames the skill's title from
`NBJ Write Clearly` to `Simply` to match its directory and invocation name. The
guidance and references are otherwise untouched, and `NOTICE.md` records the
change.

The skill is unofficial and is not endorsed by Google. `NOTICE.md` also carries
the Google Style Guide's CC BY 4.0 terms and the review date of the condensed
guidance.
