#!/usr/bin/env bash
# Detects drift between this tool's files/ payloads and the installed
# ~/.claude delegation system. Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
files_dir="$script_dir/files"

status=0

check_pair() {
  local payload="$1" target="$2"
  if [[ ! -e "$target" ]]; then
    echo "MISSING $target"
    status=1
  elif ! diff -q "$payload" "$target" >/dev/null 2>&1; then
    echo "DRIFT $target"
    status=1
  else
    echo "OK $target"
  fi
}

check_pair "$files_dir/agents/explore.md"    "$HOME/.claude/agents/explore.md"
check_pair "$files_dir/agents/researcher.md" "$HOME/.claude/agents/researcher.md"
check_pair "$files_dir/agents/implementer.md" "$HOME/.claude/agents/implementer.md"
check_pair "$files_dir/agents/verifier.md"   "$HOME/.claude/agents/verifier.md"
check_pair "$files_dir/skills/delegate-to-codex/SKILL.md" "$HOME/.claude/skills/delegate-to-codex/SKILL.md"
check_pair "$files_dir/skills/delegate-to-codex/scripts/codex-delegate.sh" "$HOME/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh"

# CLAUDE.md holds the delegation section among other content; extract just
# the "## Delegation" section (heading through the line before the next
# "## " heading, or EOF), trim trailing blank lines, and diff that against
# the payload.
claude_md="$HOME/.claude/CLAUDE.md"
delegation_payload="$files_dir/claude-md/delegation.md"
target_label="$claude_md (## Delegation section)"

if [[ ! -e "$claude_md" ]]; then
  echo "MISSING $target_label"
  status=1
else
  extracted="$(mktemp)"
  awk '
    /^## Delegation$/ { p=1 }
    p && /^## / && !/^## Delegation$/ { exit }
    p { buf[++n]=$0 }
    END {
      while (n > 0 && buf[n] == "") n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  ' "$claude_md" > "$extracted"

  if ! diff -q "$delegation_payload" "$extracted" >/dev/null 2>&1; then
    echo "DRIFT $target_label"
    status=1
  else
    echo "OK $target_label"
  fi
  rm -f "$extracted"
fi

exit "$status"
