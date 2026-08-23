# minimal — one line, only the facts that change what you do next.
# branch (with a * when dirty) · context % · weekly usage · spend

render() {
  local dot="${GRY} · ${R}" out="" pct bc sv c d

  if [ "$CC_IN_REPO" = "1" ]; then
    out="${CYN}${CC_BRANCH}${R}"
    cc_dirty; d=$REPLY
    [ -n "$d" ] && out="${out}${YEL}*${R}"
    [ "${CC_BEHIND:-0}" -gt 0 ] && out="${out}${RED}↓${CC_BEHIND}${R}"
  else
    cc_path "$CC_CWD" 1
    out="${D}${REPLY}${R}"
  fi

  cc_int "${CC_CTX_PCT:-0}"; pct=$REPLY
  if   [ "$pct" -lt 50 ]; then bc=$GRN
  elif [ "$pct" -lt 75 ]; then bc=$YEL
  else bc=$RED; fi
  out="${out}${dot}${bc}${pct}%${R}"

  if [ -n "$CC_7D" ]; then
    cc_sev "$CC_7D" 80 92; sv=$REPLY
    cc_sevcolor "$sv"; c=$REPLY
    cc_int "$CC_7D"
    out="${out}${dot}${c}7d ${REPLY}%${R}"
  fi
  if [ -n "$CC_COST" ]; then
    cc_money "$CC_COST"
    out="${out}${dot}${D}\$${REPLY}${R}"
  fi

  printf '%s' "$out"
}
