# dense — two lines, maximum signal.
#   line 1  WHO and WHERE : model · effort · fast · thinking | repo/branch state | PR | worktree
#   line 2  WHAT IT COSTS : context bar + tokens/window | $ | lines | elapsed | 5h/7d with reset

render() {
  local dot="${GRY} · ${R}" gap="${GRY}   ${R}" l1="" l2="" seg pct bc sv c d ab tok1 tok2

  # ── line 1 ────────────────────────────────────────────────────────────────
  cc_model_short
  l1="${WHT}${B}${REPLY}${R}"
  [ -n "$CC_EFFORT" ]         && l1="${l1}${dot}${MAG}${CC_EFFORT}${R}"
  [ "$CC_FAST" = "true" ]     && l1="${l1}${dot}${YEL}fast${R}"
  [ "$CC_THINKING" = "false" ] && l1="${l1}${dot}${GRY}no-think${R}"
  [ -n "$CC_STYLE" ] && [ "$CC_STYLE" != "default" ] && l1="${l1}${dot}${BLU}${CC_STYLE}${R}"
  [ -n "$CC_AGENT" ]          && l1="${l1}${dot}${CYN}@${CC_AGENT}${R}"
  [ -n "$CC_VIM" ]            && l1="${l1}${dot}${GRY}${CC_VIM}${R}"

  # place: the CHECKOUT DIRECTORY name, then branch state.
  # Deliberately not workspace.repo.name — that comes from the remote URL, so two
  # clones of the same GitHub repo render identically, which is exactly when you
  # most need to tell them apart. Falls back to the cwd's last segment outside a repo.
  if [ -n "$CC_ROOT" ]; then
    cc_path "$CC_ROOT" 1; seg=$REPLY
  else
    cc_path "$CC_CWD" 1; seg=$REPLY
  fi
  l1="${l1}${gap}${D}${seg}${R}"
  if [ "$CC_IN_REPO" = "1" ]; then
    l1="${l1} ${CYN}${CC_BRANCH}${R}"
    cc_ab; ab=$REPLY
    [ -n "$ab" ] && l1="${l1} ${BLU}${ab}${R}"
    cc_dirty; d=$REPLY
    if [ -n "$d" ]; then l1="${l1} ${YEL}${d}${R}"; else l1="${l1} ${GRN}✓${R}"; fi
  fi
  [ -n "$CC_WT" ] && l1="${l1}${gap}${MAG}⑂ ${CC_WT}${R}"
  if [ -n "$CC_PR" ]; then
    case "$CC_PR_STATE" in
      APPROVED)          l1="${l1}${gap}${GRN}PR #${CC_PR} ✓${R}" ;;
      CHANGES_REQUESTED) l1="${l1}${gap}${RED}PR #${CC_PR} ✗${R}" ;;
      *)                 l1="${l1}${gap}${GRY}PR #${CC_PR}${R}" ;;
    esac
  fi
  [ "${CC_ADDED_DIRS:-0}" -gt 0 ] 2>/dev/null && l1="${l1}${gap}${GRY}+${CC_ADDED_DIRS} dir${R}"

  # ── line 2 ────────────────────────────────────────────────────────────────
  if [ -n "$CC_CTX_PCT" ]; then
    cc_int "$CC_CTX_PCT"; pct=$REPLY
    if   [ "$pct" -lt 50 ]; then bc=$GRN
    elif [ "$pct" -lt 75 ]; then bc=$YEL
    else bc=$RED; fi
    cc_bar_c "$bc" "$pct" 16
    l2="${REPLY} ${bc}${B}${pct}%${R}"
    if [ -n "$CC_CTX_TOK" ]; then
      cc_tokens "$CC_CTX_TOK"; tok1=$REPLY
      cc_tokens "$CC_CTX_SIZE"; tok2=$REPLY
      l2="${l2} ${D}${tok1}/${tok2}${R}"
    fi
  else
    l2="${D}context n/a${R}"
  fi

  if [ -n "$CC_COST" ]; then
    cc_money "$CC_COST"
    l2="${l2}${gap}${YEL}\$${REPLY}${R}"
  fi
  if [ "${CC_ADDED:-0}" != "0" ] || [ "${CC_REMOVED:-0}" != "0" ]; then
    l2="${l2}${gap}${GRN}+${CC_ADDED}${R}${GRY}/${R}${RED}-${CC_REMOVED}${R}"
  fi
  if [ -n "$CC_DUR_MS" ]; then
    cc_dur "$CC_DUR_MS"
    l2="${l2}${gap}${GRY}${REPLY}${R}"
  fi
  cc_burn
  [ -n "$REPLY" ] && l2="${l2}${gap}${GRY}${REPLY}${R}"

  for w in "5h:$CC_5H:$CC_5H_RESET:75:85" "7d:$CC_7D:$CC_7D_RESET:80:92" "7dO:$CC_7D_OPUS::80:92"; do
    local lbl p rst wa cr r
    lbl=${w%%:*};  w=${w#*:}
    p=${w%%:*};    w=${w#*:}
    rst=${w%%:*};  w=${w#*:}
    wa=${w%%:*};   cr=${w#*:}
    [ -n "$p" ] || continue
    cc_sev "$p" "$wa" "$cr"; sv=$REPLY
    cc_sevcolor "$sv"; c=$REPLY
    cc_int "$p"
    l2="${l2}${gap}${c}${lbl} ${REPLY}%${R}"
    if [ -n "$rst" ]; then
      cc_reset_in "$rst"; r=$REPLY
      [ -n "$r" ] && l2="${l2}${GRY} ⟳${r}${R}"
    fi
  done

  # width-fit both lines to the terminal; cc_width returns 0 (disabled) when
  # COLUMNS isn't a usable positive int, in which case cc_fit is a no-op.
  cc_width; local width=$REPLY
  cc_fit "$l1" "$width"; l1=$REPLY
  cc_fit "$l2" "$width"; l2=$REPLY

  printf '%s\n%s' "$l1" "$l2"
}
