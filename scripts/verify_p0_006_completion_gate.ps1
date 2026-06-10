param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_006_smoke_report.txt"),
    [double]$MinHz = 90.0,
    [double]$MaxHz = 110.0
)

$ErrorActionPreference = "Stop"

$staticGate = Join-Path $PSScriptRoot "verify_p0_006_fake_sensor_slice.ps1"
$reportGate = Join-Path $PSScriptRoot "verify_p0_006_smoke_report.ps1"

& $staticGate -RepoRoot $RepoRoot
& $reportGate -ReportPath $ReportPath -MinHz $MinHz -MaxHz $MaxHz

Write-Host "P0-006 completion gate checks passed"
