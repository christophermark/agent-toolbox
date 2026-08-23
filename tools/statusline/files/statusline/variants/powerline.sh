# powerline — single line, filled segments with  transitions.
# Needs a Nerd Font / Powerline-patched font in the terminal. Falls back to
# plain separators when CC_NO_GLYPHS=1.

render() {
  local SEP THIN out="" prev="" pct bc sv d ab t1 fastglyph toksuffix bgs fgs
  if [ "${CC_NO_GLYPHS:-0}" = "1" ]; then SEP=""; THIN="|"; else SEP=$''; THIN=$''; fi

  # bg/fg helpers: 256-colour palette (assign REPLY instead of printing)
  bg() { printf -v REPLY '\033[48;5;%sm' "$1"; }
  fg() { printf -v REPLY '\033[38;5;%sm' "$1"; }

  # push segment: $1 bg colour  $2 fg colour  $3 text
  push() {
    local b="$1" f="$2" t="$3"
    if [ -n "$prev" ]; then
      bg "$b"; bgs=$REPLY
      fg "$prev"; fgs=$REPLY
      out="${out}${bgs}${fgs}${SEP}"
    else
      bg "$b"; out="${out}${REPLY}"
    fi
    fg "$f"; out="${out}${REPLY} ${t} "
    prev="$b"
  }

  cc_model_short; t1=$REPLY
  fastglyph=""
  [ "$CC_FAST" = "true" ] && fastglyph=" ⚡"
  push 24 231 "${t1}${CC_EFFORT:+ ${CC_EFFORT}}${fastglyph}"

  if [ "$CC_IN_REPO" = "1" ]; then
    cc_dirty; d=$REPLY
    cc_ab; ab=$REPLY
    if [ -n "$d" ]; then push 130 231 "${CC_BRANCH}${ab:+ $ab} ${d}"
    else                push 22  231 "${CC_BRANCH}${ab:+ $ab}"; fi
  else
    cc_path "$CC_CWD" 1
    push 238 231 "$REPLY"
  fi

  [ -n "$CC_WT" ] && push 54 231 "⑂ ${CC_WT}"
  [ -n "$CC_PR" ] && push 60 231 "#${CC_PR}"

  cc_int "${CC_CTX_PCT:-0}"; pct=$REPLY
  if   [ "$pct" -lt 50 ]; then bc=28
  elif [ "$pct" -lt 75 ]; then bc=136
  else bc=124; fi
  toksuffix=""
  if [ -n "$CC_CTX_TOK" ]; then cc_tokens "$CC_CTX_TOK"; toksuffix=" $REPLY"; fi
  push "$bc" 231 "${pct}%${toksuffix}"

  if [ -n "$CC_COST" ]; then
    cc_money "$CC_COST"
    push 240 231 "\$${REPLY}"
  fi

  if [ -n "$CC_7D" ]; then
    cc_sev "$CC_7D" 80 92; sv=$REPLY
    case "$sv" in crit) bc=124 ;; warn) bc=136 ;; *) bc=236 ;; esac
    cc_int "$CC_7D"
    push "$bc" 231 "7d ${REPLY}%"
  fi

  # close the last segment: reset bg first, keep fg so the final arrow blends out
  fg "$prev"
  out="${out}${R}${REPLY}${SEP}${R}"

  # width-fit the whole line. If the cut lands mid-segment the trailing bg/fg
  # codes for that segment are simply dropped — the line ends in a bare ${R}
  # from cc_fit instead of a closed arrow, so no colour bleeds past the cut.
  cc_width; local width=$REPLY
  cc_fit "$out" "$width"; out=$REPLY

  printf '%s' "$out"
}
