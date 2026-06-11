param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$packageDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_processor"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_007_processor_smoke.sh"
$smokeReportVerifierPath = Join-Path $RepoRoot "scripts/verify_p0_007_smoke_report.ps1"
$completionGatePath = Join-Path $RepoRoot "scripts/verify_p0_007_completion_gate.ps1"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$workspaceReadmePath = Join-Path $RepoRoot "ros2_ws/src/README.md"
$rootReadmePath = Join-Path $RepoRoot "README.md"
$interfaceContractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"
$passFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_007_smoke_report_pass.txt"
$failFixturePath = Join-Path $RepoRoot "scripts/testdata/p0_007_smoke_report_fail.txt"
$requiredFiles = @(
    "package.xml",
    "CMakeLists.txt",
    "include/edge_reliability_processor/pipeline_metrics_accumulator.hpp",
    "src/sensor_processor.cpp",
    "test/pipeline_metrics_accumulator_test.cpp",
    "launch/processor.launch.py",
    "config/processor.yaml",
    "README.md"
)

$missing = @()
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $packageDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missing += $relativePath
    }
}

foreach ($pathAndName in @(
    @($smokeScriptPath, "scripts/run_p0_007_processor_smoke.sh"),
    @($smokeReportVerifierPath, "scripts/verify_p0_007_smoke_report.ps1"),
    @($completionGatePath, "scripts/verify_p0_007_completion_gate.ps1"),
    @($scriptsReadmePath, "scripts/README.md"),
    @($workspaceReadmePath, "ros2_ws/src/README.md"),
    @($rootReadmePath, "README.md"),
    @($interfaceContractPath, "docs/interfaces/edge_reliability_contract.md"),
    @($passFixturePath, "scripts/testdata/p0_007_smoke_report_pass.txt"),
    @($failFixturePath, "scripts/testdata/p0_007_smoke_report_fail.txt")
)) {
    if (-not (Test-Path -LiteralPath $pathAndName[0] -PathType Leaf)) {
        $missing += $pathAndName[1]
    }
}

if ($missing.Count -gt 0) {
    throw "Missing P0-007 processor metrics files: $($missing -join ', ')"
}

