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
$runDirectory = Join-Path $benchmarkRoot "results\$RunId"

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    throw 'Copilot CLI is not installed or is not on PATH.'
}
if (-not (Test-Path $skillSource)) {
    throw "Skill source not found: $skillSource"
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

function Get-TelemetryFacts([string]$Path, [string]$SkillName) {
    if (-not (Test-Path $Path)) {
        return @{ SkillInvoked = $false; InputTokens = 0; OutputTokens = 0; TotalTokens = 0 }
    }

    $skillInvoked = $false
    $inputTokens = 0
    $outputTokens = 0
    $totalTokens = 0
    foreach ($line in Get-Content $Path) {
        if ($line -match [regex]::Escape('github.copilot.skill.invoked') -and $line -match [regex]::Escape($SkillName)) {
            $skillInvoked = $true
        }
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
    return @{ SkillInvoked = $skillInvoked; InputTokens = $inputTokens; OutputTokens = $outputTokens; TotalTokens = $totalTokens }
}

foreach ($case in $cases) {
    for ($repetition = 1; $repetition -le $Repetitions; $repetition++) {
        $caseRunId = if ($Repetitions -eq 1) { $case.id } else { "$($case.id)-$repetition" }
        $caseDirectory = Join-Path $runDirectory $caseRunId
        $workspace = Join-Path $caseDirectory 'workspace'
        $otelPath = Join-Path $caseDirectory 'otel.jsonl'
        New-Item $workspace -ItemType Directory -Force | Out-Null
        Copy-Item (Join-Path $benchmarkRoot "fixtures\$($case.fixture)\*") $workspace -Recurse -Force
        $skillTarget = Join-Path $workspace '.github\skills\java-modernize-routing'
        New-Item $skillTarget -ItemType Directory -Force | Out-Null
        Copy-Item (Join-Path $skillSource 'SKILL.md') $skillTarget -Force

        $discoveryPath = Join-Path $caseDirectory 'skills.json'
        & copilot -C $workspace plugins list --kind skill --json 1> $discoveryPath 2> (Join-Path $caseDirectory 'discovery.stderr.txt')
        $discovery = Get-Content $discoveryPath -Raw | ConvertFrom-Json
        $repositorySkill = @($discovery.plugins | Where-Object {
            $_.name -eq $configuration.skillName -and $_.scope -eq 'repository' -and $_.source -eq 'project' -and $_.enabled
        })
        if ($LASTEXITCODE -ne 0 -or $repositorySkill.Count -ne 1) {
            throw "Skill discovery failed for case $caseRunId."
        }

        Write-Host "[$caseRunId] fixture=$($case.fixture) expected=$($case.expectedTrigger)"
        $previousOtelPath = $env:COPILOT_OTEL_FILE_EXPORTER_PATH
        $env:COPILOT_OTEL_FILE_EXPORTER_PATH = $otelPath
        try {
            $arguments = @(
                '-C', $workspace,
                '-p', $case.prompt,
                '--model', $Model,
                '--output-format', 'json',
                '--stream', 'off',
                '--available-tools', 'skill,glob,view',
                '--allow-all-tools',
                '--disable-builtin-mcps',
                '--no-custom-instructions',
                '--no-ask-user'
            )
            & copilot @arguments 1> (Join-Path $caseDirectory 'response.jsonl') 2> (Join-Path $caseDirectory 'stderr.txt')
            $exitCode = $LASTEXITCODE
        } finally {
            $env:COPILOT_OTEL_FILE_EXPORTER_PATH = $previousOtelPath
        }

        $facts = Get-TelemetryFacts $otelPath $configuration.skillName
        $status = if ($exitCode -eq 0) { 'completed' } else { 'cli-error' }
        $results.Add([pscustomobject][ordered]@{
            caseId = $case.id
            repetition = $repetition
            fixture = $case.fixture
            prompt = $case.prompt
            expectedTrigger = [bool]$case.expectedTrigger
            skillInvoked = [bool]$facts.SkillInvoked
            passed = $exitCode -eq 0 -and ([bool]$case.expectedTrigger -eq [bool]$facts.SkillInvoked)
            status = $status
            exitCode = $exitCode
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
