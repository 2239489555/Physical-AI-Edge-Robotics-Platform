param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$fakeSensorDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_fake_sensor"
$processorDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_processor"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_009_fault_injection_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_009_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_009_completion_gate.ps1"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/fault_injection_drop_delay.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-009_fault_injection_drop_delay.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_009_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_009_smoke_report_fail.txt"

$requiredFiles = @(
    @((Join-Path $fakeSensorDir "src/fake_sensor_adapter.cpp"), "fake sensor source"),
    @((Join-Path $fakeSensorDir "config/fake_sensor.yaml"), "fake sensor normal config"),
    @((Join-Path $fakeSensorDir "config/fake_sensor_drop.yaml"), "fake sensor drop config"),
    @((Join-Path $fakeSensorDir "README.md"), "fake sensor README"),
    @((Join-Path $processorDir "src/sensor_processor.cpp"), "processor source"),
    @((Join-Path $processorDir "config/processor.yaml"), "processor normal config"),
    @((Join-Path $processorDir "config/processor_delay.yaml"), "processor delay config"),
    @((Join-Path $processorDir "README.md"), "processor README"),
    @($smokeScriptPath, "scripts/run_p0_009_fault_injection_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_009_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_009_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/fault_injection_drop_delay.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "docs/backlog/issues/P0-009_fault_injection_drop_delay.md"),
    @($interfaceContractPath, "docs/interfaces/edge_reliability_contract.md"),
    @($passFixturePath, "scripts/testdata/p0_009_smoke_report_pass.txt"),
    @($failFixturePath, "scripts/testdata/p0_009_smoke_report_fail.txt")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-009 fault injection files: $($missing -join ', ')"
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
$fakeConfig = Get-Content -Raw -LiteralPath (Join-Path $fakeSensorDir "config/fake_sensor.yaml")
$fakeDropConfig = Get-Content -Raw -LiteralPath (Join-Path $fakeSensorDir "config/fake_sensor_drop.yaml")
$fakeReadme = Get-Content -Raw -LiteralPath (Join-Path $fakeSensorDir "README.md")
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
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "#include <random>",
    "declare_parameter<bool>(`"drop_enabled`", false)",
    "declare_parameter<double>(`"drop_probability`", 0.0)",
    "declare_parameter<int>(`"drop_seed`", 1)",
    "std::mt19937",
    "std::uniform_real_distribution<double>",
    "should_drop_sample",
    "drop_enabled_",
    "drop_probability_",
    "drop_seed_",
    "dropped_injected_count_",
    "event=drop_injected",
    "event=first_drop_injected",
    "drop_probability=%.3f",
    "drop_seed=%d",
    "++sequence_id_;"
)) {
    Assert-Contains "fake_sensor_adapter.cpp" $fakeSource $text
}

foreach ($text in @(
    "drop_enabled: false",
    "drop_probability: 0.0",
    "drop_seed: 1"
)) {
    Assert-Contains "config/fake_sensor.yaml" $fakeConfig $text
}

foreach ($text in @(
    'fault_mode: "drop"',
    "drop_enabled: true",
    "drop_probability: 0.2",
    "drop_seed: 42"
)) {
    Assert-Contains "config/fake_sensor_drop.yaml" $fakeDropConfig $text
}

foreach ($text in @(
    "fake_sensor_drop.yaml",
    "drop_enabled",
    "drop_probability",
    "drop_seed",
    "sequence gaps",
    "scripts/run_p0_009_fault_injection_smoke.sh"
)) {
    Assert-Contains "edge_reliability_fake_sensor README" $fakeReadme $text
}

foreach ($text in @(
    "#include <thread>",
    "declare_parameter<bool>(`"processing_delay_enabled`", false)",
    "declare_parameter<double>(`"processing_delay_ms`", 0.0)",
    "processing_delay_enabled_",
    "processing_delay_ms_",
    "std::this_thread::sleep_for",
    "event=first_processing_delay",
    "processing_delay_ms=%.3f"
)) {
    Assert-Contains "sensor_processor.cpp" $processorSource $text
}

foreach ($text in @(
    "processing_delay_enabled: false",
    "processing_delay_ms: 0.0"
)) {
    Assert-Contains "config/processor.yaml" $processorConfig $text
}

foreach ($text in @(
    "processing_delay_enabled: true",
    "processing_delay_ms: 8.0"
)) {
    Assert-Contains "config/processor_delay.yaml" $processorDelayConfig $text
}

foreach ($text in @(
    "processor_delay.yaml",
    "processing_delay_enabled",
    "processing_delay_ms",
    "p95_latency_ms",
    "scripts/run_p0_009_fault_injection_smoke.sh"
)) {
    Assert-Contains "edge_reliability_processor README" $processorReadme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-009_RESULT",
    'SCENARIO_DROP="drop_fault"',
    'SCENARIO_DELAY="subscriber_delay"',
    'SENSOR_TOPIC="/edge/sensors/fake_primary"',
    'METRICS_TOPIC="/edge/metrics/pipeline"',
    "fake_sensor_drop.yaml",
    "processor_delay.yaml",
    "run_metric_scenario",
    "record_fault_bag",
    "capture_metrics_summary",
    "normal drop rate:",
    "drop fault drop rate:",
    "normal p95 latency ms:",
    "delay fault p95 latency ms:",
    "drop rate increase:",
    "p95 latency increase ms:",
    "runtime/bags/p0-009",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_009_fault_injection_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    "/tmp/p0-009"
)) {
    Assert-NotContains "scripts/run_p0_009_fault_injection_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "param(",
    "p0_009_smoke_report.txt",
    "P0-009_RESULT",
    "PASS/FAIL: PASS",
    "normal drop rate:",
    "drop fault drop rate:",
    "drop rate increase:",
    "normal p95 latency ms:",
    "delay fault p95 latency ms:",
    "p95 latency increase ms:",
    "drop fault bag messages:",
    "delay fault bag messages:",
    "P0-009 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_009_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "verify_p0_009_fault_injection.ps1",
    "verify_p0_009_smoke_report.ps1",
    "P0-009 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_009_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# Fault Injection Drop And Delay",
    "P0-009",
    "drop_enabled",
    "drop_probability",
    "processing_delay_enabled",
    "processing_delay_ms",
    "drop_rate",
    "p95_latency_ms",
    "runtime/bags/p0-009",
    "normal vs fault",
    "rosbag"
)) {
    Assert-Contains "docs/runbooks/fault_injection_drop_delay.md" $runbook $text
}

foreach ($text in @(
    "run_p0_009_fault_injection_smoke.sh",
    "verify_p0_009_fault_injection.ps1",
    "verify_p0_009_smoke_report.ps1",
    "verify_p0_009_completion_gate.ps1",
    "P0-009",
    "runtime/bags/p0-009"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "scripts/run_p0_009_fault_injection_smoke.sh",
    "fake_sensor_drop.yaml",
    "processor_delay.yaml",
    "Completion requires returned Jetson smoke evidence"
)) {
    Assert-Contains "docs/backlog/issues/P0-009_fault_injection_drop_delay.md" $issue $text
}

foreach ($text in @(
    "P0-009",
    "drop_enabled",
    "drop_probability",
    "processing_delay_enabled",
    "processing_delay_ms",
    "drop_rate",
    "p95_latency_ms"
)) {
    Assert-Contains "docs/interfaces/edge_reliability_contract.md" $interfaceContract $text
}

foreach ($text in @(
    "P0-009_RESULT",
    "PASS/FAIL: PASS",
    "normal drop rate: 0.000000",
    "drop fault drop rate: 0.2",
    "drop rate increase:",
    "normal p95 latency ms:",
    "delay fault p95 latency ms:",
    "p95 latency increase ms:",
    "drop fault bag messages:",
    "delay fault bag messages:"
)) {
    Assert-Contains "scripts/testdata/p0_009_smoke_report_pass.txt" $passFixture $text
}

foreach ($text in @(
    "P0-009_RESULT",
    "PASS/FAIL: FAIL",
    "drop rate increase: 0.000000",
    "Blocker if FAIL:"
)) {
    Assert-Contains "scripts/testdata/p0_009_smoke_report_fail.txt" $failFixture $text
}

Write-Host "P0-009 fault injection static checks passed"
