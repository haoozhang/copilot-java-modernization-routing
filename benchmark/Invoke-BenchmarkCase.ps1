[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CaseJson,

    [Parameter(Mandatory)]
    [int]$Repetition,

    [Parameter(Mandatory)]
    [string]$CaseRunId,

    [Parameter(Mandatory)]
    [string]$RunDirectory,

    [Parameter(Mandatory)]
    [string]$BenchmarkRoot,

    [Parameter(Mandatory)]
    [string]$SkillSource,

    [Parameter(Mandatory)]
    [string]$SkillName,

    [Parameter(Mandatory)]
    [string]$MockMcpServer,

    [Parameter(Mandatory)]
    [string]$Model
)

$ErrorActionPreference = 'Stop'
$case = $CaseJson | ConvertFrom-Json
$caseDirectory = Join-Path $RunDirectory $CaseRunId
$resultPath = Join-Path $caseDirectory 'result.json'

function Get-TelemetryFacts([string]$Path) {
    if (-not (Test-Path $Path)) {
        return @{ InputTokens = 0; OutputTokens = 0; TotalTokens = 0 }
    }

    $inputTokens = 0
    $outputTokens = 0
    $totalTokens = 0
    foreach ($line in Get-Content $Path) {
        try {
            $json = $line | ConvertFrom-Json
            if ($json.attributes.'gen_ai.operation.name' -eq 'chat') {
                $inputTokens += [int64]$json.attributes.'gen_ai.usage.input_tokens'
                $outputTokens += [int64]$json.attributes.'gen_ai.usage.output_tokens'
                $totalTokens += [int64]$json.attributes.'gen_ai.usage.total_tokens'
            }
        } catch {
            Write-Warning "Ignoring malformed telemetry line in $Path"
        }
    }
    if ($totalTokens -eq 0) { $totalTokens = $inputTokens + $outputTokens }
    return @{ InputTokens = $inputTokens; OutputTokens = $outputTokens; TotalTokens = $totalTokens }
}

function Test-QuestionArguments($Arguments) {
    $questions = @($Arguments.questions)
    if ($questions.Count -ne 1) { return $false }

    $question = $questions[0]
    if ($question.allowFreeformInput -ne $false -or $question.multiSelect -eq $true) { return $false }

    $options = @($question.options)
    return $options.Count -eq 2 -and
        $options[0].label -eq 'Use GitHub Copilot modernization extension' -and
        $options[0].recommended -eq $true -and
        $options[1].label -eq 'Continue in the current chat'
}

function Get-ActualRecommendation([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }

    foreach ($line in Get-Content $Path) {
        try {
            $json = $line | ConvertFrom-Json
            if ($json.type -ne 'tool.execution_start' -or
                $json.data.mcpServerName -ne 'vscode-question-benchmark' -or
                $json.data.mcpToolName -ne 'vscode_askQuestions') {
                continue
            }

            if (Test-QuestionArguments $json.data.arguments) { return $true }
        } catch {
            Write-Warning "Ignoring malformed response line in $Path"
        }
    }

    return $false
}

function Write-Result(
    [string]$Status,
    [int]$ExitCode,
    [string]$InvocationError,
    [bool]$ActualRecommendation,
    $Facts
) {
    $expectedRecommendation = [bool]$case.expectedRecommendation
    $result = [pscustomobject][ordered]@{
        caseId = $case.id
        repetition = $Repetition
        fixture = $case.fixture
        prompt = $case.prompt
        expectedRecommendation = $expectedRecommendation
        actualRecommendation = $ActualRecommendation
        passed = $Status -eq 'completed' -and ($expectedRecommendation -eq $ActualRecommendation)
        status = $Status
        exitCode = $ExitCode
        invocationError = $InvocationError
        inputTokens = $Facts.InputTokens
        outputTokens = $Facts.OutputTokens
        totalTokens = $Facts.TotalTokens
        artifacts = $CaseRunId
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content $resultPath -Encoding utf8
}

try {
    $workspace = Join-Path $caseDirectory 'workspace'
    $otelPath = Join-Path $caseDirectory 'otel.jsonl'
    New-Item $workspace -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $BenchmarkRoot "fixtures\$($case.fixture)\*") $workspace -Recurse -Force
    $skillTarget = Join-Path $workspace '.github\skills\java-modernize-routing'
    New-Item $skillTarget -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $SkillSource 'SKILL.md') $skillTarget -Force

    $discoveryPath = Join-Path $caseDirectory 'skills.json'
    & copilot -C $workspace plugins list --kind skill --json 1> $discoveryPath 2> (Join-Path $caseDirectory 'discovery.stderr.txt')
    $discoveryExitCode = $LASTEXITCODE
    $discovery = Get-Content $discoveryPath -Raw | ConvertFrom-Json
    $repositorySkill = @($discovery.plugins | Where-Object {
        $_.name -eq $SkillName -and $_.scope -eq 'repository' -and $_.source -eq 'project' -and $_.enabled
    })
    if ($discoveryExitCode -ne 0 -or $repositorySkill.Count -ne 1) {
        throw "Skill discovery failed for case $CaseRunId."
    }

    Write-Output "[$CaseRunId] fixture=$($case.fixture) expectedRecommendation=$($case.expectedRecommendation)"
    $mcpConfiguration = @{
        mcpServers = @{
            'vscode-question-benchmark' = @{
                type = 'local'
                command = 'node'
                args = @($MockMcpServer)
                tools = @('*')
            }
        }
    } | ConvertTo-Json -Compress -Depth 6

    $previousOtelPath = $env:COPILOT_OTEL_FILE_EXPORTER_PATH
    $env:COPILOT_OTEL_FILE_EXPORTER_PATH = $otelPath
    $invocationError = $null
    try {
        $arguments = @(
            '-C', $workspace,
            '-p', $case.prompt,
            '--model', $Model,
            '--output-format', 'json',
            '--stream', 'off',
            '--available-tools', 'skill,glob,view,vscode-question-benchmark-vscode_askQuestions',
            '--additional-mcp-config', $mcpConfiguration,
            '--allow-all-tools',
            '--disable-builtin-mcps',
            '--no-custom-instructions',
            '--no-ask-user'
        )
        & copilot @arguments 1> (Join-Path $caseDirectory 'response.jsonl') 2> (Join-Path $caseDirectory 'stderr.txt')
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = -1
        $invocationError = $_.Exception.Message
        Add-Content (Join-Path $caseDirectory 'stderr.txt') $invocationError
    } finally {
        $env:COPILOT_OTEL_FILE_EXPORTER_PATH = $previousOtelPath
    }

    $facts = Get-TelemetryFacts $otelPath
    $actualRecommendation = Get-ActualRecommendation (Join-Path $caseDirectory 'response.jsonl')
    $status = if ($exitCode -eq 0) { 'completed' } else { 'cli-error' }
    Write-Result $status $exitCode $invocationError $actualRecommendation $facts
} catch {
    New-Item $caseDirectory -ItemType Directory -Force | Out-Null
    $infrastructureError = $_.Exception.Message
    Add-Content (Join-Path $caseDirectory 'stderr.txt') $infrastructureError
    Write-Result 'infrastructure-error' -1 $infrastructureError $false @{
        InputTokens = 0
        OutputTokens = 0
        TotalTokens = 0
    }
}