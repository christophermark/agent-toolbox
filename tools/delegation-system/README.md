# Delegation System

A delegation system for Claude Code where a premium main-loop model (Fable 5 / Opus) acts as orchestrator and routes work to cheaper Claude subagents and to the Codex CLI — expanding the main thread's capability by keeping bulk tool output out of its context window, not by dumbing it down.

## Design principles

These come from Anthropic's Fable 5 prompting guide, the current Claude Code subagent docs, and post-Fable community playbooks (mid-2026):

1. **The main thread is the scarce resource.** Delegation exists to protect the orchestrator's context window and judgment, not primarily to save money. A session at two-thirds context capacity degrades; every grep dump or test log you keep out of the main conversation is intelligence preserved. Cost savings are a side effect of routing bulk work to Sonnet and Codex.
2. **The orchestrator keeps: goal understanding, architecture, judgment calls, integration, and final review.** Everything mechanical or read-heavy is a candidate for delegation. Ambiguous design work is never delegated — writing the spec *is* the work.
3. **Cheapest model that can do the job well — with a quality floor.** Sonnet handles everything delegated (retrieval, research synthesis, mechanical implementation, verification); the main model is reserved for orchestration; Codex is an out-of-band lane for large read-heavy jobs and cross-model second opinions. Haiku was considered for the retrieval lane and deliberately rejected: exploration output is navigation ground truth for the orchestrator, and a small model's silent false negatives ("no other call sites exist") poison downstream decisions in exactly the way this system is supposed to prevent. Community measurements report 50–80% cost reduction with no visible quality drop from the orchestrator/executor split alone.
4. **Fable-era mechanics, not Opus-era mechanics.** Fable 5 dispatches parallel subagents reliably and manages long-lived ones. So: prefer background/parallel dispatch with fan-out scaled to the task's structure (a lookup needs one worker; work that genuinely decomposes justifies ten or more — Anthropic's own guidance scales fan-out to complexity rather than fixing a count, and the harness queues any excess), prefer *resuming* a live subagent over respawning (keeps its context and prompt cache), and use fresh-context **verifier** subagents instead of self-critique — Anthropic reports these outperform self-review.
5. **Work orders in, evidence-backed briefs out.** Subagents start with zero session context. Every delegation carries: goal, exact paths/symbols, constraints and non-goals, expected proof, and the return shape. Bulk output goes to a scratch directory on disk; only the brief returns to the orchestrator.
6. **Instructions stay short.** Fable-class models follow brief policy statements better than enumerated rulebooks; over-prescriptive skills measurably degrade output. The CLAUDE.md policy is deliberately compact — do not pad it.
7. **Guardrails live in structure, not prose.** Read-only agents get read-only tools. Codex runs sandboxed (`read-only` or `workspace-write`), never with approvals bypassed. Commits, pushes, releases, secrets, and destructive ops never leave the main thread.

## Architecture

| Component | File | Model / mode | Role |
|---|---|---|---|
| Delegation policy | `files/claude-md/delegation.md` (appended as a section of `~/.claude/CLAUDE.md`) | — | Teaches the orchestrator when and how to route |
| Explore override | `files/agents/explore.md` | Sonnet, read-only | Keeps built-in exploration off the premium session model (since v2.1.198 Explore *inherits* it — up to Opus prices). Sonnet over Haiku is deliberate: no silent false negatives in retrieval |
| Researcher | `files/agents/researcher.md` | Sonnet, read-only + scratch writes, per-project memory | Multi-file synthesis, log/doc digestion, root-cause investigation, state reconstruction |
| Implementer | `files/agents/implementer.md` | Sonnet, edit+bash, turn-bounded | Mechanical execution of frozen approaches |
| Verifier | `files/agents/verifier.md` | Sonnet, read+bash, fresh context, persistent memory | Checks finished work against spec; replaces self-review |
| Codex bridge | `files/skills/delegate-to-codex/` (SKILL.md + wrapper script) | Codex CLI, sandboxed `codex exec` | Large read-heavy jobs, bulk patch drafting, bounded write tasks, cross-model review |
| Scratch convention | `.delegate/scratch/` per repo | — | Disk handoff for bulk material so it never enters the main context |

Division of labor at a glance: **Sonnet finds, does, and checks. Codex second-opinions. The main model decides, integrates, and signs off.**

