ITLT_DIR=${0:A:h}

itlt_up() {
  if [[ $LBUF_CHANGED -eq 1 || $BUF_CHANGED -eq 1 ]]; then
    COMP_COUNT="$(cat $ITLT_TMP_DIR/comp_count)"
    HIST_COUNT="-$(cat $ITLT_TMP_DIR/hist_count)"
    LBUF_CHANGED=0
    BUF_CHANGED=0
  fi
  ITLT_POS=$(( (ITLT_POS-1)<HIST_COUNT?ITLT_POS:(ITLT_POS-1) ))
  _zsh_autosuggest_fetch
}
zle -N itlt_up
bindkey '^[[A' itlt_up
itlt_down() {
  if [[ $LBUF_CHANGED -eq 1 || $BUF_CHANGED -eq 1 ]]; then
    COMP_COUNT="$(cat $ITLT_TMP_DIR/comp_count)"
    HIST_COUNT="-$(cat $ITLT_TMP_DIR/hist_count)"
    LBUF_CHANGED=0
    BUF_CHANGED=0
  fi
  ITLT_POS=$(( (ITLT_POS+1)>(COMP_COUNT-1)?ITLT_POS:(ITLT_POS+1) ))
  _zsh_autosuggest_fetch
}
zle -N itlt_down
bindkey '^[[B' itlt_down
itlt_right() {
  if [ -f "$ITLT_TMP_DIR/pos" ]; then
    zmodload zsh/zpty
    local zpty_name=itlt
    zpty -d "$zpty_name" 2>/dev/null
    zpty "$zpty_name" zsh -f -i
    zpty -w "$zpty_name" "ZSH_CONFIG_PATH=$ZSH_CONFIG_PATH"
    zpty -w "$zpty_name" "ITLT_TMP_DIR=$ITLT_TMP_DIR"
    zpty -w "$zpty_name" "source $ITLT_DIR/lib/itlt_zpty.zsh"
    zpty -wn "$zpty_name" "$LBUFFER"$'\x00'
    read <$ITLT_TMP_DIR/lbuf_done.fifo
    LBUFFER="$(cat $ITLT_TMP_DIR/lbuffer)"
    zpty -d "$zpty_name" 2>/dev/null
    zle redisplay
  elif [ $ITLT_POS -lt 0 ]; then
    local pos=$((-ITLT_POS)) 
    # BUFFER="$(sed "${pos}q;d" $ITLT_TMP_DIR/hist_list | sed -e 's/^ [0-9]* *//g')"
    BUFFER="$(sed "${pos}q;d" $ITLT_TMP_DIR/hist_list)"
    CURSOR=$#BUFFER
    zle redisplay
  fi
}
zle -N itlt_right
bindkey '^I' itlt_right
itlt_left() {
  zle backward-kill-word
}
zle -N itlt_left
bindkey '^[[Z' itlt_left
itlt_accept() {
  if [ $ITLT_POS -lt 0 ]; then
    zle itlt_right
  fi
  zle accept-line
}
zle -N itlt_accept
bindkey '^M' itlt_accept
bindkey '^H' itlt_left
bindkey '^J' itlt_down
bindkey '^K' itlt_up
bindkey '^L' itlt_right
bindkey '^O' backward-delete-char

