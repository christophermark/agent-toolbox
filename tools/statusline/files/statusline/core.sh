#!/usr/bin/env bash
# Shared core for Claude Code status lines.
# Parses the whole stdin payload in ONE jq call, exposes it as plain variables,
# and provides a TTL-cached git reader. bash 3.2 compatible (macOS /bin/bash).
#
# Payload field names verified against the Claude Code 2.1.238 binary.

US=$'\037'   # unit separator: non-whitespace, so empty fields never collapse

cc_parse() {  # $1 = raw json
  local raw="$1" line
  line=$(jq -r '
    def s: if . == null then "" else tostring end;
    [ (.model.display_name?        | s)
    , (.model.id?                  | s)
    , (.cwd? // .workspace.current_dir? | s)
    , (.workspace.project_dir?     | s)
    , (.version?                   | s)
    , (.output_style.name? // .output_style? | s)
    , (.fast_mode?                 | s)
    , (.effort.level?              | s)
    , (.thinking.enabled?          | s)
    , (.vim.mode?                  | s)
    , (.agent.name?                | s)
    , (.pr.number?                 | s)
    , (.pr.review_state?           | s)
    , (.worktree.name? // .workspace.git_worktree? | s)
    , (.worktree.branch?           | s)
    , (.workspace.repo.owner?      | s)
    , (.workspace.repo.name?       | s)
    , (.cost.total_cost_usd?       | s)
    , (.cost.total_duration_ms?    | s)
    , (.cost.total_api_duration_ms?| s)
    , (.cost.total_lines_added?    | s)
    , (.cost.total_lines_removed?  | s)
    , (.context_window.used_percentage?      | s)
    , (.context_window.remaining_percentage? | s)
    , (.context_window.context_window_size?  | s)
    , (.context_window.total_input_tokens?   | s)
    , (.exceeds_200k_tokens?       | s)
    , (.rate_limits.five_hour.used_percentage?      | s)
    , (.rate_limits.five_hour.resets_at?            | s)
    , (.rate_limits.seven_day.used_percentage?      | s)
    , (.rate_limits.seven_day.resets_at?            | s)
    , (.rate_limits.seven_day_opus.used_percentage? | s)
    , ((.workspace.added_dirs? // []) | length | s)
    , (.session_id?              | s)
    , (.session_name?            | s)
    ] | join("\u001f")' <<<"$raw" 2>/dev/null)

  IFS="$US" read -r CC_MODEL CC_MODEL_ID CC_CWD CC_PROJECT CC_VERSION CC_STYLE \
    CC_FAST CC_EFFORT CC_THINKING CC_VIM CC_AGENT CC_PR CC_PR_STATE \
    CC_WT CC_WT_BRANCH CC_REPO_OWNER CC_REPO_NAME \
    CC_COST CC_DUR_MS CC_API_MS CC_ADDED CC_REMOVED \
    CC_CTX_PCT CC_CTX_REM CC_CTX_SIZE CC_CTX_TOK CC_OVER_200K \
    CC_5H CC_5H_RESET CC_7D CC_7D_RESET CC_7D_OPUS CC_ADDED_DIRS \
    CC_SESSION CC_SESSION_NAME <<<"$line"

  [ -n "$CC_MODEL" ] || CC_MODEL="Claude"
  [ -n "$CC_CWD" ]   || CC_CWD=$(pwd)

  CC_NOW=$(date +%s)   # single date fork per render; cc_git and cc_reset_in reuse it
}

# ── TTL-cached git ───────────────────────────────────────────────────────────
# Sets CC_BRANCH CC_STAGED CC_UNSTAGED CC_UNTRACKED CC_AHEAD CC_BEHIND CC_IN_REPO
# One `git status --porcelain=v2 --branch` at most every $CC_GIT_TTL seconds per repo.
cc_git() {
  CC_BRANCH=""; CC_STAGED=0; CC_UNSTAGED=0; CC_UNTRACKED=0
  CC_AHEAD=0; CC_BEHIND=0; CC_IN_REPO=0; CC_ROOT=""

  local root cache key now cached ts
  root=$(git --no-optional-locks -C "$CC_CWD" rev-parse --show-toplevel 2>/dev/null) || return 0
  CC_IN_REPO=1
  CC_ROOT="$root"          # checkout directory: distinguishes clones of the same remote

  cache="${TMPDIR:-/tmp}/cc-statusline"
  [ -d "$cache" ] || mkdir -p "$cache" 2>/dev/null
  key="$cache/$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
  now=$CC_NOW

  if [ -f "$key" ]; then
    cached=$(cat "$key" 2>/dev/null)
    ts=${cached%%"$US"*}
    case "$ts" in
      ''|*[!0-9]*) ;;
      *) if [ $(( now - ts )) -lt "${CC_GIT_TTL:-3}" ]; then
           IFS="$US" read -r ts CC_BRANCH CC_STAGED CC_UNSTAGED CC_UNTRACKED CC_AHEAD CC_BEHIND <<<"$cached"
           return 0
         fi ;;
    esac
  fi

  local st l xy ab
  if st=$(git --no-optional-locks -C "$root" status --porcelain=v2 --branch 2>/dev/null); then
    while IFS= read -r l; do
      case "$l" in
        '# branch.head '*) CC_BRANCH=${l#\# branch.head } ;;
        '# branch.ab '*)   ab=${l#\# branch.ab }
                           CC_AHEAD=${ab%% *}; CC_AHEAD=${CC_AHEAD#+}
                           CC_BEHIND=${ab##* }; CC_BEHIND=${CC_BEHIND#-} ;;
        '1 '*|'2 '*)       xy=${l:2:2}
                           [ "${xy%?}" != "." ] && CC_STAGED=$((CC_STAGED+1))
                           [ "${xy#?}" != "." ] && CC_UNSTAGED=$((CC_UNSTAGED+1)) ;;
        '? '*)             CC_UNTRACKED=$((CC_UNTRACKED+1)) ;;
      esac
    done <<<"$st"
    if [ "$CC_BRANCH" = "(detached)" ]; then
      CC_BRANCH=$(git --no-optional-locks -C "$root" rev-parse --short HEAD 2>/dev/null)
    fi
    printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
      "$now" "$US" "$CC_BRANCH" "$US" "$CC_STAGED" "$US" "$CC_UNSTAGED" "$US" \
      "$CC_UNTRACKED" "$US" "$CC_AHEAD" "$US" "$CC_BEHIND" > "$key.$$" 2>/dev/null \
      && mv -f "$key.$$" "$key" 2>/dev/null || rm -f "$key.$$" 2>/dev/null
  fi
}

# ── formatting helpers (no subprocesses) ─────────────────────────────────────
# Convention: each helper below assigns its result to the global REPLY instead
# of printing it, so callers avoid a `$(...)` subshell fork:
#   cc_money "$CC_COST"; cost=$REPLY
BAR_FULL='████████████████████████████████████████'
BAR_EMPTY='░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░'
BAR_FULL_R='▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰'
BAR_EMPTY_R='▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱'

cc_int() { local v=${1%%.*}; case "$v" in ''|*[!0-9-]*) REPLY=0 ;; *) REPLY="$v" ;; esac; }

cc_bar() {  # $1 = percent int, $2 = width, $3 = style (block|round)
  local p w n f e
  cc_int "$1"; p=$REPLY; w=${2:-20}
  [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
  if [ "$3" = "round" ]; then f=$BAR_FULL_R; e=$BAR_EMPTY_R; else f=$BAR_FULL; e=$BAR_EMPTY; fi
  n=$(( p * w / 100 ))
  printf -v REPLY '%s%s' "${f:0:n}" "${e:0:$((w-n))}"
}

cc_tokens() {  # 428301 -> 428k ; 1200000 -> 1.2M
  local t; cc_int "$1"; t=$REPLY
  if   [ "$t" -ge 1000000 ]; then if [ $(( (t%1000000)/100000 )) -eq 0 ]; then printf -v REPLY '%dM' $((t/1000000)); else printf -v REPLY '%d.%dM' $((t/1000000)) $(( (t%1000000)/100000 )); fi
  elif [ "$t" -ge 1000 ];    then printf -v REPLY '%dk' $((t/1000))
  else printf -v REPLY '%d' "$t"; fi
}

cc_dur() {  # ms -> 45s / 4m / 1h12m
  local s; cc_int "$1"; s=$(( REPLY / 1000 ))
  if   [ "$s" -ge 3600 ]; then printf -v REPLY '%dh%dm' $((s/3600)) $(( (s%3600)/60 ))
  elif [ "$s" -ge 60 ];   then printf -v REPLY '%dm' $((s/60))
  else printf -v REPLY '%ds' "$s"; fi
}

cc_reset_in() {  # epoch -> time until reset
  local target s
  cc_int "$1"; target=$REPLY
  REPLY=""
  [ "$target" -le 0 ] && return 0
  s=$(( target - CC_NOW )); [ "$s" -lt 0 ] && s=0
  if   [ "$s" -ge 3600 ]; then printf -v REPLY '%dh' $((s/3600))
  elif [ "$s" -ge 60 ];   then printf -v REPLY '%dm' $((s/60))
  else printf -v REPLY '%ds' "$s"; fi
}

cc_sev() {  # $1 pct  $2 warn  $3 crit -> ok|warn|crit
  local p; cc_int "$1"; p=$REPLY
  if [ "$p" -ge "$3" ]; then REPLY=crit; elif [ "$p" -ge "$2" ]; then REPLY=warn; else REPLY=ok; fi
}

cc_path() {  # last N segments of a path
  local p="${1%/}" n="${2:-2}" out="" i=0
  while [ "$i" -lt "$n" ] && [ -n "$p" ] && [ "$p" != "/" ]; do
    out="${p##*/}${out:+/}$out"; p="${p%/*}"; i=$((i+1))
  done
  REPLY="${out:-/}"
}

cc_money() {  # 1.2345 -> 1.23 (awk-free, integer math on the string)
  local v="$1" whole frac
  case "$v" in ''|null) REPLY='0.00'; return ;; esac
  whole=${v%%.*}; frac=${v#*.}
  [ "$whole" = "$v" ] && frac="00"
  frac="${frac}00"
  printf -v REPLY '%s.%s' "${whole:-0}" "${frac:0:2}"
}

# ── colours ──────────────────────────────────────────────────────────────────
R=$'\033[0m';  B=$'\033[1m';   D=$'\033[2m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
BLU=$'\033[34m'; MAG=$'\033[35m'; CYN=$'\033[36m'; WHT=$'\033[97m'
GRY=$'\033[90m'
cc_sevcolor() { case "$1" in crit) REPLY="$RED" ;; warn) REPLY="$YEL" ;; *) REPLY="$GRN" ;; esac; }

