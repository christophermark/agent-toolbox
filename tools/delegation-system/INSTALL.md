# Delegation System — Install Instructions

**Audience:** an implementing agent (Claude Code or similar) running on any machine, with zero prior context on this tool.
**Goal:** set up a delegation system for Claude Code where a premium main-loop model (Fable 5 / Opus) acts as orchestrator and routes work to cheaper Claude subagents and to the Codex CLI — expanding the main thread's capability by keeping bulk tool output out of its context window, not by dumbing it down.

Read this whole file before writing anything. All target file contents live in `files/` in this tool directory — copy them byte-for-byte; never retype or paraphrase them. Follow the idempotency rules below.

## Preflight

Before writing anything:

1. `claude --version` — this system assumes Claude Code **v2.1.198+** (background-by-default subagents, Explore model inheritance, `memory`/`effort` frontmatter). On older versions everything still works; note any gaps to the user instead of failing.
2. `command -v codex && codex --version` — if the Codex CLI is absent, install the agents and CLAUDE.md section anyway and skip the Codex bridge files, telling the user the Codex lane needs `npm i -g @openai/codex` (or `brew install --cask codex`) plus `codex login` to activate. Do not fail the whole setup.
3. If Codex is present, check auth with `codex login status` (expect `Logged in using ChatGPT` or an API-key message; if not logged in, tell the user to run `codex login` — suggest typing `! codex login` in the Claude prompt since it's interactive).
4. Verify the wrapper's flags against the installed Codex: `codex exec --help` must list `--cd`, `--sandbox` (values `read-only`, `workspace-write`, `danger-full-access`), `--output-last-message`, `-c key=value`, and `--skip-git-repo-check`. Config keys used (confirmed in the official config reference, re-verified against Codex CLI v0.145.0 on 2026-07-25 at https://learn.chatgpt.com/docs/config-file/config-reference — developers.openai.com/codex/config-reference now redirects here): `approval_policy` (values `untrusted | on-request | never`), `model_reasoning_effort` (values `minimal | low | medium | high | xhigh`), `sandbox_workspace_write.network_access` (bool). Adapt the wrapper if the installed version differs, and note what you changed.
5. Create directories as needed: `~/.claude/agents/`, `~/.claude/skills/delegate-to-codex/scripts/`. If `~/.claude/agents/` did not exist before the current session, remind the user to restart Claude Code once at the end (the directory watcher only covers directories that existed at session start).
6. Confirm `CLAUDE_CODE_SUBAGENT_MODEL` is unset (`echo "${CLAUDE_CODE_SUBAGENT_MODEL:-unset}"` and check `env` in `~/.claude/settings.json`) — if set, it overrides all per-agent model routing.

## File map

Copy each payload byte-for-byte to its target path. `chmod +x` the wrapper script after copying it.

| Payload (in `files/`) | Target path |
|---|---|
| `files/agents/explore.md` | `~/.claude/agents/explore.md` |
| `files/agents/researcher.md` | `~/.claude/agents/researcher.md` |
| `files/agents/implementer.md` | `~/.claude/agents/implementer.md` |
| `files/agents/verifier.md` | `~/.claude/agents/verifier.md` |
| `files/skills/delegate-to-codex/SKILL.md` | `~/.claude/skills/delegate-to-codex/SKILL.md` |
| `files/skills/delegate-to-codex/scripts/codex-delegate.sh` | `~/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh` (copy byte-for-byte, then `chmod +x`) |
| `files/claude-md/delegation.md` | append as a section of `~/.claude/CLAUDE.md`, preserving existing content |

## Idempotency

**Never clobber existing config.** For each target file that already exists: show a diff of what you'd change and ask before overwriting (unless the user has already told you to proceed autonomously — then upgrade and report the diff afterward). For `~/.claude/CLAUDE.md`, append/replace only the `## Delegation` section (the contents of `files/claude-md/delegation.md`), preserving everything else. If a previous version of this system is present (e.g. agents named `researcher`/`implementer` from an earlier setup), treat this tool as the newer revision.

## Verify the installation

Steps 1–5 are mechanical; 6–7 are live end-to-end tests.

1. `ls ~/.claude/agents/` → expect `explore.md`, `implementer.md`, `researcher.md`, `verifier.md`.
2. Confirm the `## Delegation` section is present in `~/.claude/CLAUDE.md` and no pre-existing content was lost.
3. `test -x ~/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh && echo ok`
4. `bash -n ~/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh && echo "syntax OK"`, then run the script with no arguments and confirm it prints usage and exits `2`.
5. Confirm `CLAUDE_CODE_SUBAGENT_MODEL` is unset (Preflight item 6).
6. **Codex smoke test** (skip if Codex isn't installed). Build a tiny throwaway repo and delegate a trivial research question through the wrapper:

   ```bash
   SMOKE=$(mktemp -d)/smoke-repo && mkdir -p "$SMOKE/src" && cd "$SMOKE"
   git init -q
   printf '# Smoke Repo\n' > README.md
   printf 'export function add(a, b) {\n  return a + b;\n}\n' > src/math.js
   git add -A && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init

   cat > /tmp/smoke-work-order.md <<'EOF'
   Goal: Answer two questions about this repository. Success = both answered with exact paths.

   1. What files exist at the top level and in src/?
   2. What function(s) does src/math.js export, with what signature?

   Constraints: read-only investigation, no commands needed beyond listing/reading files.
   Output shape: two numbered answers, one line each.
   EOF

   ~/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh \
     --repo "$SMOKE" --mode research --effort low \
     --prompt-file /tmp/smoke-work-order.md --output /tmp/codex-smoke-result.md \
   && cat /tmp/codex-smoke-result.md
   ```

   Expected: the wrapper exits 0, prints the output path, and the result file contains two numbered answers naming `README.md`, `src/math.js`, and `add(a, b)`. (Note the `commit.gpgsign=false` — machines with global commit signing otherwise fail to create the throwaway commit.)
7. **Claude subagent smoke test.** From the same throwaway repo, run a headless session (headless sessions load `~/.claude/agents/` fresh, so this works even before restarting the interactive session):

   ```bash
   cd "$SMOKE" && claude -p "Use the researcher subagent to state in one sentence what this repository contains, citing one file path."
   ```

   Expected: a one-sentence answer citing `src/math.js` or `README.md`, proving delegation to the Sonnet-pinned researcher works end to end.
8. If `~/.claude/agents/` didn't exist before the current interactive session, remind the user to restart Claude Code once so the watcher picks it up.
9. Run `check.sh` from this tool directory — every line should end `OK`.
10. Optional but recommended on first install: run the live shakedown in `SHAKEDOWN.md` — it exercises every delegation lane end to end (routing, backgrounding, briefs, verification) and finishes with a scorecard.
