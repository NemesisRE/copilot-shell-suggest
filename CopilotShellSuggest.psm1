Set-StrictMode -Version Latest

$script:OriginalTabHandler = $null
$script:ModuleRoot = $PSScriptRoot

function Get-CopilotSuggestPrompt {
    param([string]$Request)
    "Return only shell commands, one command per line. Do not explain anything. Do not use Markdown or code fences. Never execute a command. User request: $Request"
}

function ConvertFrom-CopilotSuggestOutput {
    param([AllowEmptyString()][string]$Output)
    @($Output -split "`n" | ForEach-Object {
            $line = $_.TrimEnd("`r")
            if ($line -and $line -notmatch '^```') {
                if ($line -match '^\$\s+') { $line = $line -replace '^\$\s+', '' }
                if ($line -ne '$' -and $line.Trim()) { $line }
            }
        })
}

function Invoke-CopilotSuggestCli {
    param([string]$Request)
    $arguments = @('--deny-tool', $env:COPILOT_SUGGEST_DENY_TOOL, '--no-ask-user', '-s')
    if ($env:COPILOT_SUGGEST_MODEL) { $arguments += @('--model', $env:COPILOT_SUGGEST_MODEL) }
    $arguments += (Get-CopilotSuggestPrompt $Request)
    try {
        $global:LASTEXITCODE = 0
        $output = & copilot @arguments 2>&1 | Out-String
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } catch {
        [pscustomobject]@{ ExitCode = 127; Output = $_.Exception.Message }
    }
}

function Start-CopilotSuggestJob {
    param([string]$Request)
    $modulePath = $script:ModuleRoot
    Start-Job -ScriptBlock {
        param($Path, $Value)
        Import-Module $Path -Force
        Invoke-CopilotSuggestCli $Value
    } -ArgumentList $modulePath, $Request
}

function Invoke-CopilotSuggestFallback {
    if ($script:OriginalTabHandler -is [scriptblock]) { & $script:OriginalTabHandler }
    else { [Microsoft.PowerShell.PSConsoleReadLine]::TabCompleteNext() }
}

function Select-CopilotSuggestion {
    param([string[]]$Suggestions)
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        return ($Suggestions | & fzf --preview 'Write-Output {}' --height=40% --layout=reverse)
    }
    Write-Host 'Mehrere Vorschläge; fzf fehlt.'
    for ($index = 0; $index -lt $Suggestions.Count; $index++) { Write-Host ("{0}: {1}" -f ($index + 1), $Suggestions[$index]) }
    $choice = Read-Host 'Nummer wählen (Abbruch mit Enter)'
    if ($choice -match '^[1-9]\d*$' -and [int]$choice -le $Suggestions.Count) { $Suggestions[[int]$choice - 1] }
}

function Invoke-CopilotSuggestWidget {
    $line = ''; $cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    $prefix = if ($env:COPILOT_SUGGEST_PREFIX) { $env:COPILOT_SUGGEST_PREFIX } else { '#' }
    if (-not $line.StartsWith($prefix)) { Invoke-CopilotSuggestFallback; return }
    if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) { Write-Host 'copilot nicht im PATH gefunden'; return }

    $originalLine = $line
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Copilot denkt nach...')
    $job = Start-CopilotSuggestJob ($line.Substring($prefix.Length))
    $timeout = if ($env:COPILOT_SUGGEST_TIMEOUT) { [int]$env:COPILOT_SUGGEST_TIMEOUT } else { 15 }
    $deadline = [datetime]::UtcNow.AddSeconds($timeout)
    while ($job.State -in @('NotStarted', 'Running') -and [datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
    if ($job.State -in @('NotStarted', 'Running')) {
        Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine(); [Microsoft.PowerShell.PSConsoleReadLine]::Insert($originalLine)
        Write-Host "Copilot timeout nach ${timeout}s"; return
    }
    $result = Receive-Job $job -ErrorAction SilentlyContinue | Select-Object -Last 1
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine(); [Microsoft.PowerShell.PSConsoleReadLine]::Insert($originalLine)
    if (-not $result -or $result.ExitCode -ne 0) { Write-Host "Copilot-Fehler (Anmeldung mit 'copilot' prüfen)"; return }
    $suggestions = @(ConvertFrom-CopilotSuggestOutput $result.Output)
    if ($suggestions.Count -eq 0) { Write-Host 'Keine Vorschläge erhalten'; return }
    $selected = if ($suggestions.Count -eq 1) { $suggestions[0] } else { Select-CopilotSuggestion $suggestions }
    if ($selected) { [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine(); [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected) }
}

function Enable-CopilotSuggest {
    if (-not (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue)) { return }
    $key = if ($env:COPILOT_SUGGEST_KEY) { $env:COPILOT_SUGGEST_KEY } else { 'Tab' }
    $handler = Get-PSReadLineKeyHandler -Key $key -ErrorAction SilentlyContinue
    $script:OriginalTabHandler = if ($handler) { $handler.Function } else { $null }
    Set-PSReadLineKeyHandler -Key $key -ScriptBlock { Invoke-CopilotSuggestWidget }
}

Export-ModuleMember -Function Enable-CopilotSuggest, Invoke-CopilotSuggestWidget, ConvertFrom-CopilotSuggestOutput, Invoke-CopilotSuggestCli, Select-CopilotSuggestion, Start-CopilotSuggestJob
Enable-CopilotSuggest
