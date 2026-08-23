#!/usr/bin/env bash
# Detects drift between the canonical statusline payloads in this checkout's
# files/ and the installed ~/.claude/statusline files, plus the settings.json
# wiring that activates them. Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload_root="$script_dir/files/statusline"
installed_root="$HOME/.claude/statusline"
settings_file="$HOME/.claude/settings.json"
status=0

check_pair() {
  local rel="$1"
  local source_file="$payload_root/$rel"
  local target_file="$installed_root/$rel"
  if [[ ! -e "$target_file" ]]; then
    echo "MISSING $target_file"
    status=1
  elif ! diff -q "$source_file" "$target_file" >/dev/null 2>&1; then
    echo "DRIFT $target_file"
    diff -u "$target_file" "$source_file" | sed "s/^/  /"
    status=1
  else
    echo "OK $target_file"
  fi
}

check_pair "core.sh"
check_pair "statusline.sh"
check_pair "subagent.sh"
check_pair "preview.sh"
check_pair "variants/tuneup.sh"
check_pair "variants/dense.sh"
check_pair "variants/focus.sh"
check_pair "variants/minimal.sh"
check_pair "variants/powerline.sh"

# --- settings.json wiring ---

check_wiring() {
  local jq_key="$1" script_name="$2" required="$3"
  local cmd
  cmd="$(jq -r "${jq_key} // empty" "$settings_file" 2>/dev/null)"
  if [[ -z "$cmd" ]]; then
    if [[ "$required" == "required" ]]; then
      echo "MISSING $jq_key in $settings_file"
      status=1
    else
      echo "INFO $jq_key not set in $settings_file (optional)"
    fi
    return
  fi
  case "$cmd" in
    *".claude/statusline/$script_name") echo "OK $jq_key -> $script_name" ;;
    *)
      echo "DRIFT $jq_key in $settings_file points at '$cmd', expected .../.claude/statusline/$script_name"
      status=1
      ;;
  esac
}

if [[ ! -e "$settings_file" ]]; then
  echo "MISSING $settings_file"
  status=1
else
  check_wiring ".statusLine.command" "statusline.sh" "required"
  check_wiring ".subagentStatusLine.command" "subagent.sh" "optional"
fi

# --- active variant ---

active_file="$installed_root/active"
if [[ ! -e "$active_file" ]]; then
  echo "INFO $active_file missing (falls back to tuneup)"
else
  active_variant="$(cat "$active_file")"
  if [[ -e "$payload_root/variants/$active_variant.sh" ]]; then
    echo "OK $active_file -> $active_variant"
  else
    echo "DRIFT $active_file names nonexistent variant '$active_variant'"
    status=1
  fi
fi

# --- environment notes ---

if command -v jq >/dev/null 2>&1; then
  echo "OK jq available ($(jq --version))"
else
  echo "INFO jq not available"
fi

bash_version="$(/bin/bash --version | head -1)"
if [[ "$bash_version" == *"version 3."* ]]; then
  echo "WARNING /bin/bash is 3.x ($bash_version) — expected on macOS, payloads target 3.2"
else
  echo "OK $bash_version"
fi

exit "$status"
