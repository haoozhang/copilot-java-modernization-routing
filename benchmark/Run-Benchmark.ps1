[CmdletBinding()]
param(
    [string]$Model = 'auto',
    [int]$Repetitions = 1,
    [string[]]$CaseId,
    [string]$RunId = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    [ValidateRange(1, 8)]
    [int]$ThrottleLimit = 2
)

$ErrorActionPreference = 'Stop'
$benchmarkRoot = $PSScriptRoot
$repoRoot = Split-Path $benchmarkRoot -Parent
$configuration = Get-Content (Join-Path $benchmarkRoot 'cases.json') -Raw | ConvertFrom-Json
$skillSource = Join-Path $repoRoot '.github\skills\java-modernize-routing'
$mockMcpServer = Join-Path $benchmarkRoot 'mock-mcp\server.mjs'
$caseWorker = Join-Path $benchmarkRoot 'Invoke-BenchmarkCase.ps1'
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
if (-not (Test-Path $caseWorker)) {
    throw "Case worker not found: $caseWorker"
}
if ($Repetitions -lt 1) {
    throw 'Repetitions must be at least 1.'
}
if (Test-Path $runDirectory) {
    throw "Run directory already exists: $runDirectory"
}

$cases = @($configuration.cases)
if ($CaseId) {
    $cases = @($cases | Where-Object { $_.id -in $CaseId })
    $missing = @($CaseId | Where-Object { $_ -notin $cases.id })
    if ($missing.Count -gt 0) { throw "Unknown case ID(s): $($missing -join ', ')" }
}

New-Item $runDirectory -ItemType Directory | Out-Null
$tasks = [System.Collections.Generic.List[object]]::new()
$sequence = 0
foreach ($case in $cases) {
    for ($repetition = 1; $repetition -le $Repetitions; $repetition++) {
        $caseRunId = if ($Repetitions -eq 1) { $case.id } else { "$($case.id)-$repetition" }
        $tasks.Add([pscustomobject]@{
            sequence = $sequence
            case = $case
            repetition = $repetition
            caseRunId = $caseRunId
        })
        $sequence++
    }
}

$pending = [System.Collections.Generic.Queue[object]]::new()
foreach ($task in $tasks) { $pending.Enqueue($task) }
$active = [System.Collections.Generic.List[object]]::new()
$completedResults = [System.Collections.Generic.List[object]]::new()

while ($pending.Count -gt 0 -or $active.Count -gt 0) {
    while ($pending.Count -gt 0 -and $active.Count -lt $ThrottleLimit) {
        $task = $pending.Dequeue()
        $arguments = @(
            ($task.case | ConvertTo-Json -Compress -Depth 6),
            $task.repetition,
            $task.caseRunId,
            $runDirectory,
            $benchmarkRoot,
            $skillSource,
            $configuration.skillName,
            $mockMcpServer,
            $Model
        )
        $job = Start-Job -FilePath $caseWorker -ArgumentList $arguments
        $active.Add([pscustomobject]@{ Job = $job; Task = $task })
    }

    [void](Wait-Job -Job @($active.Job) -Any)
    $finishedEntries = @($active | Where-Object { $_.Job.State -in @('Completed', 'Failed', 'Stopped', 'Disconnected') })
    foreach ($entry in $finishedEntries) {
        Receive-Job $entry.Job -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        $resultPath = Join-Path (Join-Path $runDirectory $entry.Task.caseRunId) 'result.json'
        if (Test-Path $resultPath) {
            $result = Get-Content $resultPath -Raw | ConvertFrom-Json
        } else {
            $result = [pscustomobject][ordered]@{
                caseId = $entry.Task.case.id
                repetition = $entry.Task.repetition
                fixture = $entry.Task.case.fixture
                prompt = $entry.Task.case.prompt
                expectedRecommendation = [bool]$entry.Task.case.expectedRecommendation
                actualRecommendation = $false
                passed = $false
                status = 'infrastructure-error'
                exitCode = -1
                invocationError = "Worker ended in state $($entry.Job.State) without producing result.json."
                inputTokens = 0
                outputTokens = 0
                totalTokens = 0
                artifacts = $entry.Task.caseRunId
            }
        }
        $completedResults.Add([pscustomobject]@{ sequence = $entry.Task.sequence; result = $result })
        Remove-Job $entry.Job -Force
        [void]$active.Remove($entry)
    }
}

$results = @($completedResults | Sort-Object sequence | ForEach-Object { $_.result })

$summary = [ordered]@{
    runId = $RunId
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    model = $Model
    repetitions = $Repetitions
    throttleLimit = $ThrottleLimit
    skillName = $configuration.skillName
    results = $results
}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $runDirectory 'summary.json') -Encoding utf8
& (Join-Path $benchmarkRoot 'New-BenchmarkReport.ps1') -RunDirectory $runDirectory
Write-Host "Artifacts: $runDirectory"
