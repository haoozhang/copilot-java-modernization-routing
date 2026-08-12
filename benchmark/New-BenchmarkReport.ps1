[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunDirectory
)

$ErrorActionPreference = 'Stop'
$summaryPath = Join-Path $RunDirectory 'summary.json'
$summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
$completed = @($summary.results | Where-Object { $_.status -eq 'completed' })
$truePositive = @($completed | Where-Object { $_.expectedTrigger -and $_.skillInvoked }).Count
$trueNegative = @($completed | Where-Object { -not $_.expectedTrigger -and -not $_.skillInvoked }).Count
$falsePositive = @($completed | Where-Object { -not $_.expectedTrigger -and $_.skillInvoked }).Count
$falseNegative = @($completed | Where-Object { $_.expectedTrigger -and -not $_.skillInvoked }).Count

function Get-Ratio([int]$Numerator, [int]$Denominator) {
    if ($Denominator -eq 0) { return $null }
    return [math]::Round($Numerator / $Denominator, 4)
}

function Get-Percentile([long[]]$Values, [double]$Percentile) {
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $index = [math]::Ceiling($Percentile * $sorted.Count) - 1
    return $sorted[[math]::Max(0, $index)]
}

$tokenValues = @($completed | ForEach-Object { [long]$_.totalTokens })
$tokenAverage = if ($tokenValues.Count -eq 0) { $null } else { [math]::Round(($tokenValues | Measure-Object -Average).Average, 2) }

$metrics = [ordered]@{
    runId = $summary.runId
    model = $summary.model
    totalRuns = @($summary.results).Count
    completedRuns = $completed.Count
    failedRuns = @($summary.results | Where-Object { $_.status -ne 'completed' }).Count
    truePositive = $truePositive
    trueNegative = $trueNegative
    falsePositive = $falsePositive
    falseNegative = $falseNegative
    precision = Get-Ratio $truePositive ($truePositive + $falsePositive)
    recall = Get-Ratio $truePositive ($truePositive + $falseNegative)
    accuracy = Get-Ratio ($truePositive + $trueNegative) $completed.Count
    falsePositiveRate = Get-Ratio $falsePositive ($falsePositive + $trueNegative)
    inputTokens = ($completed | Measure-Object inputTokens -Sum).Sum
    outputTokens = ($completed | Measure-Object outputTokens -Sum).Sum
    totalTokens = ($completed | Measure-Object totalTokens -Sum).Sum
    averageTokensPerRun = $tokenAverage
    p50TokensPerRun = Get-Percentile $tokenValues 0.50
    p95TokensPerRun = Get-Percentile $tokenValues 0.95
    maxTokensPerRun = if ($tokenValues.Count -eq 0) { $null } else { ($tokenValues | Measure-Object -Maximum).Maximum }
}

$metrics | ConvertTo-Json | Set-Content (Join-Path $RunDirectory 'metrics.json') -Encoding utf8

$lines = @(
    '# Benchmark Report',
    '',
    "- Run: ``$($metrics.runId)``",
    "- Model: ``$($metrics.model)``",
    "- Completed: $($metrics.completedRuns) / $($metrics.totalRuns)",
    "- Precision: $($metrics.precision)",
    "- Recall: $($metrics.recall)",
    "- Accuracy: $($metrics.accuracy)",
    "- False-positive rate: $($metrics.falsePositiveRate)",
    "- Tokens (input / output / total): $($metrics.inputTokens) / $($metrics.outputTokens) / $($metrics.totalTokens)",
    "- Tokens per run (average / P50 / P95 / max): $($metrics.averageTokensPerRun) / $($metrics.p50TokensPerRun) / $($metrics.p95TokensPerRun) / $($metrics.maxTokensPerRun)",
    '',
    '| Case | Fixture | Expected | Invoked | Result | Tokens |',
    '| --- | --- | ---: | ---: | --- | ---: |'
)

foreach ($result in $summary.results) {
    $outcome = if ($result.status -ne 'completed') { 'ERROR' } elseif ($result.passed) { 'PASS' } else { 'FAIL' }
    $lines += "| $($result.caseId) | $($result.fixture) | $($result.expectedTrigger) | $($result.skillInvoked) | $outcome | $($result.totalTokens) |"
}

$lines | Set-Content (Join-Path $RunDirectory 'report.md') -Encoding utf8
$metrics
