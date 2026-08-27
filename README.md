# Copilot Shell Suggest (CSS)

[![Tests](https://github.com/NemesisRE/copilot-shell-suggest/actions/workflows/tests.yml/badge.svg)](https://github.com/NemesisRE/copilot-shell-suggest/actions/workflows/tests.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/License-GPL--3.0--only-blue.svg)](https://github.com/NemesisRE/copilot-shell-suggest/blob/main/LICENSE)
[![zsh](https://img.shields.io/badge/zsh-5.8%2B-89e051.svg)](https://www.zsh.org/)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg)](https://learn.microsoft.com/powershell/)

## Overview

Copilot Shell Suggest brings natural-language command suggestions directly into interactive shell sessions. Type a request as a comment, press Tab, and let the GitHub Copilot CLI suggest one or more shell commands. The selected command is placed into the current command-line buffer for review; it is never executed automatically.

The project provides the same behavior for zsh and PowerShell while respecting each shell's native completion system. It is useful when you know what you want to accomplish but do not remember the exact command or its options. For example, type `# find the five largest files`, press Tab, review the result, and then press Enter only when you are satisfied.

ZLE widget for zsh and a PSReadLine key handler for PowerShell. Both send a description beginning with `#` to the GitHub Copilot CLI and insert a selected suggestion as **text in the buffer**. Example: `# find large files` + Tab -> `find . -size +100M`; pressing Enter remains an explicit user action.

Demo placeholder: `# list the five largest files` -> `[find ...] [du ...]` -> fzf selection -> buffer, never automatic execution.

## Requirements

- GitHub Copilot CLI (`copilot`) installed and authenticated, with an active Copilot subscription.
- `fzf` recommended. Without fzf, zsh inserts the first result for multiple suggestions; PowerShell offers a numbered selection.
- zsh 5.8 or newer for modern ZLE file handlers and stable parameter expansion.
- PowerShell 7+ and PSReadLine 2.2+. Older PSReadLine versions do not fully support ScriptBlock parameters for `Set-PSReadLineKeyHandler`.
- PowerShell on Windows uses the same native `copilot` invocation; the CLI requires Node.js >= 22.

## zsh Installation

```zsh
git clone https://github.com/NemesisRE/copilot-shell-suggest.git ~/.zsh/copilot-shell-suggest
source ~/.zsh/copilot-shell-suggest/copilot-shell-suggest.plugin.zsh
```

Oh My Zsh: clone into `$ZSH_CUSTOM/plugins/copilot-shell-suggest/` and add `copilot-shell-suggest` to `plugins=(...)`.

Sheldon (`~/.config/sheldon/plugins.toml`):

```toml
[plugins.copilot-shell-suggest]
github = "NemesisRE/copilot-shell-suggest"
dir = "copilot-shell-suggest"
apply = ["source"]
```

Then run `sheldon lock --update`. Alternatives: zplug `zplug "NemesisRE/copilot-shell-suggest"`, Antigen `antigen bundle NemesisRE/copilot-shell-suggest`, or Zinit `zinit light NemesisRE/copilot-shell-suggest`.

## PowerShell Installation

```powershell
$moduleDir = Join-Path ($env:PSModulePath -split [IO.Path]::PathSeparator | Select-Object -First 1) 'CopilotShellSuggest'
New-Item -ItemType Directory -Force $moduleDir | Out-Null
Copy-Item ./CopilotShellSuggest.psm1 $moduleDir
Import-Module CopilotShellSuggest
```

Add `Import-Module CopilotShellSuggest` to `$PROFILE` to load it automatically. Publishing a PowerShell Gallery module is a possible future distribution option, but is outside the core project.

## Differences

zsh registers a real `zle -F` file-descriptor callback and does not block input. PSReadLine key handlers have no equivalent callback: PowerShell starts a background job, displays a placeholder, and polls it at short intervals. This is asynchronous with respect to the Copilot process, but the active key handler remains occupied until completion or timeout. Without fzf, PowerShell uses a numbered `Read-Host` selection because it is a useful interactive Windows fallback; zsh deliberately inserts the first suggestion.

## Configuration

| Variable | Default | Meaning |
| --- | ---: | --- |
| `COPILOT_SUGGEST_PREFIX` | `#` | Trigger prefix |
| `COPILOT_SUGGEST_KEY` | zsh `^I`, PS `Tab` | Key binding |
| `COPILOT_SUGGEST_TIMEOUT` | `15` | Timeout in seconds |
| `COPILOT_SUGGEST_MODEL` | empty | Optional model passed to `--model` |
| `COPILOT_SUGGEST_DENY_TOOL` | `shell` | Copilot tool to deny |

PowerShell uses the same names through `$env:COPILOT_SUGGEST_*`. `FZF_DEFAULT_OPTS` is preserved; preview and layout are passed as additional options.

## Security and Limitations

Every trigger sends the text after the prefix to GitHub/Copilot. Prompts and responses are not stored on disk. `--deny-tool shell` prevents Copilot from executing shell actions itself. The suggested command is still executed by the user, so review it before pressing Enter; the plugin guarantees neither correctness nor safety. No code path presses Enter automatically.

Requests may count against the user's Copilot quota. Limits depend on the plan, so consult the current GitHub documentation. Node startup and network access typically add 1-3 seconds of latency. There is no live or ghost-text autosuggest. Errors, timeouts, and empty responses leave the comment buffer unchanged. `COPILOT_SUGGEST_DENY_TOOL` can be overridden, but should only be changed deliberately.

## Tests

The zsh tests intentionally use a small shunit2-compatible pattern without network access; `tests/copilot-shell-suggest.plugin.zsh` can be run directly or integrated with zunit. Pester is the standard PowerShell test framework:

```zsh
zsh tests/copilot-shell-suggest.plugin.zsh
```

```powershell
Invoke-Pester ./tests/CopilotShellSuggest.Tests.ps1
```

The tests mock the Copilot invocation or validate the parser and flag contract. A full interactive ZLE/PSReadLine session is intentionally not part of CI; `copilot`, `fzf`, and job functions can be injected through PATH or Pester mocks for integration testing.

## License

GPL-3.0-only. See [LICENSE](LICENSE).
