#!/usr/bin/env bash
# Detects drift between the usage-preflight payloads and the installed
# ~/.claude files. By default compares against the latest published payloads
# on GitHub main (upstream); pass --local to compare against this checkout's
# files/ instead (offline, or when iterating on unpushed payload changes).
# Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote_base="https://raw.githubusercontent.com/christophermark/agent-toolbox/main/tools/usage-preflight/files"

mode="remote"
case "${1:-}" in
  --local) mode="local" ;;
  "") ;;
  *) echo "usage: $0 [--local]" >&2; exit 2 ;;
esac

status=0
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
if [[ "$mode" == "remote" ]]; then
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

fetch_fail() {
  echo "FETCH-FAIL $1 (couldn't retrieve $remote_base/$2 — offline or file not on main; try --local)"
  status=1
}

check_pair() {
  local rel="$1" target="$2"
  local payload
  if ! payload="$(payload_for "$rel")"; then
    fetch_fail "$target" "$rel"
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

check_pair "skills/usage-preflight/SKILL.md" "$HOME/.claude/skills/usage-preflight/SKILL.md"
check_pair "check-usage-limit.sh"            "$HOME/.claude/check-usage-limit.sh"

if [[ -e "$HOME/.claude/check-usage-limit.sh" && ! -x "$HOME/.claude/check-usage-limit.sh" ]]; then
  echo "NOT-EXECUTABLE $HOME/.claude/check-usage-limit.sh (chmod +x it)"
  status=1
fi

# CLAUDE.md holds the preflight policy among other content; extract just the
# "## Usage-limit preflight" section (heading through the line before the next
# "## " heading, or EOF), trim trailing blank lines, and diff that against the
# payload.
claude_md="$HOME/.claude/CLAUDE.md"
target_label="$claude_md (## Usage-limit preflight section)"

if ! policy_payload="$(payload_for "claude-md/usage-preflight.md")"; then
  fetch_fail "$target_label" "claude-md/usage-preflight.md"
elif [[ ! -e "$claude_md" ]]; then
  echo "MISSING $target_label"
  status=1
else
  extracted="$tmp_dir/claude-md-section"
  awk '
    /^## Usage-limit preflight$/ { p=1 }
    p && /^## / && !/^## Usage-limit preflight$/ { exit }
    p { buf[++n]=$0 }
    END {
      while (n > 0 && buf[n] == "") n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  ' "$claude_md" > "$extracted"

  if [[ ! -s "$extracted" ]]; then
    echo "MISSING $target_label"
    status=1
  elif ! diff -q "$policy_payload" "$extracted" >/dev/null 2>&1; then
    echo "DRIFT $target_label"
    status=1
  else
    echo "OK $target_label"
  fi
fi

# The status line is what populates the cache the skill reads, but it is also a
# personal display preference — most installs graft the capture block into a
# status line they already had. So the contract checked here is "the capture
# block is present verbatim", not "your whole status line matches ours".
statusline_target="$(
  jq -r '.statusLine.command // empty' "$HOME/.claude/settings.json" 2>/dev/null \
    | grep -oE '[^[:space:]]*statusline[^[:space:]]*\.sh' | head -1
)"
statusline_target="${statusline_target:-$HOME/.claude/statusline-command.sh}"
statusline_label="$statusline_target (usage-limit capture block)"

if ! statusline_payload="$(payload_for "statusline-command.sh")"; then
  fetch_fail "$statusline_label" "statusline-command.sh"
elif [[ ! -e "$statusline_target" ]]; then
  echo "MISSING $statusline_label"
  status=1
else
  block="$tmp_dir/capture-block"
  awk '
    /^# ── usage-limit capture/ { p=1 }
    p && /^# ── colours/ { exit }
    p { buf[++n]=$0 }
    END {
      while (n > 0 && buf[n] == "") n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  ' "$statusline_payload" > "$block"

  # Substring match across lines, done in pure bash by swapping newlines for a
  # byte that cannot appear in either file.
  haystack="$(tr '\n' '\001' < "$statusline_target")"
  needle="$(tr '\n' '\001' < "$block")"
  if [[ ! -s "$block" ]]; then
    echo "FETCH-FAIL $statusline_label (capture block not found in payload)"
    status=1
  elif [[ "$haystack" == *"$needle"* ]]; then
    echo "OK $statusline_label"
  else
    echo "DRIFT $statusline_label"
    status=1
  fi
fi

# The cache itself is written by the status line at runtime, not by the
# installer. Its absence means the loop has not closed yet — report it, but do
# not fail the check on a machine that simply has not rendered a status line
# since install.
cache="${CLAUDE_USAGE_CACHE:-$HOME/.claude/usage-limits.json}"
if [[ -s "$cache" ]] && jq -e '.rate_limits' "$cache" >/dev/null 2>&1; then
  echo "OK $cache (populated)"
else
  echo "NOTE $cache not populated yet — render a status line in an authenticated interactive session, then re-check"
fi

exit "$status"