cc_bar_c() {  # $1 colour  $2 pct  $3 width  $4 style -> filled in colour, empty dim
  local col="$1" p w n f e
  cc_int "$2"; p=$REPLY; w=${3:-20}
  [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
  if [ "$4" = "round" ]; then f=$BAR_FULL_R; e=$BAR_EMPTY_R; else f=$BAR_FULL; e=$BAR_EMPTY; fi
  n=$(( p * w / 100 ))
  printf -v REPLY '%s%s%s%s%s' "$col" "${f:0:n}" "$D" "${e:0:$((w-n))}" "$R"
}

cc_dirty() {  # compact dirty summary: +2~1?3 (empty when clean)
  local o=""
  [ "${CC_STAGED:-0}"    -gt 0 ] && o="${o}+${CC_STAGED}"
  [ "${CC_UNSTAGED:-0}"  -gt 0 ] && o="${o}~${CC_UNSTAGED}"
  [ "${CC_UNTRACKED:-0}" -gt 0 ] && o="${o}?${CC_UNTRACKED}"
  REPLY="$o"
}

cc_ab() {  # ahead/behind arrows
  local o=""
  [ "${CC_AHEAD:-0}"  -gt 0 ] && o="${o}↑${CC_AHEAD}"
  [ "${CC_BEHIND:-0}" -gt 0 ] && o="${o}↓${CC_BEHIND}"
  REPLY="$o"
}

cc_model_short() {  # "Opus 5 (1M context)" -> "Opus 5 1M"
  local m="$CC_MODEL"
  m=${m/ (1M context)/ 1M}
  m=${m/Claude /}
  REPLY="$m"
}

# ── terminal-width truncation (no forking, no tput) ─────────────────────────
cc_width() {  # -> REPLY = $COLUMNS if it's a positive int, else 0 ("unknown", disables cc_fit)
  case "$COLUMNS" in
    ''|*[!0-9]*) REPLY=0 ;;
    *) if [ "$COLUMNS" -gt 0 ]; then REPLY="$COLUMNS"; else REPLY=0; fi ;;
  esac
}

