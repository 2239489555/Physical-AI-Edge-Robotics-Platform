$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$RuntimeDir = Join-Path $RepoRoot "runtime"

$repoRootString = [string]$RepoRoot
$runtimeFullPath = [System.IO.Path]::GetFullPath($RuntimeDir)

if (-not $runtimeFullPath.StartsWith($repoRootString, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create runtime directory outside repository: $runtimeFullPath"
}

$subdirs = @(
    "datasets",
    "bags",
    "logs",
    "results",
    "artifacts",
    "cache",
    "run",
    "tmp"
)

foreach ($subdir in $subdirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $RuntimeDir $subdir) | Out-Null
}

@"
# Local Runtime Artifacts

This directory is intentionally ignored by git.

Use it for project-local Jetson runtime outputs:

- datasets/
- bags/
- logs/
- results/
- artifacts/
- cache/
- run/
- tmp/

Do not commit this directory.
"@ | Set-Content -LiteralPath (Join-Path $RuntimeDir "README.local.md") -Encoding UTF8

Write-Output "Runtime directories ready under: $runtimeFullPath"
