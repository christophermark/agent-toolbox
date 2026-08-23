#!/usr/bin/env bash
# Render every variant against a set of scenarios, so you can compare without
# waiting for live sessions to reach an interesting state.
#
#   ./preview.sh                 all variants, all scenarios
#   ./preview.sh dense           one variant, all scenarios
#   ./preview.sh dense fresh     one variant, one scenario
#   ./preview.sh --list          list captured real sessions, newest first
#   ./preview.sh --real          newest captured payload
#   ./preview.sh --real 3fa9 dense   a specific session, by id prefix
#   ./preview.sh --bench         time each variant
#
# To capture real payloads, add "CC_STATUSLINE_CAPTURE": "1" to the `env` block of
# settings.json and restart. Each session writes captures/<session_id>.json plus a
# .env sidecar (mode 600, pruned after 7 days). Keyed by session id because every
# concurrent session runs this same script — a single shared file would record only
# whichever session rendered last.

HERE=$(cd "$(dirname "$0")" && pwd)
NOW=$(date +%s)

scenario() {  # $1 = name
  local cwd="$PWD"
  case "$1" in
    fresh)  # brand new session, clean repo
      jq -nc --arg cwd "$cwd" --argjson r5 $((NOW+17000)) --argjson r7 $((NOW+240000)) '{
        model:{id:"claude-opus-5[1m]",display_name:"Opus 5 (1M context)"},
        cwd:$cwd, workspace:{current_dir:$cwd,project_dir:$cwd,added_dirs:[],
          repo:{host:"github.com",owner:"acme",name:"web-app"}},
        version:"2.1.238", output_style:{name:"default"},
        cost:{total_cost_usd:0.0412,total_duration_ms:48000,total_api_duration_ms:21000,
              total_lines_added:0,total_lines_removed:0},
        exceeds_200k_tokens:false, thinking:{enabled:true}, effort:{level:"high"},
        context_window:{total_input_tokens:31240,total_output_tokens:900,
          context_window_size:1000000,used_percentage:3.1,remaining_percentage:96.9},
        rate_limits:{five_hour:{used_percentage:1,resets_at:$r5},
                     seven_day:{used_percentage:12,resets_at:$r7}}}' ;;
    working)  # mid-session, dirty tree, ahead of upstream, fast mode, PR open
      jq -nc --arg cwd "$cwd" --argjson r5 $((NOW+9000)) --argjson r7 $((NOW+180000)) '{
        model:{id:"claude-opus-5[1m]",display_name:"Opus 5 (1M context)"},
        cwd:$cwd, workspace:{current_dir:$cwd,project_dir:$cwd,added_dirs:[(env.HOME + "/.claude")],
          repo:{host:"github.com",owner:"acme",name:"web-app"}},
        version:"2.1.238", output_style:{name:"default"}, fast_mode:true,
        cost:{total_cost_usd:1.2345,total_duration_ms:812345,total_api_duration_ms:410000,
              total_lines_added:120,total_lines_removed:34},
        exceeds_200k_tokens:false, thinking:{enabled:true}, effort:{level:"high"},
        context_window:{total_input_tokens:428301,total_output_tokens:9100,
          context_window_size:1000000,used_percentage:42.7,remaining_percentage:57.3},
        pr:{number:482,url:"https://x/482",review_state:"APPROVED",kind:"authored"},
        rate_limits:{five_hour:{used_percentage:34,resets_at:$r5},
                     seven_day:{used_percentage:66,resets_at:$r7}}}' ;;
    worktree)  # in a linked worktree, review requested changes, subagent running
      jq -nc --arg cwd "$cwd" --argjson r5 $((NOW+5400)) --argjson r7 $((NOW+90000)) '{
        model:{id:"claude-sonnet-5",display_name:"Sonnet 5"},
        cwd:$cwd, workspace:{current_dir:$cwd,project_dir:$cwd,added_dirs:[],
          git_worktree:"fix-scanner-crash",
          repo:{host:"github.com",owner:"acme",name:"scanner"}},
        version:"2.1.238", output_style:{name:"explanatory"},
        worktree:{name:"fix-scanner-crash",path:"/tmp/wt",branch:"fix/scanner-crash",
                  original_cwd:"/tmp/scanner",original_branch:"main"},
        agent:{name:"implementer"}, vim:{mode:"NORMAL"},
        cost:{total_cost_usd:4.81,total_duration_ms:3120000,total_api_duration_ms:1400000,
              total_lines_added:640,total_lines_removed:212},
        exceeds_200k_tokens:false, thinking:{enabled:false}, effort:{level:"medium"},
        context_window:{total_input_tokens:151900,total_output_tokens:24000,
          context_window_size:200000,used_percentage:76.0,remaining_percentage:24.0},
        pr:{number:1207,url:"https://x/1207",review_state:"CHANGES_REQUESTED",kind:"authored"},
        rate_limits:{five_hour:{used_percentage:71,resets_at:$r5},
                     seven_day:{used_percentage:84,resets_at:$r7}}}' ;;
    danger)  # context nearly full, weekly limit nearly gone, behind upstream
      jq -nc --arg cwd "$cwd" --argjson r5 $((NOW+900)) --argjson r7 $((NOW+36000)) '{
        model:{id:"claude-opus-5[1m]",display_name:"Opus 5 (1M context)"},
        cwd:$cwd, workspace:{current_dir:$cwd,project_dir:$cwd,added_dirs:[],
          repo:{host:"github.com",owner:"acme",name:"api"}},
        version:"2.1.238", output_style:{name:"default"},
        cost:{total_cost_usd:18.407,total_duration_ms:9900000,total_api_duration_ms:5100000,
              total_lines_added:2140,total_lines_removed:980},
        exceeds_200k_tokens:true, thinking:{enabled:true}, effort:{level:"max"},
        context_window:{total_input_tokens:918400,total_output_tokens:41000,
          context_window_size:1000000,used_percentage:91.8,remaining_percentage:8.2},
        rate_limits:{five_hour:{used_percentage:93,resets_at:$r5},
                     seven_day:{used_percentage:96,resets_at:$r7},
                     seven_day_opus:{used_percentage:88}}}' ;;
    nogit)  # not a repo, no rate limits yet (fresh process)
      jq -nc --arg cwd "$HOME" '{
        model:{id:"claude-opus-5",display_name:"Opus 5"},
        cwd:$cwd, workspace:{current_dir:$cwd,project_dir:$cwd,added_dirs:[]},
        version:"2.1.238", output_style:{name:"default"},
        cost:{total_cost_usd:0,total_duration_ms:1200,total_api_duration_ms:800,
              total_lines_added:0,total_lines_removed:0},
        exceeds_200k_tokens:false,
        context_window:{total_input_tokens:0,total_output_tokens:0,
          context_window_size:200000,used_percentage:0,remaining_percentage:100}}' ;;
    real)
      cat "$REAL_FILE" 2>/dev/null ;;
  esac
}