This system deliberately stops at report-back subagents plus one external CLI. For work that needs teammates coordinating directly with each other, or fan-out into dozens of independent units, reach for Claude Code's built-in [agent teams](https://code.claude.com/docs/en/agent-teams) or [Dynamic Workflows](https://code.claude.com/docs/en/workflows) instead — the same orchestrator-keeps-judgment principles apply.

## Install

Give an implementing agent this prompt:

```
Read tools/delegation-system/INSTALL.md and install as described. Show me diffs before overwriting anything that already exists.
```

## Validate

Two layers:

- **Static** — `./check.sh` diffs every installed file against `files/`; seven
  `OK` lines means no drift.
- **Dynamic** — [SHAKEDOWN.md](SHAKEDOWN.md) is a prompt you hand to your
  orchestrator session: it plants a bug in a throwaway repo, exercises all six
  delegation lanes against it (background Codex audit, Explore, researcher,
  implementer, verifier, integration), and reports a scorecard. Run it after
  first install and after upgrading Claude Code or the Codex CLI.

## Usage patterns

Verbatim prompts you can use or adapt:

- **Parallel research fan-out:**
  > Research the auth, billing, and API modules in parallel using separate
  > researcher subagents; each returns a brief with `path:line` evidence. Then
  > synthesize the three briefs into one design assessment.
- **Plan execution with a long-lived worker:** freeze the approach first, then:
  > Dispatch the implementer subagent with slice 1 of the plan (files, approach,
  > proof command). When it reports, review, then send slice 2 to the *same*
  > implementer via SendMessage rather than spawning a new one.
- **Close the loop:**
  > Dispatch the verifier subagent with the original work order and the list of
  > changed files. Do not self-certify.
- **Codex as background second brain:** at the start of a large job:
  > Write a work order to `/tmp/wo-audit.md` asking for an audit of module X, then
  > run codex-delegate.sh in research mode as a background task. Continue
  > orchestrating; integrate the Codex brief when it lands.
- **Cross-model design review (Codex `research` mode work order):**

  ```markdown
  Goal: Second opinion on the design below. Success = a verdict with the top 3
  risks, each tied to a concrete file or interface in this repo.

  Design: [paste the frozen design summary]
  Relevant files: src/auth/session.ts, src/auth/middleware.ts
  Non-goals: do not propose a rewrite; critique this design as scoped.
  Output shape: verdict (sound / sound-with-risks / flawed), then numbered risks
  with evidence, then open questions.
  ```

- **Fork for context-heavy side quests:** when a side task needs the whole
  conversation (e.g. "draft tests for everything we changed so far"), use `/fork`
  or ask for a fork — it shares the prompt cache instead of paying re-explanation.

Anti-patterns to avoid: delegating single-file edits (round-trip overhead exceeds the task), fan-out mismatched to the task (a fleet for a single lookup, or more parallel lanes than you can meaningfully integrate), two subagents writing the same files, letting subagents return raw dumps instead of briefs, and delegating ambiguity.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Wrapper fails instantly with a git error | Target isn't a git repo | research/patch handle this automatically via `--skip-git-repo-check`; write mode refuses by design |
| Wrapper fails with auth/login error | Codex not logged in | `codex login` (interactive; in Claude type `! codex login`) |
| Subagent not found in interactive session | `~/.claude/agents/` created mid-session | Restart Claude Code once; thereafter edits hot-reload |
| Explore still runs on an expensive model | Override not loaded, or name mismatch | File must set `name: Explore` exactly; check `/doctor` for duplicate-name warnings |
| All subagents run on one model regardless of frontmatter | `CLAUDE_CODE_SUBAGENT_MODEL` is set | Unset it in the environment and `settings.json` `env` |
| Throwaway-repo commit fails with GPG error | Global `commit.gpgsign=true` | Add `-c commit.gpgsign=false` to the test commit |
| `-c` override seems ignored by Codex | Key renamed in a newer Codex | Re-verify against `codex exec --help` and the config reference; adjust wrapper |
| Background subagent goes idle without delivering its brief | Worker finished without messaging the orchestrator | Ping it via SendMessage; agent prompts should end with an explicit report-back line |

## Design notes & maintenance

