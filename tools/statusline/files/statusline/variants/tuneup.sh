# tuneup — today's status line, unchanged visually. Same two lines, same colours,
# just built on the fast core (1 jq call, cached git) with the rounding, clamping
# and detached-HEAD edges fixed.

render() {
  local sep="${D} │ ${R}" line1 line2 counts git_info="" ctx pct bar bc usage="" sv c

  # line 1: model | branch [+s ~u ?q] | cost | usage windows
  line1="${WHT}${B}${CC_MODEL}${R}"
  if [ "$CC_IN_REPO" = "1" ]; then
    [ "$CC_STAGED"    -gt 0 ] && counts="${counts}${YEL}+${CC_STAGED}${R} "
    [ "$CC_UNSTAGED"  -gt 0 ] && counts="${counts}${YEL}~${CC_UNSTAGED}${R} "
    [ "$CC_UNTRACKED" -gt 0 ] && counts="${counts}${YEL}?${CC_UNTRACKED}${R} "
    counts="${counts% }"
    git_info=" ${CYN}${CC_BRANCH}${R}${counts:+ [${counts}]}"
    line1="${line1}${git_info}"
  fi
  if [ -n "$CC_COST" ]; then
    cc_money "$CC_COST"
    line1="${line1}${sep}${YEL}\$${REPLY}${R}"
  fi

  for w in "5h:$CC_5H:75:85" "7d:$CC_7D:90:95" "7dO:$CC_7D_OPUS:90:95"; do
    local lbl=${w%%:*} rest=${w#*:} p wa cr
    p=${rest%%:*}; rest=${rest#*:}; wa=${rest%%:*}; cr=${rest#*:}
    [ -n "$p" ] || continue
    cc_sev "$p" "$wa" "$cr"; sv=$REPLY
    cc_sevcolor "$sv"; c=$REPLY
    cc_int "$p"
    usage="${usage}${usage:+ }${c}${lbl}:${REPLY}%${R}"
  done
  [ -n "$usage" ] && line1="${line1}${sep}${usage}"

  # line 2: context bar + % | cwd
  if [ -n "$CC_CTX_PCT" ]; then
    cc_int "$CC_CTX_PCT"; pct=$REPLY
    if   [ "$pct" -lt 50 ]; then bc=$GRN
    elif [ "$pct" -lt 80 ]; then bc=$YEL
    else bc=$RED; fi
    cc_bar_c "$bc" "$pct" 20
    bar="$REPLY"
    ctx="${bar} ${bc}${pct}%${R}"
  else
    ctx="${D}no context data${R}"
  fi
  cc_path "$CC_CWD" 2
  line2="${ctx}${sep}${D}${REPLY}${R}"

  printf '%s\n%s' "$line1" "$line2"
}
