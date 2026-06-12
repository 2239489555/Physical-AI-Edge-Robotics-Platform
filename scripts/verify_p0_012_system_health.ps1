param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$healthDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_health"
$systemDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_system"
$messagesDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_msgs"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-012_system_health_integration_jetson_metrics.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/system_health_integration.md"
$m5Path = Join-Path $RepoRoot "docs/backlog/M5_tegrastats_monitor.md"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_012_system_health_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_012_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_012_completion_gate.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_012_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_012_smoke_report_fail.txt"

$requiredFiles = @(
    @((Join-Path $messagesDir "msg/SystemMetrics.msg"), "SystemMetrics.msg"),
    @((Join-Path $systemDir "src/system_metrics_node.cpp"), "system metrics node source"),
    @((Join-Path $systemDir "config/system_metrics.yaml"), "system metrics config"),
    @((Join-Path $systemDir "launch/system_metrics.launch.py"), "system metrics launch"),
    @((Join-Path $healthDir "include/edge_reliability_health/health_rules.hpp"), "health rules header"),
    @((Join-Path $healthDir "src/health_monitor.cpp"), "health monitor source"),
    @((Join-Path $healthDir "test/health_rules_test.cpp"), "health rules test"),
    @((Join-Path $healthDir "config/health_monitor.yaml"), "health monitor config"),
    @((Join-Path $healthDir "config/health_monitor_system_nominal.yaml"), "system nominal health config"),
    @((Join-Path $healthDir "config/health_monitor_system_pressure.yaml"), "system pressure health config"),
    @((Join-Path $healthDir "package.xml"), "health package.xml"),
    @((Join-Path $healthDir "README.md"), "health README"),
    @((Join-Path $systemDir "README.md"), "system README"),
    @($smokeScriptPath, "scripts/run_p0_012_system_health_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_012_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_012_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/system_health_integration.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "P0-012 issue"),
    @($interfaceContractPath, "interface contract"),
    @($m5Path, "M5 backlog"),
    @($passFixturePath, "P0-012 pass fixture"),
    @($failFixturePath, "P0-012 fail fixture")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-012 system health files: $($missing -join ', ')"
}

function Assert-Contains {
    param(
        [string]$Name,
        [string]$Content,
        [string]$Text
    )

    if (-not $Content.Contains($Text)) {
        throw "$Name does not contain required text: $Text"
    }
}

function Assert-NotContains {
    param(
        [string]$Name,
        [string]$Content,
        [string]$Text
    )

    if ($Content.Contains($Text)) {
        throw "$Name contains forbidden text: $Text"
    }
}

$systemMetricsMsg = Get-Content -Raw -LiteralPath (Join-Path $messagesDir "msg/SystemMetrics.msg")
$systemSource = Get-Content -Raw -LiteralPath (Join-Path $systemDir "src/system_metrics_node.cpp")
$systemConfig = Get-Content -Raw -LiteralPath (Join-Path $systemDir "config/system_metrics.yaml")
$systemLaunch = Get-Content -Raw -LiteralPath (Join-Path $systemDir "launch/system_metrics.launch.py")
$systemReadme = Get-Content -Raw -LiteralPath (Join-Path $systemDir "README.md")
$rulesHeader = Get-Content -Raw -LiteralPath (Join-Path $healthDir "include/edge_reliability_health/health_rules.hpp")
$healthSource = Get-Content -Raw -LiteralPath (Join-Path $healthDir "src/health_monitor.cpp")
$healthTest = Get-Content -Raw -LiteralPath (Join-Path $healthDir "test/health_rules_test.cpp")
$healthConfig = Get-Content -Raw -LiteralPath (Join-Path $healthDir "config/health_monitor.yaml")
$nominalConfig = Get-Content -Raw -LiteralPath (Join-Path $healthDir "config/health_monitor_system_nominal.yaml")
$pressureConfig = Get-Content -Raw -LiteralPath (Join-Path $healthDir "config/health_monitor_system_pressure.yaml")
$healthPackage = Get-Content -Raw -LiteralPath (Join-Path $healthDir "package.xml")
$healthReadme = Get-Content -Raw -LiteralPath (Join-Path $healthDir "README.md")
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$m5 = Get-Content -Raw -LiteralPath $m5Path
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "float64 disk_used_mb",
    "float64 disk_total_mb",
    "float64 disk_used_percent"
)) {
    Assert-Contains "SystemMetrics.msg" $systemMetricsMsg $text
}

foreach ($text in @(
    'declare_parameter<std::string>("disk_path", "/")',
    "std::filesystem::space",
    "message.disk_used_mb",
    "message.disk_total_mb",
    "message.disk_used_percent",
    "event=disk_metrics_unavailable"
)) {
    Assert-Contains "system_metrics_node.cpp" $systemSource $text
}

foreach ($text in @(
    "disk_path: /",
    "raw_log_path:"
)) {
    Assert-Contains "system_metrics.yaml" $systemConfig $text
}

foreach ($text in @(
    "disk_path",
    "Filesystem path used for disk usage metrics"
)) {
    Assert-Contains "system_metrics.launch.py" $systemLaunch $text
}

foreach ($text in @(
    "struct SystemHealthInput",
    "max_cpu_percent_warning{85.0}",
    "max_memory_used_percent_warning{80.0}",
    "max_disk_used_percent_warning{80.0}",
    "max_temperature_c_unhealthy{85.0}",
    "evaluate_system_health",
    "combine_health_evaluations",
    "system_temperature_unhealthy",
    "system_disk_warning"
)) {
    Assert-Contains "health_rules.hpp" $rulesHeader $text
}

