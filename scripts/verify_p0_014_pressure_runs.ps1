param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-014_pressure_runs_500_1000hz_bottleneck_report.md"
$indexPath = Join-Path $RepoRoot "docs/backlog/issues/INDEX.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/pressure_experiment_runner.md"
$m6Path = Join-Path $RepoRoot "docs/backlog/M6_qos_latency_drop_lab.md"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_014_pressure_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_014_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_014_completion_gate.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_014_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_014_smoke_report_fail.txt"

$requiredFiles = @(
    @($smokeScriptPath, "scripts/run_p0_014_pressure_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_014_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_014_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/pressure_experiment_runner.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "P0-014 issue"),
    @($indexPath, "issue index"),
    @($interfaceContractPath, "interface contract"),
    @($m6Path, "M6 backlog"),
    @($passFixturePath, "P0-014 pass fixture"),
    @($failFixturePath, "P0-014 fail fixture")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-014 pressure-run files: $($missing -join ', ')"
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
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$index = Get-Content -Raw -LiteralPath $indexPath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$m6 = Get-Content -Raw -LiteralPath $m6Path
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-014_RESULT",
    'QOS_RESULT_DIR="$RESULT_DIR/qos"',
    'QOS_LOG_DIR="$LOG_DIR/qos"',
    'QOS_BAG_DIR="$RUNTIME_DIR/bags/qos"',
    'TMP_DIR="$RUNTIME_DIR/tmp/p0-014"',
    "as_yaml_double",
    "write_fake_config",
    "write_processor_config",
    "pressure_note",
    "run_pressure_scenario",
    "for hz in 500 1000",
    "for reliability in best_effort reliable",
    "for depth in 10 50",
    '"best_effort" "reliable" 10 "qos_mismatch"',
    "launch_and_check ACTIVE_FAKE_PID",
    "launch_and_check ACTIVE_PROCESSOR_PID",
    "launch_and_check ACTIVE_SYSTEM_PID",
    "p0 high-frequency stability required: no",
    "scenario count: `$SCENARIO_COUNT",
    "pressure scenario count: `$PRESSURE_SCENARIO_COUNT",
    "qos mismatch scenario count: `$MISMATCH_SCENARIO_COUNT",
    "target_ratio",
    "rate_gap_hz",
    'printf ''%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n''',
    "P0 Gate Separation",
    "Bottleneck Reading Guide",
    "QoS Mismatch",
    "runtime/results/qos",
    "runtime/logs/qos",
    "runtime/bags/qos",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_014_pressure_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    " /tmp/p0-014",
    "`n/tmp/p0-014",
    'ACTIVE_FAKE_PID="$(launch_and_check',
    'ACTIVE_PROCESSOR_PID="$(launch_and_check',
    'ACTIVE_SYSTEM_PID="$(launch_and_check',
    "publish_hz: `$hz`n",
    "expected_hz: `$hz`n"
)) {
    Assert-NotContains "scripts/run_p0_014_pressure_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "P0-014_RESULT",
    "PASS/FAIL: PASS",
    "scenario count: 10",
    "pressure scenario count: 8",
    "qos mismatch scenario count: 2",
    "frequencies: 500,1000",
    "p0 high-frequency stability required: no",
    "scenario_name,scenario_kind,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,target_ratio,rate_gap_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,metrics_messages,received_count,expected_count,dropped_count,notes",
    "qos_mismatch_500hz",
    "P0-014 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_014_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "verify_p0_014_pressure_runs.ps1",
    "verify_p0_014_smoke_report.ps1",
    "P0-014 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_014_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# Pressure Experiment Runner",
    "P0-014",
    "500Hz",
    "1000Hz",
    "BestEffort",
    "Reliable",
    "QoS mismatch",
    "target_ratio",
    "runtime/results/qos/p0_014_pressure_results.csv",
    "P0-014 does not require 500Hz or 1000Hz to be stable"
)) {
    Assert-Contains "docs/runbooks/pressure_experiment_runner.md" $runbook $text
}

foreach ($text in @(
    "run_p0_014_pressure_smoke.sh",
    "verify_p0_014_pressure_runs.ps1",
    "verify_p0_014_smoke_report.ps1",
    "verify_p0_014_completion_gate.ps1",
    "P0-014"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Status: completed, Jetson verified 2026-06-12",
    "Jetson verification evidence",
    "SMOKE_EXIT_STATUS=0",
    "scenario count: 10",
    "pressure scenario count: 8",
    "qos mismatch scenario count: 2",
    "scripts/run_p0_014_pressure_smoke.sh",
    "500Hz/1000Hz",
    "BestEffort publisher plus Reliable subscriber",
    "runtime/results/qos/p0_014_pressure_results.csv",
    "runtime/results/qos/p0_014_pressure_report.md",
    "RELIABILITY_QOS_POLICY",
    "received_count=0"
)) {
    Assert-Contains "P0-014 issue" $issue $text
}

foreach ($text in @(
    "P0-014",
    "500/1000Hz",
    "P0-015"
)) {
    Assert-Contains "issue index" $index $text
}

foreach ($text in @(
    "P0-006 through P0-014 Jetson verified",
    "P0-014 pressure experiment output",
    "run_p0_014_pressure_smoke.sh",
    "p0_014_pressure_results.csv",
    "BestEffort publisher with Reliable subscriber",
    "500Hz and 1000Hz stability is pressure evidence only",
    "SMOKE_EXIT_STATUS=0"
)) {
    Assert-Contains "interface contract" $interfaceContract $text
}

foreach ($text in @(
    "P0-014 pressure runner is completed",
    "500Hz/1000Hz",
    "QoS mismatch",
    "p0_014_pressure_results.csv",
    "SMOKE_EXIT_STATUS=0",
    "target_ratio=0.934"
)) {
    Assert-Contains "M6 backlog" $m6 $text
}

foreach ($text in @(
    "P0-014_RESULT",
    "PASS/FAIL: PASS",
    "scenario count: 10",
    "pressure_500hz_pub_best_effort_sub_best_effort_depth10",
    "pressure_1000hz_pub_reliable_sub_reliable_depth50",
    "qos_mismatch_1000hz_pub_best_effort_sub_reliable_depth10"
)) {
    Assert-Contains "P0-014 pass fixture" $passFixture $text
}

foreach ($text in @(
    "P0-014_RESULT",
    "PASS/FAIL: FAIL",
    "scenario count: 4",
    "Blocker if FAIL:"
)) {
    Assert-Contains "P0-014 fail fixture" $failFixture $text
}

Write-Host "P0-014 pressure-run static checks passed"
