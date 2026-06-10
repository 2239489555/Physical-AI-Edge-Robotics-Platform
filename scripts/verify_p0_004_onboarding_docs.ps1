param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$guidePath = Join-Path $RepoRoot "docs/onboarding/ros2_beginner_onboarding.md"
$interviewPath = Join-Path $RepoRoot "docs/onboarding/interview_artifacts.md"

$missingFiles = @()
foreach ($path in @($guidePath, $interviewPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missingFiles += $path
    }
}

if ($missingFiles.Count -gt 0) {
    throw "Missing P0-004 docs: $($missingFiles -join ', ')"
}

$guide = Get-Content -Raw -LiteralPath $guidePath
$interview = Get-Content -Raw -LiteralPath $interviewPath

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

$requiredGuideTerms = @(
    "node",
    "topic",
    "message",
    "service",
    "action",
    "launch",
    "parameter",
    "QoS",
    "timestamp",
    "frame_id",
    "sequence_id",
    "TF",
    "rosbag"
)

foreach ($term in $requiredGuideTerms) {
    Assert-Contains "ros2_beginner_onboarding.md" $guide $term
}

$requiredCommands = @(
    "colcon build --packages-select edge_reliability_tracer --symlink-install",
    "ros2 launch edge_reliability_tracer tracer.launch.py",
    "ros2 topic list -t",
    "ros2 topic info /edge/tracer -v",
    "ros2 topic echo --once /edge/tracer std_msgs/msg/String",
    "ros2 topic hz /edge/tracer",
    "ros2 bag record /edge/tracer",
    "ros2 bag info",
    "ros2 bag play"
)

foreach ($command in $requiredCommands) {
    Assert-Contains "ros2_beginner_onboarding.md" $guide $command
}

$requiredEvidence = @(
    "Summary: 1 package finished",
    "/edge/tracer [std_msgs/msg/String]",
    "10.000 Hz",
    "77",
    "runtime/bags/p0-003/tracer_smoke"
)

foreach ($evidence in $requiredEvidence) {
    Assert-Contains "ros2_beginner_onboarding.md" $guide $evidence
}

$requiredInterviewQuestions = @(
    "What is a ROS 2 node?",
    "What is the difference between topic, service, and action?",
    "Why do robotics messages need timestamps and frame IDs?",
    "How does rosbag help reproduce bugs?",
    "How would you explain this project in an interview?"
)

foreach ($question in $requiredInterviewQuestions) {
    Assert-Contains "interview_artifacts.md" $interview $question
}

Write-Host "P0-004 onboarding docs checks passed"