foreach ($text in @(
    "create_subscription<edge_reliability_msgs::msg::SystemMetrics>",
    'declare_parameter<std::string>("system_metrics_topic", "/edge/metrics/system")',
    'declare_parameter<double>("max_temperature_c_warning", 75.0)',
    "event=first_system_metrics_receive",
    "combine_health_evaluations"
)) {
    Assert-Contains "health_monitor.cpp" $healthSource $text
}

foreach ($text in @(
    "MarksSystemTemperatureUnhealthy",
    "MarksSystemMemoryAndDiskWarning",
    "CombinesPipelineAndSystemRules",
    "system_memory_unhealthy"
)) {
    Assert-Contains "health_rules_test.cpp" $healthTest $text
}

foreach ($text in @(
    "system_metrics_topic: /edge/metrics/system",
    "max_cpu_percent_warning: 85.0",
    "max_memory_used_percent_warning: 80.0",
    "max_disk_used_percent_warning: 80.0",
    "max_temperature_c_unhealthy: 85.0",
    "max_power_w_unhealthy: 60.0"
)) {
    Assert-Contains "health_monitor.yaml" $healthConfig $text
}

foreach ($text in @(
    "min_receive_rate_hz_warning: 1.0",
    "max_p95_latency_ms_warning: 50.0",
    "max_temperature_c_unhealthy: 85.0",
    "max_power_w_unhealthy: 60.0"
)) {
    Assert-Contains "health_monitor_system_nominal.yaml" $nominalConfig $text
}

foreach ($text in @(
    "min_receive_rate_hz_warning: 1.0",
    "max_p95_latency_ms_warning: 50.0",
    "max_temperature_c_unhealthy: 40.0",
    "max_power_w_unhealthy: 5.0"
)) {
    Assert-Contains "health_monitor_system_pressure.yaml" $pressureConfig $text
}

Assert-Contains "health package.xml" $healthPackage "<exec_depend>edge_reliability_system</exec_depend>"

foreach ($text in @(
    "/edge/metrics/system",
    "SystemMetrics",
    "system_temperature_unhealthy",
    "system_disk_warning",
    "scripts/run_p0_012_system_health_smoke.sh"
)) {
    Assert-Contains "health README" $healthReadme $text
}

foreach ($text in @(
    "disk_used_percent",
    "disk_path",
    "filesystem"
)) {
    Assert-Contains "system README" $systemReadme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-012_RESULT",
    'SYSTEM_TOPIC="/edge/metrics/system"',
    "edge_reliability_system",
    "edge_reliability_health",
    "health_monitor_system_nominal.yaml",
    "health_monitor_system_pressure.yaml",
    "capture_system_metrics_summary",
    "capture_health_summary",
    "system pressure state:",
    "system_temperature_unhealthy",
    "system_power_unhealthy",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_012_system_health_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    "/tmp/p0-012"
)) {
    Assert-NotContains "scripts/run_p0_012_system_health_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "P0-012_RESULT",
    "PASS/FAIL: PASS",
    "normal state: HEALTHY",
    "system pressure state: UNHEALTHY",
    "system pressure active rules:",
    "system_",
    "disk used percent",
    "P0-012 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_012_smoke_report.ps1" $smokeVerifier $text
}

foreach ($text in @(
    "verify_p0_012_system_health.ps1",
    "verify_p0_012_smoke_report.ps1",
    "P0-012 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_012_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# System Health Integration",
    "P0-012",
    "/edge/metrics/system",
    "/edge/health/state",
    "system_temperature_unhealthy",
    "system_disk_warning",
    "health_monitor_system_pressure.yaml",
    "health_monitor_system_nominal.yaml"
)) {
    Assert-Contains "docs/runbooks/system_health_integration.md" $runbook $text
}

foreach ($text in @(
    "run_p0_012_system_health_smoke.sh",
    "verify_p0_012_system_health.ps1",
    "verify_p0_012_smoke_report.ps1",
    "verify_p0_012_completion_gate.ps1",
    "P0-012"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "health_monitor_system_nominal.yaml",
    "health_monitor_system_pressure.yaml",
    "scripts/run_p0_012_system_health_smoke.sh",
    'Returned Jetson smoke evidence completed with `PASS/FAIL: PASS`'
)) {
    Assert-Contains "P0-012 issue" $issue $text
}

foreach ($text in @(
    "P0-012",
    "system_temperature_unhealthy",
    "system_disk_warning",
    "disk_used_percent",
    "max_temperature_c_unhealthy",
    "/edge/metrics/system"
)) {
    Assert-Contains "interface contract" $interfaceContract $text
}

foreach ($text in @(
    "P0-012",
    "system health integration",
    "health_monitor_system_pressure.yaml"
)) {
    Assert-Contains "M5 backlog" $m5 $text
}

foreach ($text in @(
    "P0-012_RESULT",
    "PASS/FAIL: PASS",
    "normal state: HEALTHY",
    "system pressure state: UNHEALTHY",
    "system_temperature_unhealthy",
    "normal disk used percent:"
)) {
    Assert-Contains "P0-012 pass fixture" $passFixture $text
}

foreach ($text in @(
    "P0-012_RESULT",
    "PASS/FAIL: FAIL",
    "system pressure state: HEALTHY",
    "Blocker if FAIL:"
)) {
    Assert-Contains "P0-012 fail fixture" $failFixture $text
}

Write-Host "P0-012 system health static checks passed"
