param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_007_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-007 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param(
        [string]$Text
    )

    if (-not $report.Contains($Text)) {
        throw "P0-007 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param(
        [string]$Text
    )

    if ($report.Contains($Text)) {
        throw "P0-007 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-007 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-007_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "Type: edge_reliability_msgs/msg/PipelineMetrics",
    "Node name: sensor_processor",
    "received_count:",
    "expected_count:",
    "dropped_count:",
    "out_of_order_count:",
    "receive_rate_hz:",
    "expected_rate_hz:",
    "average_latency_ms:",
    "p95_latency_ms:",
    "p99_latency_ms:",
    "drop_rate:",
    "sensor last average rate:",
    "metrics last average rate:",
    "bag messages:",
    "runtime/bags/p0-007"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"

$receivedCount = Get-RequiredNumber "received_count" "received_count:\s+([0-9]+)"
$receiveRate = Get-RequiredNumber "receive_rate_hz" "receive_rate_hz:\s+([0-9]+(?:\.[0-9]+)?)"
$expectedRate = Get-RequiredNumber "expected_rate_hz" "expected_rate_hz:\s+([0-9]+(?:\.[0-9]+)?)"
$averageLatency = Get-RequiredNumber "average_latency_ms" "average_latency_ms:\s+([0-9]+(?:\.[0-9]+)?)"
$p95Latency = Get-RequiredNumber "p95_latency_ms" "p95_latency_ms:\s+([0-9]+(?:\.[0-9]+)?)"
$p99Latency = Get-RequiredNumber "p99_latency_ms" "p99_latency_ms:\s+([0-9]+(?:\.[0-9]+)?)"
$dropRate = Get-RequiredNumber "drop_rate" "drop_rate:\s+([0-9]+(?:\.[0-9]+)?)"
$sensorRate = Get-RequiredNumber "sensor last average rate" "sensor last average rate:\s+([0-9]+(?:\.[0-9]+)?)"
$metricsRate = Get-RequiredNumber "metrics last average rate" "metrics last average rate:\s+([0-9]+(?:\.[0-9]+)?)"
$bagMessages = Get-RequiredNumber "bag messages" "bag messages:\s+([0-9]+)"

if ($receivedCount -le 0) {
    throw "P0-007 smoke report received_count must be positive"
}

if ($receiveRate -lt 90.0 -or $receiveRate -gt 110.0) {
    throw "P0-007 receive_rate_hz outside 90-110Hz: $receiveRate"
}

if ($expectedRate -ne 100.0) {
    throw "P0-007 expected_rate_hz should be 100.0, got $expectedRate"
}

if ($averageLatency -lt 0.0 -or $p95Latency -lt 0.0 -or $p99Latency -lt 0.0) {
    throw "P0-007 latency fields must be non-negative"
}

if ($p99Latency -lt $p95Latency) {
    throw "P0-007 p99 latency should be greater than or equal to p95 latency"
}

if ($dropRate -lt 0.0 -or $dropRate -gt 1.0) {
    throw "P0-007 drop_rate outside 0-1 range: $dropRate"
}

if ($sensorRate -lt 90.0 -or $sensorRate -gt 110.0) {
    throw "P0-007 sensor last average rate outside 90-110Hz: $sensorRate"
}

if ($metricsRate -lt 0.5 -or $metricsRate -gt 2.0) {
    throw "P0-007 metrics last average rate outside 0.5-2.0Hz: $metricsRate"
}

if ($bagMessages -le 0) {
    throw "P0-007 bag messages must be positive"
}

Write-Host "P0-007 smoke report checks passed"
