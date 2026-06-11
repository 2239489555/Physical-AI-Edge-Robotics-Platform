param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$systemDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_system"
$issuePath = Join-Path $RepoRoot "docs/backlog/issues/P0-011_tegrastats_parser_ros2_system_metrics_node.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$runbookPath = Join-Path $RepoRoot "docs/runbooks/tegrastats_system_metrics.md"
$m5Path = Join-Path $RepoRoot "docs/backlog/M5_tegrastats_monitor.md"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_011_system_metrics_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_011_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_011_completion_gate.ps1"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_011_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_011_smoke_report_fail.txt"

$requiredFiles = @(
    @((Join-Path $systemDir "CMakeLists.txt"), "edge_reliability_system CMakeLists.txt"),
    @((Join-Path $systemDir "package.xml"), "edge_reliability_system package.xml"),
    @((Join-Path $systemDir "include/edge_reliability_system/tegrastats_parser.hpp"), "tegrastats parser header"),
    @((Join-Path $systemDir "src/system_metrics_node.cpp"), "system metrics node source"),
    @((Join-Path $systemDir "test/tegrastats_parser_test.cpp"), "tegrastats parser test"),
    @((Join-Path $systemDir "config/system_metrics.yaml"), "system metrics config"),
    @((Join-Path $systemDir "launch/system_metrics.launch.py"), "system metrics launch"),
    @((Join-Path $systemDir "testdata/tegrastats_samples.txt"), "tegrastats sample data"),
    @((Join-Path $systemDir "README.md"), "system README"),
    @($smokeScriptPath, "scripts/run_p0_011_system_metrics_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_011_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_011_completion_gate.ps1"),
    @($runbookPath, "docs/runbooks/tegrastats_system_metrics.md"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($issuePath, "docs/backlog/issues/P0-011_tegrastats_parser_ros2_system_metrics_node.md"),
    @($interfaceContractPath, "docs/interfaces/edge_reliability_contract.md"),
    @($m5Path, "docs/backlog/M5_tegrastats_monitor.md"),
    @($passFixturePath, "scripts/testdata/p0_011_smoke_report_pass.txt"),
    @($failFixturePath, "scripts/testdata/p0_011_smoke_report_fail.txt")
)

$missing = @()
foreach ($entry in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) {
        $missing += $entry[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-011 system metrics files: $($missing -join ', ')"
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

$cmake = Get-Content -Raw -LiteralPath (Join-Path $systemDir "CMakeLists.txt")
$packageXml = Get-Content -Raw -LiteralPath (Join-Path $systemDir "package.xml")
$parserHeader = Get-Content -Raw -LiteralPath (Join-Path $systemDir "include/edge_reliability_system/tegrastats_parser.hpp")
$source = Get-Content -Raw -LiteralPath (Join-Path $systemDir "src/system_metrics_node.cpp")
$test = Get-Content -Raw -LiteralPath (Join-Path $systemDir "test/tegrastats_parser_test.cpp")
$config = Get-Content -Raw -LiteralPath (Join-Path $systemDir "config/system_metrics.yaml")
$launch = Get-Content -Raw -LiteralPath (Join-Path $systemDir "launch/system_metrics.launch.py")
$samples = Get-Content -Raw -LiteralPath (Join-Path $systemDir "testdata/tegrastats_samples.txt")
$readme = Get-Content -Raw -LiteralPath (Join-Path $systemDir "README.md")
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeReportVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$runbook = Get-Content -Raw -LiteralPath $runbookPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$issue = Get-Content -Raw -LiteralPath $issuePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$m5 = Get-Content -Raw -LiteralPath $m5Path
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "project(edge_reliability_system)",
    "add_executable(system_metrics_node src/system_metrics_node.cpp)",
    "ament_target_dependencies(system_metrics_node rclcpp edge_reliability_msgs)",
    "ament_add_gtest(tegrastats_parser_test"
)) {
    Assert-Contains "edge_reliability_system CMakeLists.txt" $cmake $text
}

foreach ($text in @(
    "<name>edge_reliability_system</name>",
    "<depend>rclcpp</depend>",
    "<depend>edge_reliability_msgs</depend>"
)) {
    Assert-Contains "edge_reliability_system package.xml" $packageXml $text
}

foreach ($text in @(
    "struct TegrastatsMetrics",
    "parse_tegrastats_line",
    "RAM\s+",
    "SWAP\s+",
    "CPU\s+\[",
    "GR3D_FREQ",
    "temperature_c",
    "power_w",
    "VDD|VIN"
)) {
    Assert-Contains "tegrastats_parser.hpp" $parserHeader $text
}

foreach ($text in @(
    "create_publisher<edge_reliability_msgs::msg::SystemMetrics>",
    "declare_parameter<std::string>(`"input_mode`", `"sample_file`")",
    "declare_parameter<std::string>(`"live_command`", `"timeout 2s tegrastats --interval 1000`")",
    "raw_log_enabled",
    "parse_tegrastats_line",
    "message.cpu_percent",
    "message.memory_used_mb",
    "message.gpu_percent",
    "message.temperature_c",
    "message.power_w",
    "tegrastats_sample_file",
    "tegrastats_live_command",
    "event=first_publish"
)) {
    Assert-Contains "system_metrics_node.cpp" $source $text
}

