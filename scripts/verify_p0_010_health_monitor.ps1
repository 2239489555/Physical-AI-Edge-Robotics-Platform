param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$healthDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_health"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-010_health_monitor_configurable_thresholds.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/health_monitor_thresholds.md"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_010_health_monitor_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_010_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_010_completion_gate.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_010_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_010_smoke_report_fail.txt"

$requiredFiles = @(
    @((Join-Path $healthDir "CMakeLists.txt"), "edge_reliability_health CMakeLists.txt"),
    @((Join-Path $healthDir "package.xml"), "edge_reliability_health package.xml"),
    @((Join-Path $healthDir "include/edge_reliability_health/health_rules.hpp"), "health rules header"),
    @((Join-Path $healthDir "src/health_monitor.cpp"), "health monitor source"),
    @((Join-Path $healthDir "test/health_rules_test.cpp"), "health rules test"),
    @((Join-Path $healthDir "config/health_monitor.yaml"), "health monitor config"),
    @((Join-Path $healthDir "launch/health_monitor.launch.py"), "health monitor launch"),
    @((Join-Path $healthDir "README.md"), "health README"),
    @($smokeScriptPath, "scripts/run_p0_010_health_monitor_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_010_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_010_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/health_monitor_thresholds.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "docs/backlog/issues/P0-010_health_monitor_configurable_thresholds.md"),
    @($interfaceContractPath, "docs/interfaces/edge_reliability_contract.md"),
    @($passFixturePath, "scripts/testdata/p0_010_smoke_report_pass.txt"),
    @($failFixturePath, "scripts/testdata/p0_010_smoke_report_fail.txt")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-010 health monitor files: $($missing -join ', ')"
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

$cmake = Get-Content -Raw -LiteralPath (Join-Path $healthDir "CMakeLists.txt")
$packageXml = Get-Content -Raw -LiteralPath (Join-Path $healthDir "package.xml")
$rulesHeader = Get-Content -Raw -LiteralPath (Join-Path $healthDir "include/edge_reliability_health/health_rules.hpp")
$source = Get-Content -Raw -LiteralPath (Join-Path $healthDir "src/health_monitor.cpp")
$test = Get-Content -Raw -LiteralPath (Join-Path $healthDir "test/health_rules_test.cpp")
$config = Get-Content -Raw -LiteralPath (Join-Path $healthDir "config/health_monitor.yaml")
$launch = Get-Content -Raw -LiteralPath (Join-Path $healthDir "launch/health_monitor.launch.py")
$readme = Get-Content -Raw -LiteralPath (Join-Path $healthDir "README.md")
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeReportVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "project(edge_reliability_health)",
    "add_executable(health_monitor src/health_monitor.cpp)",
    "ament_target_dependencies(health_monitor rclcpp edge_reliability_msgs)",
    "ament_add_gtest(health_rules_test"
)) {
    Assert-Contains "edge_reliability_health CMakeLists.txt" $cmake $text
}

foreach ($text in @(
    "<name>edge_reliability_health</name>",
    "<depend>rclcpp</depend>",
    "<depend>edge_reliability_msgs</depend>",
    "<exec_depend>edge_reliability_processor</exec_depend>"
)) {
    Assert-Contains "edge_reliability_health package.xml" $packageXml $text
}

foreach ($text in @(
    "struct HealthThresholds",
    "min_receive_rate_hz_warning{95.0}",
    "min_receive_rate_hz_unhealthy{80.0}",
    "max_drop_rate_warning{0.001}",
    "max_drop_rate_unhealthy{0.01}",
    "max_p95_latency_ms_warning{5.0}",
    "max_p95_latency_ms_unhealthy{20.0}",
    "max_p99_latency_ms_warning{10.0}",
    "max_p99_latency_ms_unhealthy{50.0}",
    "evaluate_pipeline_health",
    "drop_rate_unhealthy",
    "p95_latency_warning",
    "out_of_order_unhealthy"
)) {
    Assert-Contains "health_rules.hpp" $rulesHeader $text
}

