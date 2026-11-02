#Requires -Version 7.2
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
if ($architecture -ne 'X64') { throw "Unsupported architecture: $architecture. Tool lock supports x86_64." }
if ($IsWindows) { $platform = 'windows-x86_64'; $suffix = '.exe' }
elseif ($IsLinux) { $platform = 'linux-x86_64'; $suffix = '' }
else { throw 'Pinned tools currently support Windows and Linux x86_64 only.' }
$lock = Get-Content -LiteralPath (Join-Path $repoRoot 'tools.lock.json') -Raw | ConvertFrom-Json
if ($lock.schemaVersion -ne 1) { throw 'Unsupported tools.lock.json schema.' }
$binDir = Join-Path $repoRoot '.tools/bin'
$cacheDir = Join-Path $repoRoot '.tools/downloads'
New-Item -ItemType Directory -Force -Path $binDir, $cacheDir | Out-Null
foreach ($name in @('rojo', 'lune')) {
    $tool = $lock.tools.$name
    $asset = $tool.platforms.$platform
    $archive = Join-Path $cacheDir "$name-$($tool.version)-$platform.zip"
    if (-not (Test-Path -LiteralPath $archive)) {
        Write-Host "Downloading $name $($tool.version) ($platform)..."
        Invoke-WebRequest -Uri $asset.url -OutFile $archive -MaximumRetryCount 3
    }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $asset.sha256) {
        Remove-Item -LiteralPath $archive -Force
        throw "SHA256 mismatch for $name. Invalid archive removed; rerun setup to download again."
    }
    # Always restore from the verified archive, rather than trusting an old executable.
    Expand-Archive -LiteralPath $archive -DestinationPath $binDir -Force
    $binary = Join-Path $binDir "$name$suffix"
    if (-not (Test-Path -LiteralPath $binary)) { throw "Missing executable in $name archive." }
    if ($IsLinux) {
        & chmod +x $binary
        if ($LASTEXITCODE -ne 0) { throw "chmod failed for $name." }
    }
    $versionOutput = & $binary --version
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "\b$([regex]::Escape($tool.version))\b") {
        throw "Unexpected $name executable version: $versionOutput"
    }
    Write-Host "$versionOutput (archive SHA256 verified)"
}