foreach ($text in @(
    "ParsesRepresentativeOrinLine",
    "HandlesLegacyLineWithOffCpuCore",
    "RejectsNonTegrastatsLine",
    "EXPECT_NEAR(parsed->power_w"
)) {
    Assert-Contains "tegrastats_parser_test.cpp" $test $text
}

foreach ($text in @(
    "metrics_topic: /edge/metrics/system",
    "input_mode: sample_file",
    "live_command: `"timeout 2s tegrastats --interval 1000`"",
    "raw_log_enabled: true",
    "runtime/logs/tegrastats"
)) {
    Assert-Contains "system_metrics.yaml" $config $text
}

foreach ($text in @(
    "FindPackageShare(`"edge_reliability_system`")",
    "tegrastats_samples.txt",
    "raw_log_path",
    "executable=`"system_metrics_node`""
)) {
    Assert-Contains "system_metrics.launch.py" $launch $text
}

foreach ($text in @(
    "RAM ",
    "SWAP ",
    "CPU [",
    "GR3D_FREQ",
    "VDD_GPU_SOC",
    "VIN_SYS_5V0"
)) {
    Assert-Contains "tegrastats_samples.txt" $samples $text
}

foreach ($text in @(
    "/edge/metrics/system",
    "edge_reliability_msgs/msg/SystemMetrics",
    "tegrastats",
    '`nvidia-smi` is not enough',
    "sample_file",
    "live_command",
    "runtime/logs/tegrastats",
    "scripts/run_p0_011_system_metrics_smoke.sh"
)) {
    Assert-Contains "edge_reliability_system README" $readme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-011_RESULT",
    'SYSTEM_TOPIC="/edge/metrics/system"',
    'SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"',
    "edge_reliability_system",
    "system_metrics.launch.py",
    "capture_system_metrics_summary",
    "raw tegrastats log path:",
    "live tegrastats status:",
    "tegrastats_sample_file",
    "package had stderr output",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_011_system_metrics_smoke.sh" $smokeScript $text
}

foreach ($forbidden in @(
    "sudo ",
    "rm -rf",
    "/tmp/p0-011"
)) {
    Assert-NotContains "scripts/run_p0_011_system_metrics_smoke.sh" $smokeScript $forbidden
}

foreach ($text in @(
    "P0-011_RESULT",
    "PASS/FAIL: PASS",
    "system messages:",
    "memory used mb:",
    "source: tegrastats_sample_file",
    "raw tegrastats log lines:",
    "live tegrastats status:",
    "package had stderr output",
    "P0-011 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_011_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "verify_p0_011_system_metrics.ps1",
    "verify_p0_011_smoke_report.ps1",
    "P0-011 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_011_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "# tegrastats System Metrics",
    "P0-011",
    "/edge/metrics/system",
    "SystemMetrics",
    "tegrastats",
    "sample_file",
    "live_command",
    "runtime/logs/tegrastats",
    "nvidia-smi"
)) {
    Assert-Contains "docs/runbooks/tegrastats_system_metrics.md" $runbook $text
}

foreach ($text in @(
    "run_p0_011_system_metrics_smoke.sh",
    "verify_p0_011_system_metrics.ps1",
    "verify_p0_011_smoke_report.ps1",
    "verify_p0_011_completion_gate.ps1",
    "P0-011"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "Implementation notes",
    "edge_reliability_system",
    "scripts/run_p0_011_system_metrics_smoke.sh",
    "Completion requires returned Jetson smoke evidence"
)) {
    Assert-Contains "docs/backlog/issues/P0-011_tegrastats_parser_ros2_system_metrics_node.md" $issue $text
}

foreach ($text in @(
    "P0-011",
    "edge_reliability_system",
    "system_metrics_node",
    "input_mode",
    "live_command",
    "raw_log_path",
    "/edge/metrics/system"
)) {
    Assert-Contains "docs/interfaces/edge_reliability_contract.md" $interfaceContract $text
}

foreach ($text in @(
    "P0-011",
    "edge_reliability_system",
    "runtime/logs/tegrastats"
)) {
    Assert-Contains "docs/backlog/M5_tegrastats_monitor.md" $m5 $text
}

foreach ($text in @(
    "P0-011_RESULT",
    "PASS/FAIL: PASS",
    "system messages: 6",
    "source: tegrastats_sample_file",
    "raw tegrastats log lines: 6",
    "live tegrastats status:"
)) {
    Assert-Contains "scripts/testdata/p0_011_smoke_report_pass.txt" $passFixture $text
}

foreach ($text in @(
    "P0-011_RESULT",
    "PASS/FAIL: FAIL",
    "package had stderr output",
    "Blocker if FAIL:"
)) {
    Assert-Contains "scripts/testdata/p0_011_smoke_report_fail.txt" $failFixture $text
}

Write-Host "P0-011 system metrics static checks passed"