function Read-PackageFile {
    param([string]$RelativePath)
    return Get-Content -Raw -LiteralPath (Join-Path $packageDir $RelativePath)
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

$packageXml = Read-PackageFile "package.xml"
$cmake = Read-PackageFile "CMakeLists.txt"
$accumulatorHeader = Read-PackageFile "include/edge_reliability_processor/pipeline_metrics_accumulator.hpp"
$source = Read-PackageFile "src/sensor_processor.cpp"
$testSource = Read-PackageFile "test/pipeline_metrics_accumulator_test.cpp"
$launch = Read-PackageFile "launch/processor.launch.py"
$config = Read-PackageFile "config/processor.yaml"
$readme = Read-PackageFile "README.md"
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$smokeReportVerifier = Get-Content -Raw -LiteralPath $smokeReportVerifierPath
$completionGate = Get-Content -Raw -LiteralPath $completionGatePath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath
$workspaceReadme = Get-Content -Raw -LiteralPath $workspaceReadmePath
$rootReadme = Get-Content -Raw -LiteralPath $rootReadmePath
$interfaceContract = Get-Content -Raw -LiteralPath $interfaceContractPath
$passFixture = Get-Content -Raw -LiteralPath $passFixturePath
$failFixture = Get-Content -Raw -LiteralPath $failFixturePath

foreach ($text in @(
    "<name>edge_reliability_processor</name>",
    "<depend>rclcpp</depend>",
    "<depend>edge_reliability_msgs</depend>",
    "<exec_depend>edge_reliability_fake_sensor</exec_depend>",
    "<exec_depend>launch_ros</exec_depend>",
    "<test_depend>ament_cmake_gtest</test_depend>"
)) {
    Assert-Contains "package.xml" $packageXml $text
}

foreach ($text in @(
    "project(edge_reliability_processor)",
    "find_package(rclcpp REQUIRED)",
    "find_package(edge_reliability_msgs REQUIRED)",
    "add_executable(sensor_processor src/sensor_processor.cpp)",
    "target_compile_features(sensor_processor PUBLIC cxx_std_17)",
    "target_include_directories(sensor_processor PUBLIC",
    "ament_target_dependencies(sensor_processor rclcpp edge_reliability_msgs)",
    "install(TARGETS",
    "install(DIRECTORY launch config",
    "if(BUILD_TESTING)",
    "find_package(ament_cmake_gtest REQUIRED)",
    "ament_add_gtest(pipeline_metrics_accumulator_test",
    "target_include_directories(pipeline_metrics_accumulator_test"
)) {
    Assert-Contains "CMakeLists.txt" $cmake $text
}

foreach ($text in @(
    "struct PipelineMetricsSnapshot",
    "class PipelineMetricsAccumulator",
    "void configure(",
    "void observe(",
    "PipelineMetricsSnapshot snapshot(",
    "uint64_t received_count",
    "uint64_t expected_count",
    "uint64_t dropped_count",
    "uint64_t out_of_order_count",
    "double receive_rate_hz",
    "double expected_rate_hz",
    "double average_latency_ms",
    "double p95_latency_ms",
    "double p99_latency_ms",
    "double drop_rate",
    "std::deque",
    "std::sort",
    "std::ceil"
)) {
    Assert-Contains "pipeline_metrics_accumulator.hpp" $accumulatorHeader $text
}

foreach ($text in @(
    "#include `"edge_reliability_msgs/msg/pipeline_metrics.hpp`"",
    "#include `"edge_reliability_msgs/msg/sensor_sample.hpp`"",
    "#include `"edge_reliability_processor/pipeline_metrics_accumulator.hpp`"",
    "Node(`"sensor_processor`")",
    "declare_parameter<std::string>(`"sensor_topic`", `"/edge/sensors/fake_primary`")",
    "declare_parameter<std::string>(`"metrics_topic`", `"/edge/metrics/pipeline`")",
    "declare_parameter<double>(`"expected_hz`", 100.0)",
    "declare_parameter<double>(`"metrics_publish_hz`", 1.0)",
    "declare_parameter<double>(`"latency_warn_ms`", 20.0)",
    "declare_parameter<double>(`"latency_unhealthy_ms`", 50.0)",
    "declare_parameter<int>(`"sensor_qos_depth`", 10)",
    "declare_parameter<int>(`"metrics_qos_depth`", 10)",
    "declare_parameter<double>(`"rate_window_seconds`", 5.0)",
    "declare_parameter<int>(`"latency_window_size`", 1000)",
    "rclcpp::QoS(rclcpp::KeepLast",
    ".best_effort()",
    ".reliable()",
    "create_subscription<edge_reliability_msgs::msg::SensorSample>",
    "create_publisher<edge_reliability_msgs::msg::PipelineMetrics>",
    "accumulator_.observe(",
    "message.received_count = snapshot.received_count;",
    "message.expected_count = snapshot.expected_count;",
    "message.dropped_count = snapshot.dropped_count;",
    "message.out_of_order_count = snapshot.out_of_order_count;",
    "message.receive_rate_hz = snapshot.receive_rate_hz;",
    "message.expected_rate_hz = snapshot.expected_rate_hz;",
    "message.average_latency_ms = snapshot.average_latency_ms;",
    "message.p95_latency_ms = snapshot.p95_latency_ms;",
    "message.p99_latency_ms = snapshot.p99_latency_ms;",
    "message.drop_rate = snapshot.drop_rate;",
    "event=startup",
    "event=first_receive",
    "event=first_metrics_publish",
    "RCLCPP_INFO"
)) {
    Assert-Contains "src/sensor_processor.cpp" $source $text
}

foreach ($text in @(
    "PipelineMetricsAccumulator",
    "ComputesRateLatencyAndSequenceGaps",
    "CountsOutOfOrderSamples",
    "EXPECT_EQ",
    "EXPECT_NEAR"
)) {
    Assert-Contains "test/pipeline_metrics_accumulator_test.cpp" $testSource $text
}

foreach ($text in @(
    "processor.yaml",
    "sensor_processor"
)) {
    Assert-Contains "launch/processor.launch.py" $launch $text
}

foreach ($text in @(
    "sensor_topic: /edge/sensors/fake_primary",
    "metrics_topic: /edge/metrics/pipeline",
    "expected_hz: 100.0",
    "metrics_publish_hz: 1.0",
    "latency_warn_ms: 20.0",
    "latency_unhealthy_ms: 50.0",
    "sensor_qos_depth: 10",
    "metrics_qos_depth: 10",
    "rate_window_seconds: 5.0",
    "latency_window_size: 1000"
)) {
    Assert-Contains "config/processor.yaml" $config $text
}

