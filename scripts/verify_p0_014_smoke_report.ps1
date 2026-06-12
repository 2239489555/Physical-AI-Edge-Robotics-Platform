param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_014_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-014 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-014 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-014 smoke report contains forbidden text: $Text"
    }
}

function Get-RequiredNumber {
    param(
        [string]$Name,
        [string]$Pattern
    )

    $match = [regex]::Match($report, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "P0-014 smoke report missing numeric field: $Name"
    }

    return [double]$match.Groups[1].Value
}

foreach ($text in @(
    "P0-014_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "scenario count: 10",
    "pressure scenario count: 8",
    "qos mismatch scenario count: 2",
    "frequencies: 500,1000",
    "reliability profiles: best_effort,reliable",
    "keep_last depths: 10,50",
    "mismatch profile: publisher best_effort, subscriber reliable",
    "p0 high-frequency stability required: no",
    "csv path:",
    "markdown report path:",
    "scenario_name,scenario_kind,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,target_ratio,rate_gap_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,metrics_messages,received_count,expected_count,dropped_count,notes",
    "pressure_500hz_pub_best_effort_sub_best_effort_depth10",
    "pressure_500hz_pub_reliable_sub_reliable_depth10",
    "pressure_1000hz_pub_best_effort_sub_best_effort_depth10",
    "pressure_1000hz_pub_reliable_sub_reliable_depth10",
    "qos_mismatch_500hz",
    "qos_mismatch_1000hz",
    "P0 Gate Separation",
    "Bottleneck Reading Guide",
    "QoS Mismatch",
    "runtime/results/qos",
    "runtime/logs/qos",
    "runtime/bags/qos"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"

$scenarioCount = Get-RequiredNumber "scenario count" "scenario count:\s+([0-9]+)"
if ($scenarioCount -ne 10) {
    throw "P0-014 scenario count must be 10, got $scenarioCount"
}

$pressureCount = Get-RequiredNumber "pressure scenario count" "pressure scenario count:\s+([0-9]+)"
if ($pressureCount -ne 8) {
    throw "P0-014 pressure scenario count must be 8, got $pressureCount"
}

$mismatchCount = Get-RequiredNumber "qos mismatch scenario count" "qos mismatch scenario count:\s+([0-9]+)"
if ($mismatchCount -ne 2) {
    throw "P0-014 QoS mismatch scenario count must be 2, got $mismatchCount"
}

$csvPreview = [regex]::Match($report, "csv preview:\s*(?<preview>.*?)\r?\n\r?\nMarkdown Report", [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $csvPreview.Success) {
    throw "P0-014 smoke report missing CSV preview block"
}

$dataRows = ($csvPreview.Groups["preview"].Value -split "`r?`n" | Where-Object { $_ -match '^(pressure_|qos_mismatch_)' }).Count
if ($dataRows -lt 10) {
    throw "P0-014 CSV preview must include 10 scenario rows, got $dataRows"
}

Write-Host "P0-014 smoke report checks passed"
