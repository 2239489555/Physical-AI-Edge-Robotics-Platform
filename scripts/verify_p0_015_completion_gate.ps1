param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReportPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "runtime/results/p0_015_smoke_report.txt")
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "verify_p0_015_runtime_scripts.ps1") -RepoRoot $RepoRoot
& (Join-Path $PSScriptRoot "verify_p0_015_smoke_report.ps1") -ReportPath $ReportPath

Write-Host "P0-015 completion gate checks passed"
