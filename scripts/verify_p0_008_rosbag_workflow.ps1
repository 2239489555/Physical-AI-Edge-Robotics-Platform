param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_008_rosbag_replay_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_008_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_008_completion_gate.ps1"
$workflowDocPath = Join-Path $RepoRoot "docs/runbooks/rosbag_record_replay_workflow.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$rootReadmePath = Join-Path $RepoRoot "README.md"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-008_rosbag_record_replay_workflow.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_008_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_008_smoke_report_fail.txt"

$missing = @()
foreach ($pathAndName in @(
    @($smokeScriptPath, "scripts/run_p0_008_rosbag_replay_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_008_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_008_completion_gate.ps1"),
    @($workflowDocPath, "docs/runbooks/rosbag_record_replay_workflow.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($rootReadmePath, "README.md"),
    @($issuePath, "docs/backlog/issues/P0-008_rosbag_record_replay_workflow.md"),
    @($interfaceContractPath, "docs/interfaces/edge_reliability_contract.md"),
    @($passFixturePath, "scripts/testdata/p0_008_smoke_report_pass.txt"),
    @($failFixturePath, "scripts/testdata/p0_008_smoke_report_fail.txt")
)) {
    if (-not (Test-Path -LiteralPath $pathAndName[0] -PathType Leaf)) {
        $missing += $pathAndName[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-008 rosbag workflow files: $($missing -join ', ')"
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

$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeReportVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$workflowDoc = Get-Content -Raw -LiteralPath $workflowDocPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$rootReadme = Get-Content -Raw -LiteralPath $rootReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-008_RESULT",
    'SCENARIO="${P0_008_SCENARIO:-normal_replay}"',
    'SENSOR_TOPIC="/edge/sensors/fake_primary"',
    'METRICS_TOPIC="/edge/metrics/pipeline"',
    'SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"',
    'METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"',
    'BAG_PARENT="$RUNTIME_DIR/bags/p0-008"',
    'BAG_DIR="$BAG_PARENT/${SCENARIO}_${RUN_STAMP}"',
    "sanitize_scenario_name",
    "colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install",
    "colcon test --packages-select edge_reliability_processor",
    "ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py",
    'ros2 bag record "$SENSOR_TOPIC" -o "$BAG_DIR"',
    'ros2 bag info "$BAG_DIR"',
    "stop_background_process",
    "cleanup_launches",
    "ros2 launch edge_reliability_processor processor.launch.py",
    'ros2 bag play "$BAG_DIR"',
    "capture_replay_metrics",
    "QoSReliabilityPolicy.RELIABLE",
    "PipelineMetrics",
    "recorded sensor messages:",
    "replay metrics messages:",
    "replay received count:",
    "replay receive ratio:",
    "replay drop rate:",
    "replay out_of_order count:",
    "runtime/bags/p0-008",
    "runtime/results",
    "runtime/logs",
    "git status --short --ignored",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_008_rosbag_replay_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    'rm -rf',
    'sudo ',
    '/tmp/p0-008',
    'ros2 bag record "$SENSOR_TOPIC" "$METRICS_TOPIC" -o "$BAG_DIR"'
)) {
    Assert-NotContains "scripts/run_p0_008_rosbag_replay_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "param(",
    "p0_008_smoke_report.txt",
    "P0-008_RESULT",
    "PASS/FAIL: PASS",
    "scenario: normal_replay",
    "recorded topic: /edge/sensors/fake_primary",
    "recorded sensor messages:",
    "replay metrics messages:",
    "replay received count:",
    "replay receive ratio:",
    "replay drop rate:",
    "replay out_of_order count:",
    "runtime/bags/p0-008",
    "P0-008 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_008_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "param(",
    "verify_p0_008_rosbag_workflow.ps1",
    "verify_p0_008_smoke_report.ps1",
    "P0-008 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_008_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# Rosbag Record And Replay Workflow",
    "P0-008",
    "normal replay",
    "runtime/bags/p0-008",
    "scenario name",
    "timestamp",
    "record /edge/sensors/fake_primary only",
    "do not replay /edge/metrics/pipeline while sensor_processor is publishing",
    "ros2 bag record /edge/sensors/fake_primary",
    "ros2 bag play",
    "received_count",
    "90%",
    "fault cases",
    "Replay latency caveat",
    "original wall-clock timestamp",
    "compare count, rate, drop, and order metrics"
)) {
    Assert-Contains "docs/runbooks/rosbag_record_replay_workflow.md" $workflowDoc $text
}

foreach ($text in @(
    "run_p0_008_rosbag_replay_smoke.sh",
    "verify_p0_008_rosbag_workflow.ps1",
    "verify_p0_008_smoke_report.ps1",
    "verify_p0_008_completion_gate.ps1",
    "P0-008",
    "runtime/bags/p0-008"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "P0-008 rosbag record/replay workflow",
    "docs/runbooks/rosbag_record_replay_workflow.md"
)) {
    Assert-Contains "README.md" $rootReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "scripts/run_p0_008_rosbag_replay_smoke.sh",
    "normal_replay",
    "runtime/bags/p0-008",
    "Completion requires returned Jetson smoke evidence"
)) {
    Assert-Contains "docs/backlog/issues/P0-008_rosbag_record_replay_workflow.md" $issue $text
}

foreach ($text in @(
    "P0-008",
    "normal replay",
    "runtime/bags/p0-008",
    "record raw sensor bags",
    "do not replay /edge/metrics/pipeline"
)) {
    Assert-Contains "docs/interfaces/edge_reliability_contract.md" $interfaceContract $text
}

foreach ($text in @(
    "P0-008_RESULT",
    "PASS/FAIL: PASS",
    "scenario: normal_replay",
    "recorded sensor messages: 760",
    "replay metrics messages: 8",
    "replay received count: 758",
    "replay receive ratio: 0.997",
    "replay drop rate: 0.0",
    "runtime/bags/p0-008"
)) {
    Assert-Contains "scripts/testdata/p0_008_smoke_report_pass.txt" $passFixture $text
}

foreach ($text in @(
    "P0-008_RESULT",
    "PASS/FAIL: FAIL",
    "scenario: normal_replay",
    "recorded sensor messages: 760",
    "replay received count: 100",
    "Blocker if FAIL:"
)) {
    Assert-Contains "scripts/testdata/p0_008_smoke_report_fail.txt" $failFixture $text
}

Write-Host "P0-008 rosbag workflow static checks passed"
