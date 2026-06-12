param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$startPath = Join-Path $RepoRoot "scripts/start_runtime.sh"
$stopPath = Join-Path $RepoRoot "scripts/stop_runtime.sh"
$smokePath = Join-Path $RepoRoot "scripts/run_p0_015_runtime_lifecycle_smoke.sh"
$smokeVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_015_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_015_completion_gate.ps1"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/runtime_lifecycle.md"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-015_project_local_start_stop_runtime_scripts.md"
$indexPath = Join-Path $RepoRoot "docs/backlog/issues/INDEX.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$setupShPath = Join-Path $RepoRoot "scripts/setup_runtime_dirs.sh"
$setupPs1Path = Join-Path $RepoRoot "scripts/setup_runtime_dirs.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_015_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_015_smoke_report_fail.txt"

$requiredFiles = @(
    @($startPath, "scripts/start_runtime.sh"),
    @($stopPath, "scripts/stop_runtime.sh"),
    @($smokePath, "scripts/run_p0_015_runtime_lifecycle_smoke.sh"),
    @($smokeVerifierPath, "scripts/verify_p0_015_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_015_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/runtime_lifecycle.md"),
    @($issuePath, "P0-015 issue"),
    @($indexPath, "issue index"),
    @($scriptsReadmePath, "scripts README"),
    @($passFixturePath, "P0-015 pass fixture"),
    @($failFixturePath, "P0-015 fail fixture")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-015 runtime lifecycle files: $($missing -join ', ')"
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

$start = Get-Content -Raw -LiteralPath $startPath
$stop = Get-Content -Raw -LiteralPath $stopPath
$smoke = Get-Content -Raw -LiteralPath $smokePath
$smokeVerifier = Get-Content -Raw -LiteralPath $smokeVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$issue = Get-Content -Raw -LiteralPath $issuePath
$index = Get-Content -Raw -LiteralPath $indexPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$setupSh = Get-Content -Raw -LiteralPath $setupShPath
$setupPs1 = Get-Content -Raw -LiteralPath $setupPs1Path
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "#!/usr/bin/env bash",
    'RUN_DIR="$RUNTIME_DIR/run/p0_runtime"',
    'LOG_DIR="$RUNTIME_DIR/logs/runtime"',
    'MANIFEST="$RUN_DIR/manifest.tsv"',
    'ROS_SETUP="/opt/ros/humble/setup.bash"',
    'WORKSPACE_SETUP="$REPO_ROOT/ros2_ws/install/setup.bash"',
    "source_setup_with_nounset_disabled",
    "manifest_has_live_processes",
    "launch_component",
    "wait_for_topic_type",
    "edge_reliability_fake_sensor fake_sensor.launch.py",
    "edge_reliability_processor processor.launch.py",
    "edge_reliability_system system_metrics.launch.py",
    "edge_reliability_health health_monitor.launch.py",
    "/edge/health/state",
    "runtime started"
)) {
    Assert-Contains "scripts/start_runtime.sh" $start $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    'RUN_DIR="$RUNTIME_DIR/run/p0_runtime"',
    'LOG_DIR="$RUNTIME_DIR/logs/runtime"',
    'MANIFEST="$RUN_DIR/manifest.tsv"',
    "mapfile -t MANIFEST_LINES",
    "stop_pid",
    "signal_process_tree",
    "manifest.stopped",
    "status=stopped"
)) {
    Assert-Contains "scripts/stop_runtime.sh" $stop $text
}

foreach ($text in @(
    "P0-015_RESULT",
    'bash "$SCRIPT_DIR/start_runtime.sh"',
    'bash "$SCRIPT_DIR/stop_runtime.sh"',
    "/fake_sensor_adapter",
    "/sensor_processor",
    "/system_metrics_node",
    "/health_monitor",
    "/edge/health/state [edge_reliability_msgs/msg/HealthState]",
    "check_manifest_pids_stopped",
    'LOG_DIR="$RUNTIME_DIR/logs/runtime"',
    'RUN_DIR="$RUNTIME_DIR/run/p0_runtime"'
)) {
    Assert-Contains "scripts/run_p0_015_runtime_lifecycle_smoke.sh" $smoke $text
}

