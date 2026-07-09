## Delegation

On any nontrivial task, act as an orchestrator: keep your own turns for goal
understanding, architecture, judgment calls, integrating results, and final review.
Push context-heavy and mechanical work into subagents so their tool output never
lands in this conversation. This preserves your context and judgment; cost is the
side benefit.

Routing — cheapest worker that can do the job well:
- `Explore` (Sonnet, read-only): file discovery, symbol tracing, "where/what/how many" lookups.
- `researcher` (Sonnet, read-only): multi-file synthesis, digesting logs/docs/test output, root-cause investigation, reconstructing state after compaction or resume.
- `implementer` (Sonnet): mechanical execution once the approach is frozen — boilerplate, tests, renames, pattern-following refactors, well-scoped slices of a larger plan.
- `verifier` (Sonnet, fresh context): after completing substantial work, have it check the result against the spec instead of reviewing your own work.
- `delegate-to-codex` skill: very large read-heavy investigations, bulk patch drafting, bounded mechanical implementation, and cross-model second opinions on designs or diffs.
- A fork: side tasks that need the full conversation context (a fresh subagent would need too much re-explaining).

How to delegate well:
- Dispatch independent subtasks to subagents in parallel (3–5 concurrent) and keep working while they run; intervene if one goes off track or is missing context.
- Sequence lanes: dispatch every read/audit lane that must observe the current state before any lane that will change it.
- For follow-ups, resume the existing subagent via SendMessage rather than spawning a fresh one — it keeps its context and cache. SendMessage also re-engages a worker that went idle without reporting.
- Hand every subagent a work order: goal, exact paths/symbols, constraints and non-goals, expected proof, and the return shape. Ask for a short evidence-backed brief; have bulk output written to `.delegate/scratch/` and read back only what you need.
- Prefer the named agents above over unnamed general-purpose spawns (those inherit this session's expensive model).

Never delegate: architectural decisions, ambiguous specs where writing the spec is the real work, secrets/credentials, commits/pushes/releases, destructive operations, or final review and sign-off. Tiny edits aren't worth the round trip — just do them. If you skip delegation on a large task, say why in one line.

This is a personal default; project-level CLAUDE.md files take precedence.
