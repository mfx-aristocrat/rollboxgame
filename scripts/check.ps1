#Requires -Version 7.2
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup-tools.ps1')
$suffix = if ($IsWindows) { '.exe' } else { '' }
$lune = Join-Path $repoRoot ".tools/bin/lune$suffix"
$rojo = Join-Path $repoRoot ".tools/bin/rojo$suffix"
$python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
Push-Location $repoRoot
try {
    if (-not (Test-Path -LiteralPath 'tests/run.luau')) { throw 'Missing tests/run.luau test runner.' }
    & $lune run tests/run.luau
    if ($LASTEXITCODE -ne 0) { throw 'Luau tests failed.' }
    & (Join-Path $PSScriptRoot 'build.ps1') -SkipSetup
    $repeatOutput = Join-Path $repoRoot 'build/RollboxGame.repeat.rbxlx'
    try {
        & $rojo build default.project.json --output $repeatOutput
        if ($LASTEXITCODE -ne 0) { throw 'Repeated Rojo build failed.' }
        & $python tests/build_smoke.py default.project.json build/RollboxGame.rbxlx --compare $repeatOutput
        if ($LASTEXITCODE -ne 0) { throw 'Build reproducibility check failed.' }
    } finally {
        if (Test-Path -LiteralPath $repeatOutput) { Remove-Item -LiteralPath $repeatOutput -Force }
    }
    Write-Host 'All automated checks passed. Studio playtests are separate.'
} finally { Pop-Location }
