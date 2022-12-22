# For some reason it need this
source "$ZSH_CONFIG_PATH"/config.zsh
zstyle ':completion:*' matcher-list 'r:|?=** m:{a-z\-}={A-Z\_}'
zstyle ':completion:*' cache-path $ZDOTDIR
fpath+=($ZSH_CONFIG_PATH/completion)
setopt globdots
zshaddhistory() { return 1; }
# Using fzf-tab-git installed by pamac
source "$ZSH_CONFIG_PATH"/plugins/fzf-tab/fzf-tab.plugin.zsh
zstyle ':fzf-tab:*' query-string input first
# Override fzf-tab functions
-ftb-complete() {
  local -a _ftb_compcap
  local -Ua _ftb_groups
  local choice choices _ftb_curcontext continuous_trigger print_query accept_line bs=$'\2' nul=$'\0'
  local ret=0

  # must run with user options; don't move `emulate -L zsh` above this line
  (( $+builtins[fzf-tab-compcap-generate] )) && fzf-tab-compcap-generate -i
  COLUMNS=500 _ftb__main_complete "$@" || ret=$?
  (( $+builtins[fzf-tab-compcap-generate] )) && fzf-tab-compcap-generate -o

  emulate -L zsh -o extended_glob

  local _ftb_query _ftb_complist=() _ftb_headers=() command opts

  if [ -f "$ITLT_TMP_DIR/pos" ]; then
    local pos="$(cat "$ITLT_TMP_DIR/pos")"
    choice="$(sed "${pos}q;d" $ITLT_TMP_DIR/comp_list)"
    choice="${(@)${(@)choice%$nul*}#*$nul}"
    # echo choice $choice >>/tmp/debug
    # echo _ftb_compcap $_ftb_compcap >>/tmp/debug
    local -A v=("${(@0)${_ftb_compcap[(r)${(b)choice}$bs*]#*$bs}}")
    local -a args=("${(@ps:\1:)v[args]}")
    [[ -z $args[1] ]] && args=()  # don't pass an empty string
    IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX]
    builtin compadd "${args[@]:--Q}" -Q -- "$v[word]"

    compstate[list]=
    compstate[insert]='2'
    [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
    return $ret
  else
    -ftb-generate-complist # sets `_ftb_complist`
    -ftb-generate-query      # sets `_ftb_query`
    echo -n $_ftb_query >$ITLT_TMP_DIR/query
    echo -n "${LBUFFER%$_ftb_query}" >$ITLT_TMP_DIR/pre_query
    print -rl -- ${_ftb_complist} >$ITLT_TMP_DIR/comp
    echo -n 0 >$ITLT_TMP_DIR/comp_done.fifo
    return 1
  fi
}
fzf-tab-complete() {
  # this name must be ugly to avoid clashes
  local -i _ftb_continue=1 _ftb_accept=0 ret=0
  # hide the cursor until finishing completion, so that users won't see cursor up and down
  # NOTE: MacOS Terminal doesn't support civis & cnorm
  echoti civis >/dev/tty 2>/dev/null
  while (( _ftb_continue )); do
    _ftb_continue=0
    local IN_FZF_TAB=1
    {
      zle .fzf-tab-orig-$_ftb_orig_widget
      ret=$?
    } always {
      IN_FZF_TAB=0
    }
    if (( _ftb_continue )); then
      zle .split-undo
      zle .reset-prompt
      zle -R
      zle fzf-tab-dummy
    fi
  done
  echoti cnorm >/dev/tty 2>/dev/null
  zle .redisplay
  (( _ftb_accept )) && zle .accept-line
  if [ -f "$ITLT_TMP_DIR/pos" ]; then
    echo -n $LBUFFER >$ITLT_TMP_DIR/lbuffer
    echo -n 0 >$ITLT_TMP_DIR/lbuf_done.fifo
  fi
  return $ret
}
bindkey "^@" fzf-tab-complete
