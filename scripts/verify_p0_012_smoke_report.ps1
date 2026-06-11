param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_012_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-012 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-012 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-012 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-012 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-012_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "normal state: HEALTHY",
    "system pressure state: UNHEALTHY",
    "system pressure active rules:",
    "system_",
    "normal disk used percent:",
    "system pressure disk used percent:",
    "/edge/metrics/system",
    "/edge/health/state",
    "edge_reliability_msgs/msg/SystemMetrics",
    "edge_reliability_msgs/msg/HealthState"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"

if ($report -notmatch "system pressure active rules: .*system_(temperature|power)_unhealthy") {
    throw "P0-012 system pressure must include system_temperature_unhealthy or system_power_unhealthy"
}

$normalMessages = Get-RequiredNumber "normal system messages" "normal system messages:\s+([0-9]+)"
$pressureMessages = Get-RequiredNumber "system pressure system messages" "system pressure system messages:\s+([0-9]+)"
$normalDisk = Get-RequiredNumber "normal disk used percent" "normal disk used percent:\s+([0-9]+(?:\.[0-9]+)?)"
$pressureDisk = Get-RequiredNumber "system pressure disk used percent" "system pressure disk used percent:\s+([0-9]+(?:\.[0-9]+)?)"

if ($normalMessages -lt 3) {
    throw "P0-012 normal system message count too low: $normalMessages"
}

if ($pressureMessages -lt 3) {
    throw "P0-012 system pressure message count too low: $pressureMessages"
}

if ($normalDisk -lt 0 -or $pressureDisk -lt 0) {
    throw "P0-012 disk used percent must be nonnegative"
}

Write-Host "P0-012 smoke report checks passed"
