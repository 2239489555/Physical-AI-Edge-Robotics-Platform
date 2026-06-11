param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_011_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "verify_p0_011_system_metrics.ps1") -RepoRoot $RepoRoot
& (Join-Path $PSScriptRoot "verify_p0_011_smoke_report.ps1") -ReportPath $ReportPath

Write-Host "P0-011 completion gate checks passed"
