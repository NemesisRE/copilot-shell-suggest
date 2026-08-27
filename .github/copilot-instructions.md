# copilot-shell-suggest contributor instructions

- Keep the zsh and PowerShell prompt contract, Copilot safety flags, parsing rules, and error behavior equivalent.
- Never execute a suggested command or add a path that bypasses the user's explicit Enter action.
- Preserve the normal completion handler for non-trigger lines.
- Do not persist prompts, Copilot responses, or credentials.
- Add or update mock-based tests for behavior changes. Tests must never invoke the real `copilot` CLI.
- Run `zsh -f -n copilot-shell-suggest.plugin.zsh` and `zsh -f tests/copilot-shell-suggest.plugin.zsh` locally. Run Pester and PSScriptAnalyzer when PowerShell is available.
- Keep the project licensed under GPL-3.0-only and avoid adding unrelated generated files.
