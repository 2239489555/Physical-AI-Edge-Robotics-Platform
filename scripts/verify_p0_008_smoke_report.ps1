param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_008_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-008 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)

    if (-not $report.Contains($Text)) {
        throw "P0-008 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)

    if ($report.Contains($Text)) {
        throw "P0-008 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-008 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-008_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "scenario: normal_replay",
    "recorded topic: /edge/sensors/fake_primary",
    "recorded type: edge_reliability_msgs/msg/SensorSample",
    "bag directory:",
    "recorded sensor messages:",
    "replay metrics messages:",
    "replay received count:",
    "replay expected count:",
    "replay receive ratio:",
    "replay receive rate hz:",
    "replay drop rate:",
    "replay out_of_order count:",
    "runtime/bags/p0-008"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"

$recordedMessages = Get-RequiredNumber "recorded sensor messages" "recorded sensor messages:\s+([0-9]+)"
$metricsMessages = Get-RequiredNumber "replay metrics messages" "replay metrics messages:\s+([0-9]+)"
$receivedCount = Get-RequiredNumber "replay received count" "replay received count:\s+([0-9]+)"
$receiveRatio = Get-RequiredNumber "replay receive ratio" "replay receive ratio:\s+([0-9]+(?:\.[0-9]+)?)"
$receiveRate = Get-RequiredNumber "replay receive rate hz" "replay receive rate hz:\s+([0-9]+(?:\.[0-9]+)?)"
$dropRate = Get-RequiredNumber "replay drop rate" "replay drop rate:\s+([0-9]+(?:\.[0-9]+)?)"
$outOfOrder = Get-RequiredNumber "replay out_of_order count" "replay out_of_order count:\s+([0-9]+)"

if ($recordedMessages -le 0) {
    throw "P0-008 recorded sensor messages must be positive"
}

if ($metricsMessages -le 0) {
    throw "P0-008 replay metrics messages must be positive"
}

if ($receivedCount -lt ($recordedMessages * 0.90) -or $receivedCount -gt ($recordedMessages + 5)) {
    throw "P0-008 replay received count outside tolerance: received=$receivedCount recorded=$recordedMessages"
}

if ($receiveRatio -lt 0.90 -or $receiveRatio -gt 1.05) {
    throw "P0-008 replay receive ratio outside 0.90-1.05: $receiveRatio"
}

if ($receiveRate -lt 80.0 -or $receiveRate -gt 130.0) {
    throw "P0-008 replay receive rate outside 80-130Hz: $receiveRate"
}

if ($dropRate -lt 0.0 -or $dropRate -gt 0.05) {
    throw "P0-008 replay drop rate outside 0-0.05: $dropRate"
}

if ($outOfOrder -ne 0) {
    throw "P0-008 replay out_of_order count must be zero"
}

Write-Host "P0-008 smoke report checks passed"
