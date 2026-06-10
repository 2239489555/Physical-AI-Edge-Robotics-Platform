param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$packageDir = Join-Path $RepoRoot "ros2_ws/src/edge_reliability_tracer"
$requiredFiles = @(
    "package.xml",
    "CMakeLists.txt",
    "src/tracer_publisher.cpp",
    "src/tracer_subscriber.cpp",
    "launch/tracer.launch.py",
    "config/tracer.yaml",
    "README.md"
)

$missing = @()
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $packageDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missing += $relativePath
    }
}

if ($missing.Count -gt 0) {
    throw "Missing edge_reliability_tracer files: $($missing -join ', ')"
}

function Assert-FileContainsLiteral {
    param(
        [string]$RelativePath,
        [string]$Text
    )

    $path = Join-Path $packageDir $RelativePath
    $content = Get-Content -Raw -LiteralPath $path
    if (-not $content.Contains($Text)) {
        throw "$RelativePath does not contain required text: $Text"
    }
}

Assert-FileContainsLiteral "package.xml" "<name>edge_reliability_tracer</name>"
Assert-FileContainsLiteral "package.xml" "<depend>rclcpp</depend>"
Assert-FileContainsLiteral "package.xml" "<depend>std_msgs</depend>"
Assert-FileContainsLiteral "package.xml" "<exec_depend>launch_ros</exec_depend>"
Assert-FileContainsLiteral "CMakeLists.txt" "add_executable(tracer_publisher"
Assert-FileContainsLiteral "CMakeLists.txt" "add_executable(tracer_subscriber"
Assert-FileContainsLiteral "CMakeLists.txt" "install(DIRECTORY launch config"
Assert-FileContainsLiteral "src/tracer_publisher.cpp" 'declare_parameter<double>("publish_hz"'
Assert-FileContainsLiteral "src/tracer_publisher.cpp" "create_publisher<std_msgs::msg::String>"
Assert-FileContainsLiteral "src/tracer_subscriber.cpp" "create_subscription<std_msgs::msg::String>"
Assert-FileContainsLiteral "launch/tracer.launch.py" "tracer.yaml"
Assert-FileContainsLiteral "config/tracer.yaml" "publish_hz:"
Assert-FileContainsLiteral "README.md" "ros2 topic list"
Assert-FileContainsLiteral "README.md" "ros2 topic echo"
Assert-FileContainsLiteral "README.md" "ros2 topic hz"
Assert-FileContainsLiteral "README.md" "ros2 topic info"
Assert-FileContainsLiteral "README.md" "ros2 bag record"
Assert-FileContainsLiteral "README.md" "ros2 bag play"
Assert-FileContainsLiteral "README.md" "runtime/bags"

Write-Host "edge_reliability_tracer static checks passed"