itlt_init() {
  # init_vars
  ITLT_TMP_DIR=/tmp/itlt_$USER/$$
  ITLT_POS=0
  ITLT_PAD_LEFT_OFFSET=2
  # ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=222'
  # ITLT_HIGHLIGHT_STYLE="bold,fg=229"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=006'
  ITLT_HIGHLIGHT_STYLE="bold,fg=003"
  # refresh_tmp_dir
  rm -rf $ITLT_TMP_DIR
  mkdir -p $ITLT_TMP_DIR # query, pre_query, comp, comp_list, pos, lbuffer
  echo -n "" >$ITLT_TMP_DIR/comp
  echo -n 0 >$ITLT_TMP_DIR/pos
  echo -n " " >$ITLT_TMP_DIR/pre_query
  echo -n "" >$ITLT_TMP_DIR/query
  mkfifo $ITLT_TMP_DIR/comp_done.fifo
  mkfifo $ITLT_TMP_DIR/lbuf_done.fifo
}
itlt_init
itlt_gen_comp() {
  rm -f $ITLT_TMP_DIR/pos
  zmodload zsh/zpty
  local zpty_name=itlt
  zpty -d "$zpty_name" 2>/dev/null
  zpty "$zpty_name" zsh -f -i
  zpty -w "$zpty_name" "ZSH_CONFIG_PATH=$ZSH_CONFIG_PATH"
  zpty -w "$zpty_name" "ITLT_TMP_DIR=$ITLT_TMP_DIR"
  zpty -w "$zpty_name" "source $ITLT_DIR/lib/itlt_zpty.zsh"
  local pre_query="$(echo -n $LBUFFER | sed -e 's/[a-zA-Z0-9_]*$//g')"
  zpty -wn "$zpty_name" "$pre_query"$'\x00'
  read <$ITLT_TMP_DIR/comp_done.fifo
  zpty -d "$zpty_name" 2>/dev/null
  echo itlt_gen_comp >>/tmp/debug
}
itlt_get_popup() {
  local maxrow_comp=5 maxrow_hist=3 maxrow=8
  if [ $ITLT_POS -eq 0 ]; then
    local abs_pos=$((ITLT_POS+1))
    local count="$(cat $ITLT_TMP_DIR/comp_count)"
    if [ $count -ne 0 ]; then
      echo -n $abs_pos >$ITLT_TMP_DIR/pos
    else
      rm -f $ITLT_TMP_DIR/pos
    fi
    echo
    {
      head -n $maxrow_comp $ITLT_TMP_DIR/comp_display
      while :; do 
        printf ' %.0s' {1.."$((COLUMNS-1))"}
        echo 
      done
    } | head -n $maxrow_comp # https://unix.stackexchange.com/a/302364
    {
      head -n $maxrow_hist $ITLT_TMP_DIR/hist_display | cut -c1-"$((COLUMNS-1))"
      while :; do 
        printf ' %.0s' {1.."$((COLUMNS-1))"}
        echo 
      done
    } | head -n $maxrow_hist | tac # https://unix.stackexchange.com/a/302364
  elif [ $ITLT_POS -gt 0 ]; then
    local count="$(cat $ITLT_TMP_DIR/comp_count)"
    if [ $count -ne 0 ]; then
      local abs_pos=$((ITLT_POS+1))
      echo -n $abs_pos >$ITLT_TMP_DIR/pos
      echo
      sed -n "$abs_pos,$((abs_pos+maxrow-1))p;$((abs_pos+maxrow))q" $ITLT_TMP_DIR/comp_display # https://stackoverflow.com/a/83347
    else
      rm -f $ITLT_TMP_DIR/pos
    fi
  elif [ $ITLT_POS -lt 0 ]; then
    local abs_pos=$((-ITLT_POS))
    rm -f $ITLT_TMP_DIR/pos
    echo
    {
      sed -n "$abs_pos,$((abs_pos+maxrow-1))p;$((abs_pos+maxrow))q" $ITLT_TMP_DIR/hist_display | cut -c1-"$((COLUMNS-1))" # https://stackoverflow.com/a/83347
      while :; do 
        printf ' %.0s' {1.."$((COLUMNS-1))"}
        echo 
      done
    } | head -n $maxrow | tac # https://unix.stackexchange.com/a/302364
  fi
}
itlt_precmd() {
  LBUF_CHANGED=1
  BUF_CHANGED=1
  ITLT_POS=0
  _zsh_autosuggest_fetch
}
add-zsh-hook precmd itlt_precmd
itlt_refresh() {
  itlt_gen_comp
  itlt_precmd
}
zle -N itlt_refresh
bindkey '^R' itlt_refresh
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(
  itlt_up
  itlt_down
  itlt_refresh
)

ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=()
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=()
ZSH_AUTOSUGGEST_STRATEGY=(itlt)
_zsh_autosuggest_strategy_itlt() {
  if [ $LBUF_CHANGED -eq 1 ]; then
    case ${LBUFFER: -1} in
      [a-zA-Z0-9_]) 
      ;;
      *)
      itlt_gen_comp
      ;;
    esac
    local pre_query="$(cat $ITLT_TMP_DIR/pre_query)"
    local query="$(cat $ITLT_TMP_DIR/query)"
    if [ ! "${LBUFFER#$pre_query}" = "$query" ]; then
      query="${LBUFFER#$pre_query}"
      echo -n $query >$ITLT_TMP_DIR/query
    fi
    local pad_left="$(printf ' %.0s' {1.."$(($#pre_query + $ITLT_PAD_LEFT_OFFSET))"})"
    local pad_right="$(printf ' %.0s' {1.."$((COLUMNS-1))"})"
    cat $ITLT_TMP_DIR/comp | fzf -f "$query" --ansi --tiebreak=begin,length --delimiter='\x00' --nth=2,3 >$ITLT_TMP_DIR/comp_list
    wc -l $ITLT_TMP_DIR/comp_list | awk '{ print $1 }' >$ITLT_TMP_DIR/comp_count # https://askubuntu.com/a/718156
    cat $ITLT_TMP_DIR/comp_list | sed -e 's/\x00//g' | sed -e "s/^/$pad_left/g" | sed -e "s/$/$pad_right/g" | cut -c1-"$((COLUMNS-1))" >$ITLT_TMP_DIR/comp_display
  fi
  if [ $BUF_CHANGED -eq 1 ]; then
    local pad_right="$(printf ' %.0s' {1.."$((COLUMNS-1))"})"
    # cat $HOME/.zhistory | fzf -f "$BUFFER" --tac --tiebreak=begin >$ITLT_TMP_DIR/hist_list
    cat $HISTFILE | fzf -f "$BUFFER" --tac --tiebreak=index | uniq >$ITLT_TMP_DIR/hist_list
    wc -l $ITLT_TMP_DIR/hist_list | awk '{ print $1 }' >$ITLT_TMP_DIR/hist_count # https://askubuntu.com/a/718156
    cat $ITLT_TMP_DIR/hist_list | sed -e "s/^/  /g" | sed -e "s/$/$pad_right/g" | cut -c1-"$((COLUMNS-1))" >$ITLT_TMP_DIR/hist_display
  fi
  typeset -g suggestion="$1$(itlt_get_popup)"
}
# Override zsh-autosuggestion functions
_zsh_autosuggest_highlight_reset() {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	typeset -g ITLT_HIGHLIGHT

	if [[ -n "$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT" || -n "$ITLT_HIGHLIGHT" ]]; then
		region_highlight=("${(@)region_highlight:#$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT}")
		region_highlight=("${(@)region_highlight:#$ITLT_HIGHLIGHT}")
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
		unset ITLT_HIGHLIGHT
	fi
}
_zsh_autosuggest_highlight_apply() {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	typeset -g ITLT_HIGHLIGHT

	if (( $#POSTDISPLAY )); then
		typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT="$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE"
    if [ $ITLT_POS -ge 0 ]; then
      typeset -g ITLT_HIGHLIGHT="$#BUFFER $(($#BUFFER + $COLUMNS)) $ITLT_HIGHLIGHT_STYLE"
    else
      typeset -g ITLT_HIGHLIGHT="$(($#BUFFER + COLUMNS*7)) $(($#BUFFER + COLUMNS*8)) $ITLT_HIGHLIGHT_STYLE"
    fi
		region_highlight+=("$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT")
		region_highlight+=("$ITLT_HIGHLIGHT")
	else
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
		unset ITLT_HIGHLIGHT
	fi
}
_zsh_autosuggest_suggest() {
	emulate -L zsh

	local suggestion="$1"

	# if [[ -n "$suggestion" ]] && (( $#BUFFER )); then
	# 	POSTDISPLAY="${suggestion#$BUFFER}"
	# else
	# 	unset POSTDISPLAY
	# fi
  POSTDISPLAY="${suggestion#$BUFFER}"
}
_zsh_autosuggest_modify() {
  local -i retval

  # Only available in zsh >= 5.4
  local -i KEYS_QUEUED_COUNT

  # Save the contents of the buffer/postdisplay
  local orig_lbuffer="$LBUFFER"
  local orig_buffer="$BUFFER"
  local orig_postdisplay="$POSTDISPLAY"

  # Clear suggestion while waiting for next one
  unset POSTDISPLAY

  # Original widget may modify the buffer
  _zsh_autosuggest_invoke_original_widget $@
  retval=$?

  emulate -L zsh

  # Don't fetch a new suggestion if there's more input to be read immediately
  if (( $PENDING > 0 || $KEYS_QUEUED_COUNT > 0 )); then
    POSTDISPLAY="$orig_postdisplay"
    return $retval
  fi

  # Optimize if manually typing in the suggestion or if buffer hasn't changed
  # if [[ "$BUFFER" = "$orig_buffer"* && "$orig_postdisplay" = "${BUFFER:$#orig_buffer}"* ]]; then
  # 	POSTDISPLAY="${orig_postdisplay:$(($#BUFFER - $#orig_buffer))}"
  # 	return $retval
  # fi
  if [[ "$LBUFFER" != "$orig_lbuffer" ]]; then
    LBUF_CHANGED=1
    ITLT_POS=0
  else
    LBUF_CHANGED=0
  fi
  if [[ "$BUFFER" != "$orig_buffer" ]]; then
    BUF_CHANGED=1
  else
    BUF_CHANGED=0
  fi

  # Bail out if suggestions are disabled
  if (( ${+_ZSH_AUTOSUGGEST_DISABLED} )); then
    return $?
  fi

  # Get a new suggestion if the buffer is not empty after modification
  # if (( $#BUFFER > 0 )); then
  # 	if [[ -z "$ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" ]] || (( $#BUFFER <= $ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE )); then
  # 		_zsh_autosuggest_fetch
  # 	fi
  # fi
  _zsh_autosuggest_fetch

  return $retval
}
