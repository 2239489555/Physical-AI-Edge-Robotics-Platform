param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_010_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-010 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-010 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-010 smoke report contains forbidden text: $Text"
    }
}

foreach ($text in @(
    "P0-010_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "health topic: /edge/health/state",
    "health type: edge_reliability_msgs/msg/HealthState",
    "metrics topic: /edge/metrics/pipeline",
    "normal state: HEALTHY",
    "drop fault state: UNHEALTHY",
    "drop fault active rules:",
    "drop_rate_unhealthy",
    "delay fault state:",
    "delay fault active rules:",
    "p95_latency_"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"

$delayMatch = [regex]::Match($report, "delay fault state:\s+(WARNING|UNHEALTHY)")
if (-not $delayMatch.Success) {
    throw "P0-010 delay fault state must be WARNING or UNHEALTHY"
}

Write-Host "P0-010 smoke report checks passed"
