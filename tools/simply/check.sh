#!/usr/bin/env bash
# Detects drift between the canonical simply skill payload and its installed
# location. Does not modify anything.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$script_dir/files/skills/simply"
installed="$HOME/.claude/skills/simply"
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

# Files present locally but absent from the payload are reported, not failed:
# they may be a deliberate local addition.
if [[ -d "$installed" ]]; then
  while IFS= read -r relative; do
    [[ -e "$payload/$relative" ]] || echo "EXTRA $installed/$relative"
  done < <(cd "$installed" && find . -type f -print | sed 's#^\./##' | sort)
fi

exit "$status"
