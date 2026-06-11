param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_009_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-009 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-009 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-009 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-009 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-009_RESULT",
    "PASS/FAIL: PASS",
    "normal drop rate:",
    "drop fault drop rate:",
    "drop rate increase:",
    "normal p95 latency ms:",
    "delay fault p95 latency ms:",
    "p95 latency increase ms:",
    "drop fault bag messages:",
    "delay fault bag messages:",
    "runtime/bags/p0-009"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"

$normalDropRate = Get-RequiredNumber "normal drop rate" "normal drop rate:\s+([0-9]+(?:\.[0-9]+)?)"
$dropFaultDropRate = Get-RequiredNumber "drop fault drop rate" "drop fault drop rate:\s+([0-9]+(?:\.[0-9]+)?)"
$dropRateIncrease = Get-RequiredNumber "drop rate increase" "drop rate increase:\s+([0-9]+(?:\.[0-9]+)?)"
$normalP95 = Get-RequiredNumber "normal p95 latency ms" "normal p95 latency ms:\s+([0-9]+(?:\.[0-9]+)?)"
$delayP95 = Get-RequiredNumber "delay fault p95 latency ms" "delay fault p95 latency ms:\s+([0-9]+(?:\.[0-9]+)?)"
$p95Increase = Get-RequiredNumber "p95 latency increase ms" "p95 latency increase ms:\s+([0-9]+(?:\.[0-9]+)?)"
$dropBagMessages = Get-RequiredNumber "drop fault bag messages" "drop fault bag messages:\s+([0-9]+)"
$delayBagMessages = Get-RequiredNumber "delay fault bag messages" "delay fault bag messages:\s+([0-9]+)"

if ($normalDropRate -lt 0.0 -or $normalDropRate -gt 0.02) {
    throw "P0-009 normal drop rate outside 0-0.02: $normalDropRate"
}

if ($dropFaultDropRate -lt 0.05 -or $dropRateIncrease -lt 0.05) {
    throw "P0-009 drop fault did not increase drop rate enough"
}

if ($delayP95 -le $normalP95 -or $p95Increase -lt 4.0) {
    throw "P0-009 delay fault did not increase p95 latency enough"
}

if ($dropBagMessages -le 0 -or $delayBagMessages -le 0) {
    throw "P0-009 fault bags must contain messages"
}

Write-Host "P0-009 smoke report checks passed"
