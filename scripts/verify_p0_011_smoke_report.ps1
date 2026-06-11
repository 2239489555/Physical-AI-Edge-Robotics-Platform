param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_011_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-011 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-011 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-011 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-011 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-011_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "system metrics summary:",
    "system messages:",
    "cpu percent:",
    "memory used mb:",
    "memory total mb:",
    "gpu percent:",
    "temperature c:",
    "power w:",
    "source: tegrastats_sample_file",
    "raw tegrastats log path:",
    "raw tegrastats log lines:",
    "live tegrastats status:",
    "/edge/metrics/system",
    "edge_reliability_msgs/msg/SystemMetrics"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"

$messages = Get-RequiredNumber "system messages" "system messages:\s+([0-9]+)"
$memoryUsed = Get-RequiredNumber "memory used mb" "memory used mb:\s+([0-9]+(?:\.[0-9]+)?)"
$memoryTotal = Get-RequiredNumber "memory total mb" "memory total mb:\s+([0-9]+(?:\.[0-9]+)?)"
$temperature = Get-RequiredNumber "temperature c" "temperature c:\s+([0-9]+(?:\.[0-9]+)?)"
$power = Get-RequiredNumber "power w" "power w:\s+([0-9]+(?:\.[0-9]+)?)"
$rawLines = Get-RequiredNumber "raw tegrastats log lines" "raw tegrastats log lines:\s+([0-9]+)"

if ($messages -lt 3) {
    throw "P0-011 system message count too low: $messages"
}

if ($memoryUsed -le 0 -or $memoryTotal -le $memoryUsed) {
    throw "P0-011 memory values invalid"
}

if ($temperature -le 0 -or $power -le 0) {
    throw "P0-011 temperature or power values invalid"
}

if ($rawLines -le 0) {
    throw "P0-011 raw tegrastats log must contain lines"
}

$liveStatus = [regex]::Match($report, "live tegrastats status:\s+(available|unavailable|failed)")
if (-not $liveStatus.Success) {
    throw "P0-011 live tegrastats status must be available, unavailable, or failed"
}

Write-Host "P0-011 smoke report checks passed"
