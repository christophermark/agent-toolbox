# agent-toolbox

Tools, skills, and prompts for coding agents — Claude Code, Codex, and whatever
comes next.

The premise of this repo: **installation is an agent task.** Every tool here ships
with an `INSTALL.md` written for an implementing agent, not a human. You don't
follow the instructions — you hand them to your agent:

```
Read tools/<name>/INSTALL.md in this repo and install the tool as described.
Show me diffs before overwriting anything that already exists.
```

A human can always install by hand (the payloads are plain files), but the docs
are agent-first by design.

## Catalog

| Tool | Type | Agents | What it does |
|---|---|---|---|
| [delegation-system](tools/delegation-system/) | system (multi-file) | Claude Code (+ Codex CLI) | Turns a premium main-loop model into an orchestrator that routes work to cheaper Sonnet subagents (Explore / researcher / implementer / verifier) and to a sandboxed Codex lane — preserving main-thread context and cutting cost |

## How a tool is packaged

Every entry under `tools/` follows the same contract:

```
tools/<name>/
├── README.md    # the card: what it is, when to use it, usage patterns, troubleshooting
├── INSTALL.md   # agent-executable install: preflight checks, file map, idempotency rules, verification
├── files/       # canonical payloads — the actual files that get installed, byte-for-byte
└── check.sh     # optional: diffs the installed reality against files/ to detect drift
```

Two rules make this work:

1. **`files/` is the single source of truth.** Install docs reference payloads by
   path; they never embed a second copy. (The predecessor of this repo lived in
   gists that embedded everything inline — keeping the copies in sync was a
   recurring chore. Never again.)
2. **Trust, but verify.** If a tool changes things an agent could get subtly wrong,
   it ships a `check.sh` that compares the installed files against `files/` and
   exits non-zero on drift. Run it after installing, and again whenever you
   suspect your local copies have wandered.

## Adding a tool

1. Create `tools/<name>/` with the contract above. `README.md` and `files/` are
   required; `INSTALL.md` is required if installation is more than "copy one file";
   `check.sh` if drift would hurt.
2. Payloads must be portable: `~` or `$HOME`, never absolute user paths; no
   secrets, tokens, or machine-specific config.
3. Write `INSTALL.md` for a cold-start agent: preflight (what versions/binaries to
   check), exact target paths, what to do when a target already exists (default:
   show a diff and ask), and a verification section with expected output.
4. Add one row to the catalog table above. Keep the description to one sentence of
   *what it does for you*, not what it contains.

## Types

- **system** — multi-file setup that changes how an agent session works
- **skill** — a single skill/command an agent invokes on demand
- **script** — a standalone executable an agent (or human) calls
- **prompt** — a reusable prompt/work-order template

---

Maintained with the tools in this repo, naturally.
