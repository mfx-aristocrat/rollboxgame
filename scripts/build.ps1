#Requires -Version 7.2
[CmdletBinding()]
param([switch]$SkipSetup)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SkipSetup) { & (Join-Path $PSScriptRoot 'setup-tools.ps1') }
$suffix = if ($IsWindows) { '.exe' } else { '' }
$rojo = Join-Path $repoRoot ".tools/bin/rojo$suffix"
$python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
$buildDir = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$output = Join-Path $buildDir 'RollboxGame.rbxlx'
Push-Location $repoRoot
try {
    & $rojo build default.project.json --output $output
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed.' }
    & $python tests/build_smoke.py default.project.json $output
    if ($LASTEXITCODE -ne 0) { throw 'Place smoke validation failed.' }
    Write-Host "Built $output"
} finally { Pop-Location }