- These are personal defaults (`~/.claude/`); check project-specific variants into a repo's `.claude/agents/` when a team should share them.
- `verifier` accumulates cross-project failure patterns in `~/.claude/agent-memory/verifier/`; `researcher` keeps per-project notes in each repo's `.claude/agent-memory-local/researcher/` (kept out of version control) so codebase-specific "facts" never leak between projects. Prune either if it drifts.
- Revisit the Explore override when pricing or built-in behavior changes — its purpose is pinning exploration to the cheapest *reliable* tier below the premium session model (Sonnet today; Haiku was rejected because silent false negatives in retrieval poison orchestrator decisions).
- If a future Claude Code version warns about unknown frontmatter fields (`memory`, `effort`, `maxTurns`), consult current docs at https://code.claude.com/docs/en/sub-agents and adapt.
- OpenAI ships an official alternative to the wrapper ([openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc), installed via `/plugin marketplace add openai/codex-plugin-cc`). The wrapper here is kept because it enforces the sandbox/mode contract and file-based work orders; the plugin adds interactive review commands if you want both.
- Non-interactive `codex exec` cannot answer approval prompts (they fail if no prompt surface exists), so `approval_policy="never"` is correct for all modes and safety comes entirely from the sandbox tier.
- Codex `--strict-config` (added by 0.144.x) was evaluated and deliberately left out of the wrapper: it validates the user's entire `~/.codex/config.toml`, not just the wrapper's `-c` overrides, so one unrecognized key in a personal config (e.g. written by a newer Codex desktop app) would break every delegated call. It remains useful as a manual lint when debugging the "`-c` override seems ignored" symptom.
- `codex exec` refuses to run outside a git repository by default. The wrapper detects this: research/patch add `--skip-git-repo-check` for non-git targets; write mode hard-fails instead, because without git the edits aren't reviewable or reversible.
- The work-order file is combined with per-mode delegation rules into one prompt fed via stdin (`codex exec ... -`), and the final message lands in the `--output` file so the orchestrator reads a file instead of scraping a terminal stream.
- On success the wrapper emits a one-line provenance record (mode/model/effort) to stderr before printing the output path, so delegation audits can attribute results without digging through the Codex config.

## Provenance

Battle-tested via a six-lane live shakedown (setup → background Codex audit → Explore → researcher → implementer → verifier) on 2026-07-09. Wrapper flags and config keys re-verified against codex-cli 0.144.5 on 2026-07-17 — compatible, no changes needed. Earlier self-contained versions were published as gists: [full plan](https://gist.github.com/christophermark/50e0487fce92d7de176bdc8bb5c8ea5e), [subagent setup](https://gist.github.com/christophermark/da8972564a630ae4583c5d54c481fe3c), [Codex bridge](https://gist.github.com/christophermark/3f1a85d11b91b980258f973c2ec94c8f) — this repo is now canonical.

## Sources

- Anthropic, "Prompting Claude Fable 5" — parallel/long-lived subagent guidance, fresh-context verifiers, short-instruction principle: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- Claude Code subagent reference (frontmatter fields, Explore model change in v2.1.198, background-by-default, SendMessage resume, forks, memory): https://code.claude.com/docs/en/sub-agents
- Anthropic, "How we built our multi-agent research system" — scale fan-out to query complexity (one agent for simple fact-finding, 2–4 for comparisons, 10+ for complex research): https://www.anthropic.com/engineering/multi-agent-research-system
- Claude Code agent-teams reference — "no hard limit" on teammates; 3–5 is a starting point sized by task density, not a ceiling: https://code.claude.com/docs/en/agent-teams
- Claude Code Dynamic Workflows — the sanctioned high-fan-out mechanism (16 concurrent, 1,000 agents per run) for work that decomposes into dozens-plus independent units: https://code.claude.com/docs/en/workflows
- Codex CLI: `codex exec --help` (v0.142.5) and the config reference: https://developers.openai.com/codex/config-reference
- Totalum, "Claude Code subagents: the 2026 production playbook" — delegation criteria and anti-patterns (its fixed "3–5 concurrency sweet spot" was dropped from this system in favor of task-scaled fan-out): https://www.totalum.app/blog/claude-code-subagents-totalum
- Rylaa/fable5-orchestrator — tier routing, disk hand-offs, threshold-gated delegation: https://github.com/Rylaa/fable5-orchestrator
- OpenAI Codex CLI subagents doc: https://developers.openai.com/codex/subagents
- openai/codex-plugin-cc (official Codex-from-Claude-Code plugin): https://github.com/openai/codex-plugin-cc
- Data Science Dojo, "Fable 5 as Orchestrator, Sonnet as Executor": https://datasciencedojo.com/blog/claude-code-fable-5-orchestrator-workflow/
