---
name: artifact
description: Delegate substantial reports, dashboards, comparisons, timelines, walkthroughs, and other information-rich visual presentations to Claude Sonnet and publish them as creator-private Claude Code Artifacts. Use when the user invokes $artifact, asks for a Claude-hosted visual or report, wants a shareable interactive page, or provides an existing claude.ai/code/artifact URL to update.
---

# Artifact

Create or update a private Claude Code Artifact with Claude Sonnet. Let Claude choose the visual treatment unless the user supplies design constraints.

## Workflow

1. Establish the artifact's audience, decision or question, and source material from the request and current context. Ask only when a consequential product choice is genuinely missing.
2. Select only the files needed for the artifact. Never sweep a home directory or repository. Exclude `.env` files, credentials, keys, unrelated attachments, and material the user did not authorize for Claude.ai.
3. Write a concise work order to a temporary Markdown file. Include:
   - goal and audience;
   - absolute paths to selected sources;
   - factual and confidentiality constraints;
   - the requested artifact URL when updating an existing artifact;
   - instructions to distinguish observations from interpretations;
   - permission for Claude to choose layout, charts, interactions, typography, and palette;
   - a requirement to publish creator-private and return the URL.
4. Run the bundled launcher in a PTY from a workspace the user placed in scope:

```bash
~/.codex/skills/artifact/scripts/claude-artifact.exp \
  --repo /absolute/path/to/workspace \
  --prompt-file /absolute/path/to/work-order.md
```

Set `tty: true` on the command invocation. Run outside Codex's sandbox when needed so Claude can access its normal subscription authentication and publish to Claude.ai. The launcher always selects `--model sonnet`, uses Claude auto mode, disables automatic browser opening, extracts the Artifact URL, and exits the interactive session after publication.

5. If Claude presents its workspace trust screen, inspect the path. Re-run with `--trust-workspace` only when it is the user-selected workspace already in scope. Never auto-trust an unfamiliar directory.
6. Treat the run as successful only when the launcher prints `ARTIFACT_URL=https://claude.ai/code/artifact/...`. Return that link with a one-sentence description. Do not duplicate the whole report unless asked.

## Important behavior

- Do not use `claude -p` for publication. Print mode does not expose the `Artifact` tool in the tested Claude Code configuration.
- Do not add or invoke a Claude-side skill. Interactive Claude Code already loads its built-in `artifact-design` skill.
- Keep new artifacts creator-private. Do not use the page's sharing controls or grant organization access unless the user separately requests that external write.
- For updates, include the exact existing Artifact URL and tell Claude to revise and republish that artifact rather than create a new one.
- Artifact pages are single-file HTML or Markdown. They cannot use a backend or make runtime external requests.
- If publication fails, report the launcher's error and preserve any local HTML or Markdown source Claude names. Never claim that a local file is hosted.

Read [references/discovery.md](references/discovery.md) only when diagnosing invocation or publication failures.