foreach ($nameAndContent in @(
    @("scripts/start_runtime.sh", $start),
    @("scripts/stop_runtime.sh", $stop),
    @("scripts/run_p0_015_runtime_lifecycle_smoke.sh", $smoke)
)) {
    $name = $nameAndContent[0]
    $content = $nameAndContent[1]
    foreach ($forbidden in @(
        "systemctl",
        "sudo ",
        ".bashrc",
        ".profile",
        "/var/log",
        "/etc/systemd",
        "rm -rf"
    )) {
        Assert-NotContains $name $content $forbidden
    }
}

foreach ($text in @(
    "P0-015_RESULT",
    "PASS/FAIL: PASS",
    "start exit status: 0",
    "stop exit status: 0",
    "run dir:",
    "log dir:",
    "node list:",
    "/fake_sensor_adapter",
    "/health_monitor",
    "health echo once:",
    "pid check:",
    "stopped:",
    "P0-015 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_015_smoke_report.ps1" $smokeVerifier $text
}

foreach ($text in @(
    "verify_p0_015_runtime_scripts.ps1",
    "verify_p0_015_smoke_report.ps1",
    "P0-015 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_015_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# Runtime Lifecycle Scripts",
    "start_runtime.sh",
    "stop_runtime.sh",
    "runtime/run/p0_runtime/manifest.tsv",
    "runtime/logs/runtime/",
    "do not claim to supervise or restart crashed nodes"
)) {
    Assert-Contains "docs/runbooks/runtime_lifecycle.md" $runbook $text
}

foreach ($text in @(
    "Status: completed, Jetson verified 2026-06-12",
    "scripts/start_runtime.sh",
    "scripts/stop_runtime.sh",
    "runtime/run/p0_runtime",
    "runtime/logs/runtime",
    "Jetson verification evidence",
    "SMOKE_EXIT_STATUS=0",
    "Manifest PID checks reported all four project-started process trees stopped"
)) {
    Assert-Contains "P0-015 issue" $issue $text
}

foreach ($text in @(
    "P0-015",
    "start/stop runtime"
)) {
    Assert-Contains "issue index" $index $text
}
Assert-NotContains "issue index" $index "Jetson smoke"

foreach ($text in @(
    "start_runtime.sh",
    "stop_runtime.sh",
    "run_p0_015_runtime_lifecycle_smoke.sh",
    "verify_p0_015_runtime_scripts.ps1",
    "verify_p0_015_smoke_report.ps1",
    "verify_p0_015_completion_gate.ps1"
)) {
    Assert-Contains "scripts README" $scriptsReadme $text
}

foreach ($text in @(
    '"${RUNTIME_DIR}/run"',
    "- run/"
)) {
    Assert-Contains "scripts/setup_runtime_dirs.sh" $setupSh $text
}

foreach ($text in @(
    '"run"',
    "- run/"
)) {
    Assert-Contains "scripts/setup_runtime_dirs.ps1" $setupPs1 $text
}

foreach ($text in @(
    "P0-015_RESULT",
    "PASS/FAIL: PASS",
    "start exit status: 0",
    "stop exit status: 0",
    "/fake_sensor_adapter",
    "stopped: label=fake_sensor"
)) {
    Assert-Contains "P0-015 pass fixture" $passFixture $text
}

foreach ($text in @(
    "P0-015_RESULT",
    "PASS/FAIL: FAIL",
    "Blocker if FAIL:"
)) {
    Assert-Contains "P0-015 fail fixture" $failFixture $text
}

Write-Host "P0-015 runtime script static checks passed"
