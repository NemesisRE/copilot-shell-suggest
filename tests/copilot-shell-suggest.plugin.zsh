#!/usr/bin/env zsh
script_dir=${0:A:h}
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
	zle() { [[ $1 == -M ]] && [[ $2 == 'Keine Vorschläge erhalten' ]]; }
	_copilot_suggest_finish 'echo ready' 0
	assertEquals 'echo ready' "$BUFFER"
}
test_missing_copilot_preserves_buffer() {
	local old_path=$PATH
	PATH=/usr/bin:/bin; BUFFER='# describe'
	zle() { [[ $1 == -M ]] && [[ $2 == 'copilot nicht im PATH gefunden' ]]; }
	copilot-suggest-widget
	PATH=$old_path
	assertEquals '# describe' "$BUFFER"
}
test_parse_fences || exit 1
test_non_comment_falls_back || exit 1
test_empty_parse || exit 1
test_single_suggestion_replaces_buffer || exit 1
test_missing_copilot_preserves_buffer || exit 1
print 'zsh tests passed (mock parser/fallback; integration uses PATH stubs)'
