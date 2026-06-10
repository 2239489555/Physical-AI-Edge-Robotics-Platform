param(
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_006_smoke_report.txt"),
    [double]$MinHz = 90.0,
    [double]$MaxHz = 110.0
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "P0-006 smoke report not found: $ReportPath"
}

$content = Get-Content -Raw -LiteralPath $ReportPath

function Assert-Contains {
    param(
        [string]$Name,
        [string]$Text
    )

    if (-not $content.Contains($Text)) {
        throw "$Name missing required text: $Text"
    }
}

function Read-NumberAfterLabel {
    param(
        [string]$Label,
        [string]$Pattern
    )

    $match = [regex]::Match($content, $Pattern)
    if (-not $match.Success) {
        throw "Could not parse $Label from P0-006 smoke report"
    }

    return [double]::Parse(
        $match.Groups[1].Value,
        [Globalization.CultureInfo]::InvariantCulture
    )
}

Assert-Contains "report" "P0-006_RESULT"
Assert-Contains "verdict" "PASS/FAIL: PASS"
Assert-Contains "build" "colcon exit status: 0"
Assert-Contains "topic type" "Type: edge_reliability_msgs/msg/SensorSample"
Assert-Contains "publisher node" "Node name: fake_sensor_adapter"
Assert-Contains "echo header" "header:"
Assert-Contains "echo sequence" "sequence_id:"
Assert-Contains "echo sensor id" "sensor_id: fake_primary"
Assert-Contains "echo value" "value:"
Assert-Contains "echo status" "status:"
Assert-Contains "echo status detail" "status_detail: ok"
Assert-Contains "startup log" "event=startup"
Assert-Contains "first publish log" "event=first_publish"
Assert-Contains "bag topic" "Topic: /edge/sensors/fake_primary"
Assert-Contains "runtime bag path" "runtime/bags/p0-006"
Assert-Contains "blocker" "Blocker if FAIL: -"

if ($content.Contains("PASS/FAIL: FAIL")) {
    throw "P0-006 smoke report contains FAIL verdict"
}

$rate = Read-NumberAfterLabel "last average rate" "last average rate:\s*([0-9]+(?:\.[0-9]+)?)"
if ($rate -lt $MinHz -or $rate -gt $MaxHz) {
    throw "P0-006 average rate $rate is outside expected range $MinHz-$MaxHz Hz"
}

$bagMessages = Read-NumberAfterLabel "bag messages" "bag messages:\s*([0-9]+)"
if ($bagMessages -le 0) {
    throw "P0-006 bag message count must be greater than zero"
}

Write-Host "P0-006 smoke report checks passed"
