@{
    Severity = @('Warning', 'Error')
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseApprovedVerbs',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace'
    )
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
    }
}
