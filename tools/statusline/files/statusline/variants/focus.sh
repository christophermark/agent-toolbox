# focus — one loud headline that answers "do I need to do something right now?",
# then a quiet detail line. Only one thing is allowed to shout at a time.
#
# Headline priority:  7d/5h limit critical  >  context critical  >  behind upstream
#                     >  context warning     >  all clear

render() {
  local dot="${GRY} · ${R}" head="" l2="" pct bc sv5 sv7 r d wk

  cc_int "${CC_CTX_PCT:-0}"; pct=$REPLY
  cc_sev "${CC_5H:-0}" 75 90; sv5=$REPLY
  cc_sev "${CC_7D:-0}" 80 92; sv7=$REPLY

  if   [ "$sv7" = "crit" ]; then
    cc_reset_in "$CC_7D_RESET"; r=$REPLY
    cc_int "$CC_7D"
    head="${RED}${B}⛔ weekly limit ${REPLY}%${R}${RED} — resets in ${r:-?}${R}"
  elif [ "$sv5" = "crit" ]; then
    cc_reset_in "$CC_5H_RESET"; r=$REPLY
    cc_int "$CC_5H"
    head="${RED}${B}⛔ 5h limit ${REPLY}%${R}${RED} — resets in ${r:-?}${R}"
  elif [ "$pct" -ge 85 ]; then
    head="${RED}${B}⛔ context ${pct}% — compact now${R}"
  elif [ "${CC_BEHIND:-0}" -gt 0 ]; then
    head="${YEL}${B}⇣ ${CC_BEHIND} commit(s) behind ${CC_BRANCH}${R}"
  elif [ "$pct" -ge 70 ]; then
    head="${YEL}${B}⚠ context ${pct}% — wrap up or compact${R}"
  elif [ "$sv7" = "warn" ]; then
    cc_int "${CC_7D:-0}"
    head="${YEL}${B}⚠ weekly usage ${REPLY}%${R}"
  else
    # rate_limits is absent until the first API response of a session. Showing
    # "weekly 0%" there would read as "nothing used this week", which is a
    # reassuring claim we cannot make — say "—" when we simply do not know.
    if [ -n "$CC_7D" ]; then cc_int "$CC_7D"; wk="${REPLY}%"; else wk="—"; fi
    head="${GRN}${B}✓ clear${R}${GRY} — context ${pct}%, weekly ${wk}${R}"
  fi

  if   [ "$pct" -lt 50 ]; then bc=$GRN
  elif [ "$pct" -lt 75 ]; then bc=$YEL
  else bc=$RED; fi
  cc_bar_c "$bc" "$pct" 24
  head="${REPLY}  ${head}"

  cc_model_short
  l2="${D}${REPLY}${R}"
  [ -n "$CC_EFFORT" ] && l2="${l2}${dot}${D}${CC_EFFORT}${R}"
  if [ "$CC_IN_REPO" = "1" ]; then
    l2="${l2}${dot}${CYN}${CC_BRANCH}${R}"
    cc_dirty; d=$REPLY
    [ -n "$d" ] && l2="${l2} ${YEL}${d}${R}"
  fi
  [ -n "$CC_WT" ] && l2="${l2}${dot}${MAG}⑂ ${CC_WT}${R}"
  [ -n "$CC_PR" ] && l2="${l2}${dot}${GRY}PR #${CC_PR}${R}"
  if [ -n "$CC_COST" ]; then
    cc_money "$CC_COST"
    l2="${l2}${dot}${D}\$${REPLY}${R}"
  fi
  if [ -n "$CC_DUR_MS" ]; then
    cc_dur "$CC_DUR_MS"
    l2="${l2}${dot}${D}${REPLY}${R}"
  fi
  cc_path "$CC_CWD" 2
  l2="${l2}${dot}${D}${REPLY}${R}"

  printf '%s\n%s' "$head" "$l2"
}
