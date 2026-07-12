#!/usr/bin/env bash
# Detects drift between the canonical artifact skill payload and its installed
# location. Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$script_dir/files/skills/artifact"
installed="$HOME/.codex/skills/artifact"
status=0

while IFS= read -r relative; do
  source_file="$payload/$relative"
  target_file="$installed/$relative"
  if [[ ! -e "$target_file" ]]; then
    echo "MISSING $target_file"
    status=1
  elif ! diff -q "$source_file" "$target_file" >/dev/null 2>&1; then
    echo "DRIFT $target_file"
    status=1
  else
    echo "OK $target_file"
  fi
done < <(cd "$payload" && find . -type f -print | sed 's#^\./##' | sort)

launcher="$installed/scripts/claude-artifact.exp"
if [[ -e "$launcher" && ! -x "$launcher" ]]; then
  echo "NOT EXECUTABLE $launcher"
  status=1
fi

exit "$status"
