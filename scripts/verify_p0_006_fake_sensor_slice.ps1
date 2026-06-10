param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$packageDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_fake_sensor"
$smokeScriptPath = Join-Path $RepoRoot "scripts/run_p0_006_fake_sensor_smoke.sh"
$scriptsReadmePath = Join-Path $RepoRoot "scripts/README.md"
$requiredFiles = @(
    "package.xml",
    "CMakeLists.txt",
    "src/fake_sensor_adapter.cpp",
    "launch/fake_sensor.launch.py",
    "config/fake_sensor.yaml",
    "README.md"
)

$missing = @()
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $packageDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missing += $relativePath
    }
}

if (-not (Test-Path -LiteralPath $smokeScriptPath -PathType Leaf)) {
    $missing += "scripts/run_p0_006_fake_sensor_smoke.sh"
}

if (-not (Test-Path -LiteralPath $scriptsReadmePath -PathType Leaf)) {
    $missing += "scripts/README.md"
}

if ($missing.Count -gt 0) {
    throw "Missing P0-006 fake sensor files: $($missing -join ', ')"
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
$source = Read-PackageFile "src/fake_sensor_adapter.cpp"
$launch = Read-PackageFile "launch/fake_sensor.launch.py"
$config = Read-PackageFile "config/fake_sensor.yaml"
$readme = Read-PackageFile "README.md"
$smokeScript = Get-Content -Raw -LiteralPath $smokeScriptPath
$scriptsReadme = Get-Content -Raw -LiteralPath $scriptsReadmePath

foreach ($text in @(
    "<name>edge_reliability_fake_sensor</name>",
    "<depend>rclcpp</depend>",
    "<depend>edge_reliability_msgs</depend>",
    "<exec_depend>launch_ros</exec_depend>"
)) {
    Assert-Contains "package.xml" $packageXml $text
}

foreach ($text in @(
    "add_executable(fake_sensor_adapter",
    "ament_target_dependencies(fake_sensor_adapter rclcpp edge_reliability_msgs)",
    "target_compile_features(fake_sensor_adapter PUBLIC cxx_std_17)",
    "install(DIRECTORY launch config"
)) {
    Assert-Contains "CMakeLists.txt" $cmake $text
}

foreach ($text in @(
    "#include `"edge_reliability_msgs/msg/sensor_sample.hpp`"",
    "declare_parameter<double>(`"publish_hz`", 100.0)",
    "declare_parameter<std::string>(`"sensor_id`", `"fake_primary`")",
    "declare_parameter<std::string>(`"frame_id`", `"fake_sensor_frame`")",
    "declare_parameter<std::string>(`"topic`", `"/edge/sensors/fake_primary`")",
    "declare_parameter<std::string>(`"status_mode`", `"ok`")",
    "declare_parameter<std::string>(`"fault_mode`", `"off`")",
    "declare_parameter<int>(`"qos_depth`", 10)",
    "declare_parameter<std::string>(`"qos_reliability`", `"best_effort`")",
    "rclcpp::QoS(rclcpp::KeepLast",
    ".best_effort()",
    ".reliable()",
    "create_publisher<edge_reliability_msgs::msg::SensorSample>",
    "message.header.stamp = now();",
    "message.header.frame_id = frame_id_;",
    "message.sequence_id = sequence_id_;",
    "message.sensor_id = sensor_id_;",
    "message.value =",
    "message.status =",
    "message.status_detail =",
    "++sequence_id_;",
    "RCLCPP_INFO"
)) {
    Assert-Contains "src/fake_sensor_adapter.cpp" $source $text
}

foreach ($text in @(
    "fake_sensor.yaml",
    "fake_sensor_adapter"
)) {
    Assert-Contains "launch/fake_sensor.launch.py" $launch $text
}

foreach ($text in @(
    "publish_hz: 100.0",
    "sensor_id: fake_primary",
    "frame_id: fake_sensor_frame",
    "topic: /edge/sensors/fake_primary",
    "status_mode: ok",
    "fault_mode: off",
    "qos_depth: 10",
    "qos_reliability: best_effort"
)) {
    Assert-Contains "config/fake_sensor.yaml" $config $text
}

foreach ($text in @(
    "colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor --symlink-install",
    "ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py",
    "ros2 topic info /edge/sensors/fake_primary -v",
    "ros2 topic echo --once /edge/sensors/fake_primary edge_reliability_msgs/msg/SensorSample",
    "ros2 topic hz /edge/sensors/fake_primary",
    "ros2 bag record /edge/sensors/fake_primary",
    "runtime/bags/p0-006",
    "fault_mode: off",
    "bash scripts/run_p0_006_fake_sensor_smoke.sh"
)) {
    Assert-Contains "README.md" $readme $text
}

foreach ($text in @(
    "#!/usr/bin/env bash",
    "P0-006_RESULT",
    'TOPIC="/edge/sensors/fake_primary"',
    'TYPE="edge_reliability_msgs/msg/SensorSample"',
    "colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor --symlink-install",
    "ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py",
    'ros2 topic info "$TOPIC" -v',
    'ros2 topic echo --once "$TOPIC" "$TYPE"',
    'timeout --signal=INT 12s ros2 topic hz "$TOPIC"',
    "--qos-reliability best_effort",
    'grep -F "Type: $TYPE" "$TOPIC_INFO"',
    'grep -F "Node name: fake_sensor_adapter" "$TOPIC_INFO"',
    'grep -F "header:" "$TOPIC_ECHO"',
    'grep -F "sequence_id:" "$TOPIC_ECHO"',
    'grep -F "sensor_id: fake_primary" "$TOPIC_ECHO"',
    'grep -F "value:" "$TOPIC_ECHO"',
    'grep -F "status:" "$TOPIC_ECHO"',
    'grep -F "status_detail: ok" "$TOPIC_ECHO"',
    'grep -F "event=startup" "$LAUNCH_LOG"',
    'grep -F "event=first_publish" "$LAUNCH_LOG"',
    'ros2 bag record "$TOPIC"',
    'ros2 bag info "$BAG_DIR"',
    "runtime/results",
    "runtime/logs",
    "runtime/bags/p0-006",
    "git status --short --ignored",
    "PASS/FAIL:"
)) {
    Assert-Contains "scripts/run_p0_006_fake_sensor_smoke.sh" $smokeScript $text
}

foreach ($text in @(
    "run_p0_006_fake_sensor_smoke.sh",
    "P0-006",
    "runtime/results"
)) {
    Assert-Contains "scripts/README.md" $scriptsReadme $text
}

Write-Host "P0-006 fake sensor static checks passed"
