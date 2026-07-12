# Artifact — Live Shakedown

This test publishes a small creator-private page to the signed-in user's Claude
account and then updates it in place. It does not share the page with anyone.

Give a fresh Codex session this prompt:

```text
Use $artifact for this live shakedown.

Create a creator-private Claude Artifact for an operations lead from this
synthetic data:

| Week | Tickets | Median response | Satisfaction |
|---|---:|---:|---:|
| May 4 | 820 | 5.8h | 84% |
| May 11 | 910 | 6.4h | 82% |
| May 18 | 1,040 | 7.1h | 79% |
| May 25 | 960 | 4.9h | 87% |

Let Claude Sonnet choose the visual presentation. The page should distinguish
observed facts from interpretation and suggest two questions to investigate.
Return the confirmed Artifact URL.

After creation, update that same Artifact by adding the subtitle "Shakedown
verified" and republish to the same URL. Confirm that the URL did not change and
that it remains creator-private. Clean up temporary local work-order files, but
do not delete the hosted Artifact.
```

## Pass criteria

- The run explicitly uses Claude Sonnet through the bundled PTY launcher.
- Claude's built-in artifact design behavior chooses the presentation without a
  second Claude-side skill.
- Creation returns `https://claude.ai/code/artifact/...` only after the launcher
  observes a confirmed `Published` result.
- The update observes `Updated`, returns the same URL, and does not mistake the
  URL echoed in the update prompt for success.
- The Artifact remains creator-private and no sharing controls are used.
- Temporary local work-order files are removed.

## Failure modes

| Symptom | Likely cause | First move |
|---|---|---|
| `Artifact` is unavailable | Account, organization policy, or surface does not expose it | Confirm interactive Claude Code access and review the Artifact requirements |
| Launcher reports workspace trust failure | Claude has not trusted the selected workspace | Inspect the path, then rerun with `--trust-workspace` only if it is in scope |
| Claude exits without a URL | Publication failed or only a local page was created | Preserve the named local HTML/Markdown file and inspect Claude's error |
| Drift check fails | Installed skill differs from the canonical payload | Review `diff -ru`, then reinstall from `files/` if appropriate |
