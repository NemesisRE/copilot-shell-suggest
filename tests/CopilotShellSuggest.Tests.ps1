BeforeAll { Import-Module "$PSScriptRoot/../CopilotShellSuggest.psm1" -Force }

Describe 'CopilotSuggest parser' {
    It 'removes markdown fences and prompts' {
        @(ConvertFrom-CopilotSuggestOutput "```sh`necho hi`n`$ ls`n```") | Should -Be @('echo hi', 'ls')
    }
    It 'returns no entries for empty output' {
        @(ConvertFrom-CopilotSuggestOutput '') | Should -BeNullOrEmpty
    }
}

Describe 'Copilot CLI contract' {
    It 'uses the safe flags' {
        Mock -CommandName copilot -ModuleName CopilotShellSuggest { 'echo ok' }
        $env:COPILOT_SUGGEST_DENY_TOOL = 'shell'
        $result = Invoke-CopilotSuggestCli 'list files'
        $result.ExitCode | Should -Be 0
        Should -Invoke copilot -ModuleName CopilotShellSuggest -ParameterFilter { $args -contains '--deny-tool' -and $args -contains 'shell' -and $args -contains '--no-ask-user' -and $args -contains '-s' }
    }

    It 'creates the background job without running it in the test process' {
        Mock -CommandName Start-Job -ModuleName CopilotShellSuggest { 'mock-job' }
        Start-CopilotSuggestJob 'list files' | Should -Be 'mock-job'
        Should -Invoke Start-Job -ModuleName CopilotShellSuggest
    }
}

Describe 'Suggestion selection' {
    It 'uses the first suggestion when fzf is unavailable in the caller' {
        Mock -CommandName Get-Command -ModuleName CopilotShellSuggest { $null }
        Mock -CommandName Read-Host -ModuleName CopilotShellSuggest { '' }
        Select-CopilotSuggestion @('echo first', 'echo second') | Should -BeNullOrEmpty
        Should -Invoke Read-Host -ModuleName CopilotShellSuggest
    }
}
