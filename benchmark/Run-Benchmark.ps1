[CmdletBinding()]
param(
    [string]$Model = 'auto',
    [int]$Repetitions = 1,
    [string[]]$CaseId,
    [string]$RunId = (Get-Date -Format 'yyyyMMdd-HHmmss')
)

$ErrorActionPreference = 'Stop'
$benchmarkRoot = $PSScriptRoot
$repoRoot = Split-Path $benchmarkRoot -Parent
$configuration = Get-Content (Join-Path $benchmarkRoot 'cases.json') -Raw | ConvertFrom-Json
$skillSource = Join-Path $repoRoot '.github\skills\java-modernize-routing'
$mockMcpServer = Join-Path $benchmarkRoot 'mock-mcp\server.mjs'
$runDirectory = Join-Path $benchmarkRoot "results\$RunId"

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    throw 'Copilot CLI is not installed or is not on PATH.'
}
if (-not (Test-Path $skillSource)) {
    throw "Skill source not found: $skillSource"
}
if (-not (Test-Path $mockMcpServer)) {
    throw "Mock MCP server not found: $mockMcpServer"
}
if ($Repetitions -lt 1) {
    throw 'Repetitions must be at least 1.'
}

$cases = @($configuration.cases)
if ($CaseId) {
    $cases = @($cases | Where-Object { $_.id -in $CaseId })
    $missing = @($CaseId | Where-Object { $_ -notin $cases.id })
    if ($missing.Count -gt 0) { throw "Unknown case ID(s): $($missing -join ', ')" }
}

New-Item $runDirectory -ItemType Directory -Force | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

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
            # Count chat spans only; parent agent spans already aggregate their children.
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
    # A recommendation is valid only when the model reproduces the VS Code choice contract.
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
    if (-not (Test-Path $Path)) {
        return $false
    }

    foreach ($line in Get-Content $Path) {
        try {
            $json = $line | ConvertFrom-Json
            # Use structured MCP execution events so response wording cannot satisfy the oracle.
            if ($json.type -ne 'tool.execution_start' -or
                $json.data.mcpServerName -ne 'vscode-question-benchmark' -or
                $json.data.mcpToolName -ne 'vscode_askQuestions') {
                continue
            }

            if (Test-QuestionArguments $json.data.arguments) {
                return $true
            }
        } catch {
            Write-Warning "Ignoring malformed response line in $Path"
        }
    }

    return $false
}

$mcpConfiguration = @{
    mcpServers = @{
        'vscode-question-benchmark' = @{
            type = 'local'
            command = 'node'
            args = @($mockMcpServer)
            tools = @('*')
        }
    }
} | ConvertTo-Json -Compress -Depth 6

foreach ($case in $cases) {
    for ($repetition = 1; $repetition -le $Repetitions; $repetition++) {
        $caseRunId = if ($Repetitions -eq 1) { $case.id } else { "$($case.id)-$repetition" }
        $caseDirectory = Join-Path $runDirectory $caseRunId
        $workspace = Join-Path $caseDirectory 'workspace'
        $otelPath = Join-Path $caseDirectory 'otel.jsonl'
        # Each run gets an isolated project and the exact skill version under test.
        New-Item $workspace -ItemType Directory -Force | Out-Null
        Copy-Item (Join-Path $benchmarkRoot "fixtures\$($case.fixture)\*") $workspace -Recurse -Force
        $skillTarget = Join-Path $workspace '.github\skills\java-modernize-routing'
        New-Item $skillTarget -ItemType Directory -Force | Out-Null
        Copy-Item (Join-Path $skillSource 'SKILL.md') $skillTarget -Force

        # Fail early if Copilot CLI does not discover the injected repository-scoped skill.
        $discoveryPath = Join-Path $caseDirectory 'skills.json'
        & copilot -C $workspace plugins list --kind skill --json 1> $discoveryPath 2> (Join-Path $caseDirectory 'discovery.stderr.txt')
        $discovery = Get-Content $discoveryPath -Raw | ConvertFrom-Json
        $repositorySkill = @($discovery.plugins | Where-Object {
            $_.name -eq $configuration.skillName -and $_.scope -eq 'repository' -and $_.source -eq 'project' -and $_.enabled
        })
        if ($LASTEXITCODE -ne 0 -or $repositorySkill.Count -ne 1) {
            throw "Skill discovery failed for case $caseRunId."
        }

        Write-Host "[$caseRunId] fixture=$($case.fixture) expectedRecommendation=$($case.expectedRecommendation)"
        # Scope the OTel destination to this process and restore the caller's environment afterward.
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
        $expectedRecommendation = [bool]$case.expectedRecommendation
        $actualRecommendation = Get-ActualRecommendation (Join-Path $caseDirectory 'response.jsonl')
        $status = if ($exitCode -eq 0) { 'completed' } else { 'cli-error' }
        # CLI failures never pass, even if partial output happens to match the expectation.
        $results.Add([pscustomobject][ordered]@{
            caseId = $case.id
            repetition = $repetition
            fixture = $case.fixture
            prompt = $case.prompt
            expectedRecommendation = $expectedRecommendation
            actualRecommendation = $actualRecommendation
            passed = $exitCode -eq 0 -and ($expectedRecommendation -eq $actualRecommendation)
            status = $status
            exitCode = $exitCode
            invocationError = $invocationError
            inputTokens = $facts.InputTokens
            outputTokens = $facts.OutputTokens
            totalTokens = $facts.TotalTokens
            artifacts = $caseRunId
        })
    }
}

$summary = [ordered]@{
    runId = $RunId
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    model = $Model
    repetitions = $Repetitions
    skillName = $configuration.skillName
    results = $results
}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $runDirectory 'summary.json') -Encoding utf8
& (Join-Path $benchmarkRoot 'New-BenchmarkReport.ps1') -RunDirectory $runDirectory
Write-Host "Artifacts: $runDirectory"
