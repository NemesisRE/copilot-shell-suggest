#!/usr/bin/env zsh
script_dir=${0:A:h}
zmodload zsh/datetime
source "$script_dir/../copilot-shell-suggest.plugin.zsh"

assertEquals() { [[ "$1" == "$2" ]] || { print -u2 "expected '$1', got '$2'"; return 1; }; }
test_parse_fences() {
	local expected="echo hello
ls -la"
	assertEquals "$expected" "$(printf '```sh\necho hello\n$ ls -la\n```\n' | _copilot_suggest_parse)"
}
test_non_comment_falls_back() { BUFFER='ls'; zle() { [[ $1 == .expand-or-complete ]]; }; copilot-suggest-widget; }
test_empty_parse() { [[ -z "$(printf '```\n```\n' | _copilot_suggest_parse)" ]]; }
test_single_suggestion_replaces_buffer() {
	BUFFER='# describe'; _COPILOT_SUGGEST_ORIGINAL_BUFFER=$BUFFER
	zle() { [[ $1 == -M ]] && [[ $2 == 'No suggestions received' ]]; }
	_copilot_suggest_finish 'echo ready' 0
	assertEquals 'echo ready' "$BUFFER"
}
test_missing_copilot_preserves_buffer() {
	local old_path=$PATH
	PATH=/usr/bin:/bin; BUFFER='# describe'
	zle() { [[ $1 == -M ]] && [[ $2 == 'copilot not found in PATH' ]]; }
	copilot-suggest-widget
	PATH=$old_path
	assertEquals '# describe' "$BUFFER"
}
# regression: the callback must poll, never block the shell until EOF
test_callback_does_not_block() {
	local fd start elapsed
	zle() { return 0 }
	BUFFER=''
	exec {fd}< <(sleep 2; print 'ls -lS'; print '__COPILOT_SUGGEST_STATUS__:0')
	start=$EPOCHREALTIME
	_COPILOT_SUGGEST_FD=$fd
	_copilot_suggest_callback $fd
	elapsed=$(( EPOCHREALTIME - start ))
	(( elapsed < 1 )) || { print -u2 "callback blocked for ${elapsed}s"; return 1; }
	[[ -z $BUFFER ]] || { print -u2 "callback finished before data arrived"; return 1; }
	sleep 3
	_COPILOT_SUGGEST_FD=$fd
	_copilot_suggest_callback $fd
	assertEquals 'ls -lS' "$BUFFER"
}
test_parse_fences || exit 1
test_non_comment_falls_back || exit 1
test_empty_parse || exit 1
test_single_suggestion_replaces_buffer || exit 1
test_missing_copilot_preserves_buffer || exit 1
test_callback_does_not_block || exit 1
# tests above stub out the zle builtin; drop the stub so it can't leak if this file is ever sourced
unfunction zle 2>/dev/null
print 'zsh tests passed (mock parser/fallback; integration uses PATH stubs)'