# Newest capture, or the one whose session id starts with $1.
pick_capture() {
  local cap="$HERE/captures" want="$1" f
  [ -d "$cap" ] || return 1
  if [ -n "$want" ]; then
    for f in "$cap/$want"*.json; do [ -f "$f" ] && { printf '%s' "$f"; return 0; }; done
    return 1
  fi
  f=$(ls -t "$cap"/*.json 2>/dev/null | head -1)
  [ -n "$f" ] && { printf '%s' "$f"; return 0; }
  return 1
}

list_captures() {
  local cap="$HERE/captures" f sid cwd
  [ -d "$cap" ] || { echo "  (none — set CC_STATUSLINE_CAPTURE=1 and let a session render)"; return; }
  for f in $(ls -t "$cap"/*.json 2>/dev/null); do
    sid=$(basename "$f" .json)
    cwd=$(grep '^CWD=' "${f%.json}.env" 2>/dev/null | cut -d= -f2-)
    printf '  %-38s %s\n' "$sid" "${cwd:-?}"
  done
}

VARIANTS=$(cd "$HERE/variants" && ls *.sh | sed 's/\.sh$//')
SCENARIOS="fresh working worktree danger nogit"

case "$1" in
  --list)  echo "captured sessions (newest first):"; list_captures; exit 0 ;;
  --real)  SCENARIOS="real"; shift
           # optional session-id prefix: ./preview.sh --real 3fa9 [variant]
           REAL_FILE=""
           if [ -n "$1" ] && REAL_FILE=$(pick_capture "$1"); then shift
           else REAL_FILE=$(pick_capture "") || true; fi
           if [ -z "$REAL_FILE" ] || [ ! -s "$REAL_FILE" ]; then
             echo "no captured payload found in $HERE/captures"
             echo "set CC_STATUSLINE_CAPTURE=1 in settings.json env, then let a session render"
             exit 1
           fi
           echo "using capture: $(basename "$REAL_FILE" .json)"
           grep -h '^CWD=\|^COLUMNS=' "${REAL_FILE%.json}.env" 2>/dev/null | sed 's/^/  /' ;;
  --bench) shift
           echo "timing 50 renders per variant (scenario: working)"
           p=$(scenario working)
           for v in $VARIANTS; do
             printf '  %-11s ' "$v"
             s=$( { time (for i in $(seq 50); do
                     CC_STATUSLINE_VARIANT=$v CLAUDE_USAGE_CACHE=/dev/null \
                       bash "$HERE/statusline.sh" <<<"$p" >/dev/null
                   done) ; } 2>&1 | tr '\n' ' ')
             echo "$s"
           done
           exit 0 ;;
esac

[ -n "$1" ] && VARIANTS="$1"
[ -n "$2" ] && SCENARIOS="$2"

for v in $VARIANTS; do
  printf '\033[1m\033[7m %s \033[0m\n' "$v"
  for s in $SCENARIOS; do
    p=$(scenario "$s")
    [ -n "$p" ] || continue
    printf '\033[90m  %s\033[0m\n' "$s"
    CC_STATUSLINE_VARIANT="$v" CLAUDE_USAGE_CACHE=/dev/null \
      bash "$HERE/statusline.sh" <<<"$p" | sed 's/^/    /'
    printf '\n'
  done
  printf '\n'
done
