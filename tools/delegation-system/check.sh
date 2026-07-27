#!/usr/bin/env bash
# Detects drift between the delegation-system payloads and the installed
# ~/.claude files. By default compares against the latest published payloads
# on GitHub main (upstream); pass --local to compare against this checkout's
# files/ instead (offline, or when iterating on unpushed payload changes).
# Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote_base="https://raw.githubusercontent.com/christophermark/agent-toolbox/main/tools/delegation-system/files"

mode="remote"
case "${1:-}" in
  --local) mode="local" ;;
  "") ;;
  *) echo "usage: $0 [--local]" >&2; exit 2 ;;
esac

status=0
tmp_dir=""
if [[ "$mode" == "remote" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  echo "# comparing against upstream main ($remote_base)"
else
  echo "# comparing against local checkout ($script_dir/files)"
fi

# Prints a local path holding the payload for relative path $1.
# In remote mode, fetches from GitHub main; returns 1 on fetch failure.
payload_for() {
  local rel="$1"
  if [[ "$mode" == "local" ]]; then
    echo "$script_dir/files/$rel"
  else
    local out="$tmp_dir/${rel//\//__}"
    curl -fsS --max-time 15 "$remote_base/$rel" -o "$out" || return 1
    echo "$out"
  fi
}

check_pair() {
  local rel="$1" target="$2"
  local payload
  if ! payload="$(payload_for "$rel")"; then
    echo "FETCH-FAIL $target (couldn't retrieve $remote_base/$rel — offline or file not on main; try --local)"
    status=1
    return
  fi
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

check_pair "agents/explore.md"     "$HOME/.claude/agents/explore.md"
check_pair "agents/researcher.md"  "$HOME/.claude/agents/researcher.md"
check_pair "agents/implementer.md" "$HOME/.claude/agents/implementer.md"
check_pair "agents/verifier.md"    "$HOME/.claude/agents/verifier.md"
check_pair "skills/delegate-to-codex/SKILL.md" "$HOME/.claude/skills/delegate-to-codex/SKILL.md"
check_pair "skills/delegate-to-codex/scripts/codex-delegate.sh" "$HOME/.claude/skills/delegate-to-codex/scripts/codex-delegate.sh"

# CLAUDE.md holds the delegation section among other content; extract just
# the "## Delegation" section (heading through the line before the next
# "## " heading, or EOF), trim trailing blank lines, and diff that against
# the payload.
claude_md="$HOME/.claude/CLAUDE.md"
target_label="$claude_md (## Delegation section)"

if ! delegation_payload="$(payload_for "claude-md/delegation.md")"; then
  echo "FETCH-FAIL $target_label (couldn't retrieve $remote_base/claude-md/delegation.md — offline or file not on main; try --local)"
  status=1
elif [[ ! -e "$claude_md" ]]; then
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
