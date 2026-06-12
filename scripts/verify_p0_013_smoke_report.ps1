param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_013_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-013 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-013 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-013 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-013 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-013_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "scenario count: 8",
    "frequencies: 100,200",
    "reliability profiles: best_effort,reliable",
    "keep_last depths: 10,50",
    "csv path:",
    "markdown report path:",
    "scenario_name,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,notes",
    "qos_100hz_best_effort_depth10",
    "qos_100hz_reliable_depth10",
    "qos_200hz_best_effort_depth10",
    "qos_200hz_reliable_depth10",
    "Observed Tradeoffs",
    "runtime/results/qos",
    "runtime/logs/qos"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"

$scenarioCount = Get-RequiredNumber "scenario count" "scenario count:\s+([0-9]+)"
if ($scenarioCount -ne 8) {
    throw "P0-013 scenario count must be 8, got $scenarioCount"
}

$csvPreview = [regex]::Match($report, "csv preview:\s*(?<preview>.*?)\r?\n\r?\nMarkdown Report", [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $csvPreview.Success) {
    throw "P0-013 smoke report missing CSV preview block"
}

$dataRows = ($csvPreview.Groups["preview"].Value -split "`r?`n" | Where-Object { $_ -match '^qos_' }).Count
if ($dataRows -lt 8) {
    throw "P0-013 CSV preview must include 8 scenario rows, got $dataRows"
}

Write-Host "P0-013 smoke report checks passed"
