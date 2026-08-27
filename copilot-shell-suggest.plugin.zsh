# GitHub Copilot command suggestions for zsh ZLE.

zmodload -F zsh/system b:sysread

typeset -g COPILOT_SUGGEST_PREFIX=${COPILOT_SUGGEST_PREFIX:-#}
typeset -g COPILOT_SUGGEST_KEY=${COPILOT_SUGGEST_KEY:-'^I'}
typeset -g COPILOT_SUGGEST_TIMEOUT=${COPILOT_SUGGEST_TIMEOUT:-15}
typeset -g COPILOT_SUGGEST_MODEL=${COPILOT_SUGGEST_MODEL:-}
typeset -g COPILOT_SUGGEST_DENY_TOOL=${COPILOT_SUGGEST_DENY_TOOL:-shell}
typeset -g _COPILOT_SUGGEST_FD=-1
typeset -g _COPILOT_SUGGEST_ORIGINAL_BUFFER=''
typeset -g _COPILOT_SUGGEST_OUTPUT=''

_copilot_suggest_prompt() {
  print -r -- "Return only shell commands, one command per line. Do not explain anything. Do not use Markdown or code fences. Never execute a command. User request: $1"
}

_copilot_suggest_parse() {
  local line
  while IFS= read -r line; do
    line=${line//$'\r'/}
    [[ $line == '```'* || -z ${line//[[:space:]]/} ]] && continue
    [[ $line == '$ '* ]] && line=${line#\$ }
    [[ $line == '$' ]] && continue
    [[ -n ${line//[[:space:]]/} ]] && print -r -- "$line"
  done
}

_copilot_suggest_start() {
  local prompt=$1 timeout=$COPILOT_SUGGEST_TIMEOUT
  local model_args=()
  [[ -n $COPILOT_SUGGEST_MODEL ]] && model_args=(--model "$COPILOT_SUGGEST_MODEL")
  {
    copilot --deny-tool "$COPILOT_SUGGEST_DENY_TOOL" --no-ask-user --allow-all-tools -s "${model_args[@]}" -p "$(_copilot_suggest_prompt "$prompt")" &
    local copilot_pid=$!
    ( sleep "$timeout"; kill -0 "$copilot_pid" 2>/dev/null && kill "$copilot_pid" 2>/dev/null ) &
    local watchdog_pid=$!
    wait "$copilot_pid"; local exit_code=$?
    kill "$watchdog_pid" 2>/dev/null
    (( exit_code == 143 )) && exit_code=124
    print -r -- "__COPILOT_SUGGEST_STATUS__:$exit_code"
  } 2>&1
}

_copilot_suggest_finish() {
  local output=$1 exit_code=$2
  local suggestions=("${(@f)$(_copilot_suggest_parse <<< "$output")}")
  if (( exit_code == 124 )); then
    zle -M "Copilot timed out after ${COPILOT_SUGGEST_TIMEOUT}s"
  elif (( exit_code != 0 )); then
    zle -M "Copilot error (check 'copilot' login)"
  elif (( ${#suggestions} == 0 )); then
    zle -M 'No suggestions received'
  elif (( ${#suggestions} == 1 )); then
    BUFFER=$suggestions[1]; CURSOR=${#BUFFER}
  elif ! (( $+commands[fzf] )); then
    BUFFER=$suggestions[1]; CURSOR=${#BUFFER}
    zle -M 'Multiple suggestions: fzf not installed, using the first one'
  else
    local picker=fzf selected
    [[ -n $TMUX && $+commands[fzf-tmux] ]] && picker=fzf-tmux
    selected=$(printf '%s\n' "${suggestions[@]}" | command "$picker" --preview='printf "%s\n" {}' --height=40% --layout=reverse)
    if [[ -n $selected ]]; then
      BUFFER=$selected; CURSOR=${#BUFFER}
    else
      BUFFER=$_COPILOT_SUGGEST_ORIGINAL_BUFFER; CURSOR=${#BUFFER}
    fi
  fi
}

_copilot_suggest_callback() {
  local fd=$1 event=$2 chunk status_code
  # poll only what is ready; a blocking read here would freeze the whole shell
  while true; do
    sysread -i "$fd" -t 0 chunk 2>/dev/null
    status_code=$?
    (( status_code == 0 )) || break
    _COPILOT_SUGGEST_OUTPUT+=$chunk
  done
  # 5 is EOF; anything else non-zero besides 4 (no data yet) is a broken pipe
  if (( status_code == 4 )) && [[ -z $event ]]; then
    return
  fi
  zle -F "$fd"
  exec {fd}<&-
  _COPILOT_SUGGEST_FD=-1
  local raw=$_COPILOT_SUGGEST_OUTPUT exit_code=1 output
  if [[ $raw == *__COPILOT_SUGGEST_STATUS__:* ]]; then
    exit_code=${${raw##*__COPILOT_SUGGEST_STATUS__:}%%$'\n'*}
    output=${raw%%__COPILOT_SUGGEST_STATUS__:*}
  else
    output=$raw
  fi
  _COPILOT_SUGGEST_OUTPUT=''
  _copilot_suggest_finish "$output" "$exit_code"
  zle -R
}

copilot-suggest-widget() {
  if [[ $BUFFER != "$COPILOT_SUGGEST_PREFIX"* ]]; then
    zle .expand-or-complete
    return
  fi
  if ! (( $+commands[copilot] )); then
    zle -M "copilot not found in PATH"
    return
  fi
  if (( _COPILOT_SUGGEST_FD >= 0 )); then
    zle -M 'A Copilot suggestion is already running'
    return
  fi
  _COPILOT_SUGGEST_ORIGINAL_BUFFER=$BUFFER
  _COPILOT_SUGGEST_OUTPUT=''
  local request=${BUFFER#"$COPILOT_SUGGEST_PREFIX"}
  exec {_COPILOT_SUGGEST_FD}< <(_copilot_suggest_start "$request")
  zle -F "$_COPILOT_SUGGEST_FD" _copilot_suggest_callback
  zle -M 'Copilot is thinking...'
}

zle -N copilot-suggest-widget
bindkey "$COPILOT_SUGGEST_KEY" copilot-suggest-widget
