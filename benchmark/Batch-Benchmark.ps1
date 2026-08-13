[CmdletBinding()]
param(
    [string]$BatchId = (Get-Date -Format 'yyyyMMdd-HHmmss')
)

$ErrorActionPreference = 'Stop'
$benchmarkRunner = Join-Path $PSScriptRoot 'Run-Benchmark.ps1'
$models = @(
    'gpt-5.6-sol',
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.3-codex',
    'gemini-3.1-pro-preview',
    'grok-4.5'
)

if (-not (Test-Path $benchmarkRunner)) {
    throw "Benchmark runner not found: $benchmarkRunner"
}

foreach ($model in $models) {
    $runId = "$BatchId-$model"
    Write-Host "Running benchmark with model $model (run ID: $runId)"
    & $benchmarkRunner `
        -Model $model `
        -Repetitions 3 `
        -ThrottleLimit 3 `
        -RunId $runId
}

Write-Host "Batch complete: $BatchId"