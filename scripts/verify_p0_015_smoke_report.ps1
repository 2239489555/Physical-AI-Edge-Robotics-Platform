param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_015_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-015 smoke report not found: $ReportPath"
}

$report = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param([string]$Text)
    if (-not $report.Contains($Text)) {
        throw "P0-015 smoke report missing required text: $Text"
    }
}

function Assert-NotContains {
    param([string]$Text)
    if ($report.Contains($Text)) {
        throw "P0-015 smoke report contains forbidden text: $Text"
    }
}

foreach ($text in @(
    "P0-015_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "start exit status: 0",
    "stop exit status: 0",
    "run dir:",
    "runtime/run/p0_runtime",
    "log dir:",
    "runtime/logs/runtime",
    "manifest path:",
    "status=stopped",
    "node list:",
    "/fake_sensor_adapter",
    "/sensor_processor",
    "/system_metrics_node",
    "/health_monitor",
    "topic list:",
    "/edge/sensors/fake_primary [edge_reliability_msgs/msg/SensorSample]",
    "/edge/metrics/pipeline [edge_reliability_msgs/msg/PipelineMetrics]",
    "/edge/metrics/system [edge_reliability_msgs/msg/SystemMetrics]",
    "/edge/health/state [edge_reliability_msgs/msg/HealthState]",
    "health echo once:",
    "state:",
    "pid check:",
    "stopped: label=fake_sensor",
    "stopped: label=processor",
    "stopped: label=system_metrics",
    "stopped: label=health_monitor"
)) {
    Assert-Contains $text
}

Assert-NotContains "PASS/FAIL: FAIL"
Assert-NotContains "package had stderr output"
Assert-NotContains "alive: label="

Write-Host "P0-015 smoke report checks passed"
