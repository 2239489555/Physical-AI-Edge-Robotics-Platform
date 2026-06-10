param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$packageDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_msgs"
$contractPath = Join-Path $RepoRoot "docs/interfaces/edge_reliability_contract.md"

$requiredFiles = @(
    "package.xml",
    "CMakeLists.txt",
    "msg/SensorSample.msg",
    "msg/PipelineMetrics.msg",
    "msg/SystemMetrics.msg",
    "msg/HealthState.msg"
)

$missing = @()
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $packageDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missing += $relativePath
    }
}

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    $missing += "docs/interfaces/edge_reliability_contract.md"
}

if ($missing.Count -gt 0) {
    throw "Missing P0-005 interface files: $($missing -join ', ')"
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

$packageXml = Read-PackageFile "package.xml"
$cmake = Read-PackageFile "CMakeLists.txt"
$sensorSample = Read-PackageFile "msg/SensorSample.msg"
$pipelineMetrics = Read-PackageFile "msg/PipelineMetrics.msg"
$systemMetrics = Read-PackageFile "msg/SystemMetrics.msg"
$healthState = Read-PackageFile "msg/HealthState.msg"
$contract = Get-Content -Raw -LiteralPath $contractPath

Assert-Contains "package.xml" $packageXml "<name>edge_reliability_msgs</name>"
Assert-Contains "package.xml" $packageXml "<buildtool_depend>ament_cmake</buildtool_depend>"
Assert-Contains "package.xml" $packageXml "<build_depend>rosidl_default_generators</build_depend>"
Assert-Contains "package.xml" $packageXml "<exec_depend>rosidl_default_runtime</exec_depend>"
Assert-Contains "CMakeLists.txt" $cmake "rosidl_generate_interfaces"

foreach ($field in @(
    "std_msgs/Header header",
    "uint64 sequence_id",
    "string sensor_id",
    "float64 value",
    "uint8 status",
    "STATUS_OK=0",
    "STATUS_WARN=1",
    "STATUS_ERROR=2"
)) {
    Assert-Contains "SensorSample.msg" $sensorSample $field
}

foreach ($field in @(
    "std_msgs/Header header",
    "uint64 received_count",
    "uint64 dropped_count",
    "float64 receive_rate_hz",
    "float64 average_latency_ms",
    "float64 p95_latency_ms",
    "float64 p99_latency_ms",
    "float64 drop_rate"
)) {
    Assert-Contains "PipelineMetrics.msg" $pipelineMetrics $field
}

foreach ($field in @(
    "std_msgs/Header header",
    "float64 cpu_percent",
    "float64 memory_used_mb",
    "float64 memory_total_mb",
    "float64 gpu_percent",
    "float64 temperature_c",
    "float64 power_w"
)) {
    Assert-Contains "SystemMetrics.msg" $systemMetrics $field
}

foreach ($field in @(
    "std_msgs/Header header",
    "uint8 state",
    "HEALTHY=0",
    "WARNING=1",
    "UNHEALTHY=2",
    "string reason"
)) {
    Assert-Contains "HealthState.msg" $healthState $field
}

foreach ($text in @(
    "/edge/sensors/fake_primary",
    "/edge/metrics/pipeline",
    "/edge/metrics/system",
    "/edge/health/state",
    "edge_reliability_msgs/msg/SensorSample",
    "edge_reliability_msgs/msg/PipelineMetrics",
    "edge_reliability_msgs/msg/SystemMetrics",
    "edge_reliability_msgs/msg/HealthState",
    "fake_sensor_adapter",
    "sensor_processor",
    "pipeline_metrics_node",
    "system_metrics_node",
    "health_monitor",
    "USB camera",
    "CSI camera",
    "LiDAR",
    "IMU",
    "odometry",
    "base driver",
    "QoS",
    "rosbag",
    "failure modes"
)) {
    Assert-Contains "edge_reliability_contract.md" $contract $text
}

Write-Host "P0-005 interface contract checks passed"