cc_fit() {  # $1 = string (may contain ESC[...m colour codes)  $2 = max visible columns -> REPLY
  # ANSI-aware truncation: walks the string one character at a time so a greedy
  # pattern can't eat real text between escape codes. max<=0 means "unknown
  # width" -> truncation disabled, string passed through unchanged.
  # NOTE: this counts one column per *character*, not per display cell — see
  # the East-Asian-wide / emoji caveat in the caller's comment.
  local s="$1" max="$2" i len ch seq vis col budget out
  if [ "$max" -le 0 ]; then REPLY="$s"; return; fi
  len=${#s}

  # pass 1: measure visible width, skipping ESC [ ... <letter> sequences
  vis=0; i=0
  while [ "$i" -lt "$len" ]; do
    ch="${s:$i:1}"
    if [ "$ch" = $'\033' ]; then
      i=$((i+1))
      if [ "${s:$i:1}" = "[" ]; then
        i=$((i+1))
        while [ "$i" -lt "$len" ]; do
          ch="${s:$i:1}"; i=$((i+1))
          case "$ch" in [a-zA-Z]) break ;; esac
        done
      fi
      continue
    fi
    vis=$((vis+1)); i=$((i+1))
  done
  if [ "$vis" -le "$max" ]; then REPLY="$s"; return; fi

  # pass 2: too wide — rebuild up to (max-1) visible columns, then …+reset
  budget=$((max-1)); [ "$budget" -lt 0 ] && budget=0
  i=0; col=0; out=""
  while [ "$i" -lt "$len" ] && [ "$col" -lt "$budget" ]; do
    ch="${s:$i:1}"
    if [ "$ch" = $'\033' ]; then
      seq="$ch"; i=$((i+1))
      if [ "${s:$i:1}" = "[" ]; then
        seq="${seq}["; i=$((i+1))
        while [ "$i" -lt "$len" ]; do
          ch="${s:$i:1}"; seq="${seq}${ch}"; i=$((i+1))
          case "$ch" in [a-zA-Z]) break ;; esac
        done
      fi
      out="${out}${seq}"
      continue
    fi
    out="${out}${ch}"; col=$((col+1)); i=$((i+1))
  done
  REPLY="${out}…${R}"
}

cc_burn() {  # -> REPLY = "$N.NN/h" burn rate from $CC_COST over $CC_DUR_MS, or "" if too short/unknown
  local dur v whole frac cost_units rate_cents
  cc_int "$CC_DUR_MS"; dur=$REPLY
  REPLY=""            # must come AFTER cc_int, which clobbers REPLY with $dur
  [ "$dur" -lt 60000 ] && return 0
  v="$CC_COST"
  case "$v" in ''|null|0|0.0|0.00) return 0 ;; esac
  # Work in ten-thousandths of a dollar, not cents: truncating $1.2345 to 123c
  # before dividing loses ~0.4% of the rate, which is visible at these numbers.
  whole=${v%%.*}; frac=${v#*.}
  [ "$whole" = "$v" ] && frac="0"
  frac="${frac}0000"; frac="${frac:0:4}"
  cost_units=$(( 10#${whole:-0} * 10000 + 10#${frac:-0} ))
  rate_cents=$(( cost_units * 3600000 / dur / 100 ))
  printf -v REPLY '$%d.%02d/h' $((rate_cents/100)) $((rate_cents%100))
}
