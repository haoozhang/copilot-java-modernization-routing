[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunDirectory
)

$ErrorActionPreference = 'Stop'
$summaryPath = Join-Path $RunDirectory 'summary.json'
$summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
# Exclude infrastructure failures from behavior metrics while reporting them separately.
$completed = @($summary.results | Where-Object { $_.status -eq 'completed' })
# Treat expectedRecommendation as truth and actualRecommendation as the prediction.
$truePositive = @($completed | Where-Object { $_.expectedRecommendation -and $_.actualRecommendation }).Count
$trueNegative = @($completed | Where-Object { -not $_.expectedRecommendation -and -not $_.actualRecommendation }).Count
$falsePositive = @($completed | Where-Object { -not $_.expectedRecommendation -and $_.actualRecommendation }).Count
$falseNegative = @($completed | Where-Object { $_.expectedRecommendation -and -not $_.actualRecommendation }).Count

function Get-Ratio([int]$Numerator, [int]$Denominator) {
    if ($Denominator -eq 0) { return $null }
    return [math]::Round($Numerator / $Denominator, 4)
}

function Get-Percentile([long[]]$Values, [double]$Percentile) {
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    # Use the nearest-rank definition so reported percentiles are observed run values.
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

# Build Markdown as lines to keep the generated report deterministic and diff-friendly.
$lines = @(
    '# Benchmark Report',
    '',
    "- Run: ``$($metrics.runId)``",
    "- Model: ``$($metrics.model)``",
    "- Completed: $($metrics.completedRuns) / $($metrics.totalRuns)",
    "- Tokens (input / output / total): $($metrics.inputTokens) / $($metrics.outputTokens) / $($metrics.totalTokens)",
    "- Tokens per run (average / P50 / P95 / max): $($metrics.averageTokensPerRun) / $($metrics.p50TokensPerRun) / $($metrics.p95TokensPerRun) / $($metrics.maxTokensPerRun)",
    '',
    "- Precision: $($metrics.precision)",
    "- Recall: $($metrics.recall)",
    "- Accuracy: $($metrics.accuracy)",
    "- False-positive rate: $($metrics.falsePositiveRate)",
    "- TP / TN / FP / FN: $truePositive / $trueNegative / $falsePositive / $falseNegative",
    '',
    '| Case | Fixture | Expected recommendation | Actual recommendation | Result | Tokens |',
    '| --- | --- | ---: | ---: | --- | ---: |'
)

foreach ($result in $summary.results) {
    $outcome = if ($result.status -ne 'completed') { 'ERROR' } elseif ($result.passed) { 'PASS' } else { 'FAIL' }
    $lines += "| $($result.caseId) | $($result.fixture) | $($result.expectedRecommendation) | $($result.actualRecommendation) | $outcome | $($result.totalTokens) |"
}

$lines | Set-Content (Join-Path $RunDirectory 'report.md') -Encoding utf8
$metrics
