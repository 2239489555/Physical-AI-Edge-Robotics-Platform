param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$fakeSensorDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_fake_sensor"
$processorDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_processor"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-013_qos_experiment_runner_100_200hz_reports.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/qos_experiment_runner.md"
$m6Path = Join-Path $RepoRoot "docs/backlog/M6_qos_latency_drop_lab.md"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_013_qos_experiment_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_013_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_013_completion_gate.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_013_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_013_smoke_report_fail.txt"

$requiredFiles = @(
    @((Join-Path $fakeSensorDir "src/fake_sensor_adapter.cpp"), "fake sensor source"),
    @((Join-Path $processorDir "src/sensor_processor.cpp"), "processor source"),
    @((Join-Path $processorDir "config/processor.yaml"), "processor config"),
    @((Join-Path $processorDir "config/processor_delay.yaml"), "processor delay config"),
    @((Join-Path $processorDir "README.md"), "processor README"),
    @($smokeScriptPath, "scripts/run_p0_013_qos_experiment_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_013_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_013_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/qos_experiment_runner.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "P0-013 issue"),
    @($interfaceContractPath, "interface contract"),
    @($m6Path, "M6 backlog"),
    @($passFixturePath, "P0-013 pass fixture"),
    @($failFixturePath, "P0-013 fail fixture")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-013 QoS experiment files: $($missing -join ', ')"
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

$fakeSource = Get-Content -Raw -LiteralPath (Join-Path $fakeSensorDir "src/fake_sensor_adapter.cpp")
$processorSource = Get-Content -Raw -LiteralPath (Join-Path $processorDir "src/sensor_processor.cpp")
$processorConfig = Get-Content -Raw -LiteralPath (Join-Path $processorDir "config/processor.yaml")
$processorDelayConfig = Get-Content -Raw -LiteralPath (Join-Path $processorDir "config/processor_delay.yaml")
$processorReadme = Get-Content -Raw -LiteralPath (Join-Path $processorDir "README.md")
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeReportVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$m6 = Get-Content -Raw -LiteralPath $m6Path
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    'declare_parameter<std::string>("qos_reliability", "best_effort")',
    ".best_effort()",
    ".reliable()",
    "qos_reliability=%s"
)) {
    Assert-Contains "fake_sensor_adapter.cpp" $fakeSource $text
}

foreach ($text in @(
    'declare_parameter<std::string>("sensor_qos_reliability", "best_effort")',
    "sensor_qos_reliability_",
    "sensor_qos.reliable()",
    "sensor_qos.best_effort()",
    "parameter=sensor_qos_reliability",
    "sensor_qos_reliability=%s"
)) {
    Assert-Contains "sensor_processor.cpp" $processorSource $text
}

foreach ($text in @(
    "sensor_qos_depth: 10",
    "sensor_qos_reliability: best_effort"
)) {
    Assert-Contains "processor.yaml" $processorConfig $text
}

foreach ($text in @(
    "sensor_qos_reliability: best_effort",
    "processing_delay_enabled: true"
)) {
    Assert-Contains "processor_delay.yaml" $processorDelayConfig $text
}

foreach ($text in @(
    "QoS Parameters",
    "sensor_qos_reliability",
    "best_effort",
    "reliable",
    "P0-013"
)) {
    Assert-Contains "processor README" $processorReadme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-013_RESULT",
    'QOS_RESULT_DIR="$RESULT_DIR/qos"',
    'QOS_LOG_DIR="$LOG_DIR/qos"',
    'CONFIG_DIR="$TMP_DIR/configs"',
    "as_yaml_double",
    "write_fake_config",
    "write_processor_config",
    "publish_hz: `$hz_double",
    "expected_hz: `$hz_double",
    "run_qos_scenario",
    "wait_for_topic_type",
    "launch_and_check ACTIVE_FAKE_PID",
    "launch_and_check ACTIVE_PROCESSOR_PID",
    "launch_and_check ACTIVE_SYSTEM_PID",
    "for hz in 100 200",
    "for reliability in best_effort reliable",
    "for depth in 10 50",
    "sensor_qos_reliability: `$reliability",
    "qos_reliability: `$reliability",
    "scenario_name,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,notes",
    "write_markdown_report",
    "Observed Tradeoffs",
    "runtime/results/qos",
    "runtime/logs/qos",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_013_qos_experiment_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    " /tmp/p0-013",
    "`n/tmp/p0-013",
    'ACTIVE_FAKE_PID="$(launch_and_check',
    'ACTIVE_PROCESSOR_PID="$(launch_and_check',
    'ACTIVE_SYSTEM_PID="$(launch_and_check',
    "publish_hz: `$hz`n",
    "expected_hz: `$hz`n"
)) {
    Assert-NotContains "scripts/run_p0_013_qos_experiment_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "P0-013_RESULT",
    "PASS/FAIL: PASS",
    "scenario count: 8",
    "frequencies: 100,200",
    "reliability profiles: best_effort,reliable",
    "keep_last depths: 10,50",
    "csv path:",
    "scenario_name,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,notes",
    "markdown report path:",
    "Observed Tradeoffs",
    "P0-013 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_013_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "verify_p0_013_qos_experiment.ps1",
    "verify_p0_013_smoke_report.ps1",
    "P0-013 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_013_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# QoS Experiment Runner",
    "P0-013",
    "100Hz",
    "200Hz",
    "BestEffort",
    "Reliable",
    "KeepLast",
    "runtime/results/qos",
    "p0_013_qos_results.csv"
)) {
    Assert-Contains "docs/runbooks/qos_experiment_runner.md" $runbook $text
}

foreach ($text in @(
    "run_p0_013_qos_experiment_smoke.sh",
    "verify_p0_013_qos_experiment.ps1",
    "verify_p0_013_smoke_report.ps1",
    "verify_p0_013_completion_gate.ps1",
    "P0-013"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "scripts/run_p0_013_qos_experiment_smoke.sh",
    "runtime/results/qos",
    "p0_013_qos_results.csv",
    "Completion requires returned Jetson smoke evidence"
)) {
    Assert-Contains "P0-013 issue" $issue $text
}

foreach ($text in @(
    "P0-013",
    "sensor_qos_reliability",
    "qos_depth",
    "BestEffort",
    "Reliable",
    "runtime/results/qos",
    "p0_013_qos_results.csv"
)) {
    Assert-Contains "interface contract" $interfaceContract $text
}

foreach ($text in @(
    "P0-013",
    "QoS experiment runner",
    "100Hz",
    "200Hz",
    "runtime/results/qos"
)) {
    Assert-Contains "M6 backlog" $m6 $text
}

foreach ($text in @(
    "P0-013_RESULT",
    "PASS/FAIL: PASS",
    "scenario count: 8",
    "qos_100hz_best_effort_depth10",
    "qos_200hz_reliable_depth50",
    "Observed Tradeoffs"
)) {
    Assert-Contains "P0-013 pass fixture" $passFixture $text
}

foreach ($text in @(
    "P0-013_RESULT",
    "PASS/FAIL: FAIL",
    "scenario count: 4",
    "Blocker if FAIL:"
)) {
    Assert-Contains "P0-013 fail fixture" $failFixture $text
}

Write-Host "P0-013 QoS experiment static checks passed"
