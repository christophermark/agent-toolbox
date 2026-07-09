#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: codex-delegate.sh --repo PATH --prompt-file FILE [--output FILE]
                         [--mode research|patch|write] [--model MODEL]
                         [--effort minimal|low|medium|high|xhigh] [--network]

Runs Codex CLI non-interactively and writes its final response to the output file.
research/patch modes run in a read-only sandbox; write mode uses workspace-write
and requires the target to be a git repository. --network enables outbound network
access inside the write sandbox (ignored in other modes). --effort overrides the
Codex config's model_reasoning_effort; when omitted, the config default applies.
On success, prints a provenance line (mode/model/effort) to stderr and the
output file path to stdout.
USAGE
}

repo="" prompt_file="" output_file="" mode="research" model="" effort="" network=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        repo="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --prompt-file) prompt_file="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --output)      output_file="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --mode)        mode="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --model)       model="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --effort)      effort="${2:-}"; shift 2 || { usage >&2; exit 2; } ;;
    --network)     network=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$repo" && -n "$prompt_file" ]] || { usage >&2; exit 2; }
[[ -d "$repo" ]] || { echo "Repo not found: $repo" >&2; exit 2; }
[[ -f "$prompt_file" ]] || { echo "Prompt file not found: $prompt_file" >&2; exit 2; }
case "$mode" in research|patch|write) ;; *) echo "--mode must be research, patch, or write" >&2; exit 2 ;; esac
case "$effort" in ""|minimal|low|medium|high|xhigh) ;; *) echo "--effort must be minimal, low, medium, high, or xhigh" >&2; exit 2 ;; esac
command -v codex >/dev/null 2>&1 || { echo "codex CLI not found on PATH" >&2; exit 127; }

git_repo=0
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git_repo=1
if [[ "$mode" == "write" && "$git_repo" -ne 1 ]]; then
  echo "write mode requires a git repository (the diff must be reviewable and reversible): $repo" >&2
  exit 2
fi

[[ -n "$output_file" ]] || output_file="$(mktemp "${TMPDIR:-/tmp}/codex-delegate.XXXXXX.md")"
combined_prompt="$(mktemp "${TMPDIR:-/tmp}/codex-work-order.XXXXXX.md")"
stderr_file="$(mktemp "${TMPDIR:-/tmp}/codex-delegate-stderr.XXXXXX.log")"
trap 'rm -f "$combined_prompt" "$stderr_file"' EXIT

{
  echo "# Delegated Work Order"
  echo
  cat "$prompt_file"
  echo
  echo "# Delegation Rules"
  echo
  echo "- Keep the response concise and evidence-backed; lead with the answer."
  echo "- Report commands you ran (or would run) and summarize their results."
  case "$mode" in
    research)
      echo "- You are in a read-only sandbox. Do not edit files."
      echo "- Return: answer, paths/symbols with short evidence, confidence, open questions."
      ;;
    patch)
      echo "- You are in a read-only sandbox. Do not edit files."
      echo "- Return a proposed unified diff for any code changes, then a short"
      echo "  explanation and verification notes. Do not claim files were changed;"
      echo "  the caller will review and apply any accepted patch."
      ;;
    write)
      echo "- You may edit files inside this workspace, strictly within the requested scope."
      echo "- Run focused verification when available."
      echo "- Do not run git commit/push or any destructive command."
      echo "- Return: files changed, commands run, verification results, risks."
      ;;
  esac
} > "$combined_prompt"

sandbox_mode="read-only"
[[ "$mode" == "write" ]] && sandbox_mode="workspace-write"

args=(
  exec
  --cd "$repo"
  --sandbox "$sandbox_mode"
  -c 'approval_policy="never"'
  --output-last-message "$output_file"
)
[[ -n "$effort" ]] && args+=(-c "model_reasoning_effort=\"$effort\"")
[[ "$git_repo" -eq 1 ]] || args+=(--skip-git-repo-check)
[[ "$mode" == "write" && "$network" -eq 1 ]] && args+=(-c 'sandbox_workspace_write.network_access=true')
[[ -n "$model" ]] && args+=(--model "$model")

if [[ "${CODEX_DELEGATE_DEBUG:-}" == "1" ]]; then
  codex "${args[@]}" - < "$combined_prompt"
else
  if ! codex "${args[@]}" - < "$combined_prompt" 2>"$stderr_file"; then
    echo "Codex delegation failed. Stderr (first 120 lines):" >&2
    sed -n '1,120p' "$stderr_file" >&2
    exit 1
  fi
fi

if [[ -z "$model" ]]; then
  model="$(sed -n 's/^model[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$HOME/.codex/config.toml" 2>/dev/null | head -1)"
  model="${model:-unknown} (config default)"
fi
if [[ -z "$effort" ]]; then
  effort="$(sed -n 's/^model_reasoning_effort[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$HOME/.codex/config.toml" 2>/dev/null | head -1)"
  effort="${effort:-unknown} (config default)"
fi
echo "codex-delegate: mode=$mode model=$model effort=$effort" >&2
echo "$output_file"
