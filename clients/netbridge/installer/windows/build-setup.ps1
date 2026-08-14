#Requires -Version 5
<#
.SYNOPSIS
  Build NetBridge-windows-setup.exe via Inno Setup after flutter build windows.

.PARAMETER ReleaseDir
  Path to build\windows\x64\runner\Release

.PARAMETER OutDir
  Destination for Setup.exe (default: clients/netbridge/dist)
#>
[CmdletBinding()]
param(
  [string]$ReleaseDir = '',
  [string]$OutDir = '',
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' })
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if (-not $ReleaseDir) {
  $ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
}
if (-not $OutDir) {
  $OutDir = Join-Path $Root 'dist'
}
$ReleaseDir = [string](Resolve-Path -LiteralPath $ReleaseDir)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$exe = Join-Path $ReleaseDir 'netbridge.exe'
if (-not (Test-Path -LiteralPath $exe)) {
  throw "Missing netbridge.exe under $ReleaseDir — run flutter build windows --release first"
}

function Find-ISCC {
  $candidates = @(
    ${env:ISCC},
    (Join-Path ${env:ProgramFiles} 'Inno Setup 6\ISCC.exe'),
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$iscc = Find-ISCC
if (-not $iscc) {
  throw "Inno Setup ISCC.exe not found. Install with: choco install innosetup -y"
}

$iss = Join-Path $PSScriptRoot 'NetBridge-setup.iss'
Write-Host "==> ISCC $iscc"
& $iscc "/DMyAppVersion=$Version" "/DSrcDir=$ReleaseDir" "/DOutputDir=$OutDir" $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed: $LASTEXITCODE" }

$setup = Join-Path $OutDir 'NetBridge-windows-setup.exe'
if (-not (Test-Path -LiteralPath $setup)) { throw "Missing $setup" }
Get-FileHash $setup -Algorithm SHA256 |
  ForEach-Object { "$($_.Hash.ToLower())  NetBridge-windows-setup.exe" } |
  Set-Content (Join-Path $OutDir 'NetBridge-windows-setup.exe.sha256')
Write-Host "OK: $setup"
