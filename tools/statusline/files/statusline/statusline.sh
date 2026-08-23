#!/usr/bin/env bash
# Claude Code status line entry point.
#
#   settings.json -> "statusLine": { "type": "command",
#                      "command": "bash ~/.claude/statusline/statusline.sh" }
#
# Responsibilities, in order:
#   1. persist the .rate_limits payload — the only way anything but the status
#      line can see current usage. The block below is the shared contract with
#      the usage-preflight tool and must stay verbatim; its check.sh follows
#      .statusLine.command and looks for these exact lines.
#   2. parse once, read git once, hand off to the active variant's render()
#   3. optionally capture the raw payload (CC_STATUSLINE_CAPTURE=1) for previewing
#
# Pick a variant:  echo dense > ~/.claude/statusline/active
#            or:   CC_STATUSLINE_VARIANT=focus (env wins over the file)

HERE=$(cd "$(dirname "$0")" && pwd)
input=$(cat)

# ── usage-limit capture ──────────────────────────────────────────────────────
# Persist the official .rate_limits payload so agents can read current usage via
# ~/.claude/check-usage-limit.sh. The whole rate_limits object is stored (not
# just five_hour/seven_day) so model-specific weekly windows survive. Writes are
# atomic and only happen when a real percentage is present, so a payload without
# rate_limits never erases good cached data.
if usage_json=$(jq -e '
      if ([(.rate_limits // {}) | .[]? | .used_percentage? // empty] | length) > 0
      then {
        captured_at: (now | floor),
        captured_at_iso: (now | floor | todate),
        model: (.model.display_name // null),
        rate_limits: .rate_limits,
      }
      else empty end' <<<"$input" 2>/dev/null) && [ -n "$usage_json" ]; then
  usage_cache="${CLAUDE_USAGE_CACHE:-${HOME}/.claude/usage-limits.json}"
  if usage_tmp=$(mktemp "${usage_cache}.XXXXXX" 2>/dev/null); then
    if printf '%s\n' "$usage_json" >"$usage_tmp" 2>/dev/null; then
      chmod 600 "$usage_tmp" 2>/dev/null
      mv -f "$usage_tmp" "$usage_cache" 2>/dev/null || rm -f "$usage_tmp"
    else
      rm -f "$usage_tmp"
    fi
  fi
fi

# ── render ──────────────────────────────────────────────────────────────────
. "$HERE/core.sh"

variant="${CC_STATUSLINE_VARIANT:-}"
if [ -z "$variant" ] && [ -f "$HERE/active" ]; then
  variant=$(tr -d ' \t\n' < "$HERE/active" 2>/dev/null)
fi
[ -n "$variant" ] || variant=tuneup

if [ ! -f "$HERE/variants/$variant.sh" ]; then
  printf '%s' "statusline: unknown variant '$variant'"
  exit 0
fi

cc_parse "$input"
cc_git

# ── optional payload capture, for `preview.sh --real` ───────────────────────
# Keyed by session id: every concurrent session runs this same script, so a
# single shared file would just record whichever session rendered last.
if [ "${CC_STATUSLINE_CAPTURE:-0}" = "1" ]; then
  cap="$HERE/captures"
  [ -d "$cap" ] || mkdir -p "$cap" 2>/dev/null
  sid="$CC_SESSION"
  case "$sid" in ''|*[!A-Za-z0-9_-]*) sid="unknown" ;; esac
  # Prune only on this session's FIRST capture, not on every render — otherwise
  # 20 concurrent sessions pay a `find` fork per refresh for nothing.
  [ -f "$cap/$sid.json" ] || find "$cap" -type f -mtime +7 -delete 2>/dev/null
  printf '%s\n' "$input" > "$cap/$sid.json" 2>/dev/null && chmod 600 "$cap/$sid.json" 2>/dev/null
  # COLUMNS/LINES confirm what the harness exports to this command
  printf 'COLUMNS=%s\nLINES=%s\nTERM=%s\nCWD=%s\nVARIANT=%s\n' \
    "$COLUMNS" "$LINES" "$TERM" "$CC_CWD" "$variant" > "$cap/$sid.env" 2>/dev/null
  chmod 600 "$cap/$sid.env" 2>/dev/null
fi
. "$HERE/variants/$variant.sh"
render