foreach ($text in @(
    "create_subscription<edge_reliability_msgs::msg::PipelineMetrics>",
    "create_publisher<edge_reliability_msgs::msg::HealthState>",
    "declare_parameter<double>(`"min_receive_rate_hz_warning`", 95.0)",
    "declare_parameter<double>(`"max_drop_rate_unhealthy`", 0.01)",
    "declare_parameter<double>(`"max_p95_latency_ms_warning`", 5.0)",
    "health.active_rules = evaluation.active_rules;",
    "event=health_transition",
    "event=first_health_publish",
    "edge_reliability_msgs::msg::HealthState::UNHEALTHY"
)) {
    Assert-Contains "health_monitor.cpp" $source $text
}

foreach ($text in @(
    "KeepsNormalPipelineHealthy",
    "MarksDropFaultUnhealthy",
    "MarksSubscriberDelayWarning",
    "MarksSevereLatencyUnhealthy",
    "MarksLowReceiveRateWarning"
)) {
    Assert-Contains "health_rules_test.cpp" $test $text
}

foreach ($text in @(
    "metrics_topic: /edge/metrics/pipeline",
    "health_topic: /edge/health/state",
    "min_receive_rate_hz_warning: 95.0",
    "max_drop_rate_unhealthy: 0.01",
    "max_p95_latency_ms_warning: 5.0",
    "max_p99_latency_ms_unhealthy: 50.0"
)) {
    Assert-Contains "health_monitor.yaml" $config $text
}

foreach ($text in @(
    "FindPackageShare(`"edge_reliability_health`")",
    "health_monitor.yaml",
    "executable=`"health_monitor`""
)) {
    Assert-Contains "health_monitor.launch.py" $launch $text
}

foreach ($text in @(
    "/edge/health/state",
    "edge_reliability_msgs/msg/HealthState",
    "min_receive_rate_hz_warning",
    "max_drop_rate_unhealthy",
    "max_p95_latency_ms_warning",
    "scripts/run_p0_010_health_monitor_smoke.sh"
)) {
    Assert-Contains "edge_reliability_health README" $readme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-010_RESULT",
    'HEALTH_TOPIC="/edge/health/state"',
    'HEALTH_TYPE="edge_reliability_msgs/msg/HealthState"',
    "edge_reliability_health",
    "health_monitor.launch.py",
    "capture_health_summary",
    "normal state:",
    "drop fault state:",
    "delay fault state:",
    "drop_rate_unhealthy",
    "p95_latency_",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_010_health_monitor_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    "/tmp/p0-010"
)) {
    Assert-NotContains "scripts/run_p0_010_health_monitor_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "P0-010_RESULT",
    "PASS/FAIL: PASS",
    "normal state: HEALTHY",
    "drop fault state: UNHEALTHY",
    "drop_rate_unhealthy",
    "p95_latency_",
    "P0-010 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_010_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "verify_p0_010_health_monitor.ps1",
    "verify_p0_010_smoke_report.ps1",
    "P0-010 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_010_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# Health Monitor Thresholds",
    "P0-010",
    "/edge/metrics/pipeline",
    "/edge/health/state",
    "HealthState",
    "max_drop_rate_unhealthy",
    "max_p95_latency_ms_warning",
    "normal HEALTHY",
    "drop fault UNHEALTHY",
    "delay fault WARNING"
)) {
    Assert-Contains "docs/runbooks/health_monitor_thresholds.md" $runbook $text
}

foreach ($text in @(
    "run_p0_010_health_monitor_smoke.sh",
    "verify_p0_010_health_monitor.ps1",
    "verify_p0_010_smoke_report.ps1",
    "verify_p0_010_completion_gate.ps1",
    "P0-010"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "edge_reliability_health",
    "scripts/run_p0_010_health_monitor_smoke.sh",
    "Completion requires returned Jetson smoke evidence"
)) {
    Assert-Contains "docs/backlog/issues/P0-010_health_monitor_configurable_thresholds.md" $issue $text
}

foreach ($text in @(
    "P0-010",
    "edge_reliability_health",
    "health_monitor",
    "min_receive_rate_hz_warning",
    "max_drop_rate_unhealthy",
    "max_p95_latency_ms_warning",
    "/edge/health/state"
)) {
    Assert-Contains "docs/interfaces/edge_reliability_contract.md" $interfaceContract $text
}

foreach ($text in @(
    "P0-010_RESULT",
    "PASS/FAIL: PASS",
    "normal state: HEALTHY",
    "drop fault state: UNHEALTHY",
    "delay fault state: WARNING",
    "drop_rate_unhealthy",
    "p95_latency_warning"
)) {
    Assert-Contains "scripts/testdata/p0_010_smoke_report_pass.txt" $passFixture $text
}

foreach ($text in @(
    "P0-010_RESULT",
    "PASS/FAIL: FAIL",
    "drop fault state: HEALTHY",
    "Blocker if FAIL:"
)) {
    Assert-Contains "scripts/testdata/p0_010_smoke_report_fail.txt" $failFixture $text
}

Write-Host "P0-010 health monitor static checks passed"