foreach ($text in @(
    "colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install",
    "colcon test --packages-select edge_reliability_processor",
    "ros2 launch edge_reliability_processor processor.launch.py",
    "ros2 topic info /edge/metrics/pipeline -v",
    "ros2 topic echo --once /edge/metrics/pipeline edge_reliability_msgs/msg/PipelineMetrics",
    "bash scripts/run_p0_007_processor_smoke.sh",
    "runtime/bags/p0-007",
    "average_latency_ms",
    "p95_latency_ms",
    "p99_latency_ms",
    "drop_rate",
    "After the report is copied back to a Windows checkout",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_p0_007_completion_gate.ps1"
)) {
    Assert-Contains "README.md" $readme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-007_RESULT",
    'SENSOR_TOPIC="/edge/sensors/fake_primary"',
    'METRICS_TOPIC="/edge/metrics/pipeline"',
    'METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"',
    "colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install",
    "colcon test --packages-select edge_reliability_processor",
    "ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py",
    "ros2 launch edge_reliability_processor processor.launch.py",
    'ros2 topic info "$METRICS_TOPIC" -v',
    'ros2 topic echo --once "$METRICS_TOPIC" "$METRICS_TYPE"',
    "measure_sensor_hz_with_best_effort",
    "measure_metrics_hz_with_reliable",
    "QoSReliabilityPolicy.BEST_EFFORT",
    "QoSReliabilityPolicy.RELIABLE",
    'grep -F "Type: $METRICS_TYPE" "$METRICS_TOPIC_INFO"',
    'grep -F "Node name: sensor_processor" "$METRICS_TOPIC_INFO"',
    "received_count:",
    "average_latency_ms:",
    "p95_latency_ms:",
    "p99_latency_ms:",
    "drop_rate:",
    'grep -F "event=startup" "$PROCESSOR_LAUNCH_LOG"',
    'grep -F "event=first_receive" "$PROCESSOR_LAUNCH_LOG"',
    'grep -F "event=first_metrics_publish" "$PROCESSOR_LAUNCH_LOG"',
    'ros2 bag record "$SENSOR_TOPIC" "$METRICS_TOPIC"',
    'ros2 bag info "$BAG_DIR"',
    "runtime/results",
    "runtime/logs",
    "runtime/bags/p0-007",
    "source_setup_with_nounset_disabled",
    "CLEANUP_INT_WAIT_SECONDS=8",
    "CLEANUP_TERM_WAIT_SECONDS=5",
    "signal_process_tree",
    "wait_for_background_process_exit",
    "stop_background_process",
    "signal_process_tree INT",
    "signal_process_tree TERM",
    "signal_process_tree KILL",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_007_processor_smoke.sh" $smokeScript $text
}

Assert-NotContains "scripts/run_p0_007_processor_smoke.sh" $smokeScript 'ros2 topic hz "$SENSOR_TOPIC" --qos-reliability best_effort'

foreach ($text in @(
    "param(",
    "p0_007_smoke_report.txt",
    "P0-007_RESULT",
    "PASS/FAIL: PASS",
    "colcon exit status: 0",
    "colcon test exit status: 0",
    "Type: edge_reliability_msgs/msg/PipelineMetrics",
    "Node name: sensor_processor",
    "received_count:",
    "receive_rate_hz:",
    "average_latency_ms:",
    "p95_latency_ms:",
    "p99_latency_ms:",
    "drop_rate:",
    "sensor last average rate:",
    "metrics last average rate:",
    "bag messages:",
    "runtime/bags/p0-007",
    "P0-007 smoke report checks passed"
)) {
    Assert-Contains "scripts/verify_p0_007_smoke_report.ps1" $smokeReportVerifier $text
}

foreach ($text in @(
    "P0-007_RESULT",
    "PASS/FAIL: PASS",
    "sensor last average rate: 99.8",
    "metrics last average rate: 1.0",
    "bag messages: 770"
)) {
    Assert-Contains "scripts/testdata/p0_007_smoke_report_pass.txt" $passFixture $text
}

foreach ($text in @(
    "P0-007_RESULT",
    "PASS/FAIL: FAIL",
    "sensor last average rate: 12.0",
    "Blocker if FAIL:"
)) {
    Assert-Contains "scripts/testdata/p0_007_smoke_report_fail.txt" $failFixture $text
}

foreach ($text in @(
    "param(",
    "verify_p0_007_processor_metrics_slice.ps1",
    "verify_p0_007_smoke_report.ps1",
    "P0-007 completion gate checks passed"
)) {
    Assert-Contains "scripts/verify_p0_007_completion_gate.ps1" $completionGate $text
}

foreach ($text in @(
    "run_p0_007_processor_smoke.sh",
    "verify_p0_007_processor_metrics_slice.ps1",
    "verify_p0_007_smoke_report.ps1",
    "verify_p0_007_completion_gate.ps1",
    "P0-007",
    "runtime/results"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

foreach ($text in @(
    "edge_reliability_processor",
    "processor metrics subscriber"
)) {
    Assert-Contains "ros2_ws/src/README.md" $workspaceReadme $text
}

foreach ($text in @(
    "P0-007 processor metrics package",
    "ros2_ws/src/edge_reliability_processor/README.md"
)) {
    Assert-Contains "README.md" $rootReadme $text
}

foreach ($text in @(
    "P0-007",
    "/edge/metrics/pipeline",
    "sensor_processor",
    "PipelineMetrics",
    "average_latency_ms",
    "p95_latency_ms",
    "p99_latency_ms",
    "milliseconds",
    "5 second",
    "latency_window_size"
)) {
    Assert-Contains "docs/interfaces/edge_reliability_contract.md" $interfaceContract $text
}

Write-Host "P0-007 processor metrics static checks passed"
