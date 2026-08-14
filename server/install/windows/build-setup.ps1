#Requires -Version 4
<#
.SYNOPSIS
  Build NetBridge-nbvpn-Setup.exe (Inno Setup) or fall back to a zip + setup.bat bundle.

.PARAMETER StageDir
  Folder containing nbvpn-windows-amd64.exe, install.ps1, WINDOWS.md

.PARAMETER OutDir
  Output directory (default: StageDir\dist)

.EXAMPLE
  .\build-setup.ps1 -StageDir C:\staging
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$StageDir,
  [string]$OutDir = '',
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' }),
  [string]$ExeName = 'nbvpn-windows-amd64.exe'
)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
if (-not $Here) { $Here = Split-Path -Parent $MyInvocation.MyCommand.Path }

$StageDir = [string](Resolve-Path -LiteralPath $StageDir)
if (-not $OutDir) { $OutDir = Join-Path $StageDir 'dist' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$exe = Join-Path $StageDir $ExeName
if (-not (Test-Path -LiteralPath $exe)) {
  throw "Missing $exe — place the Windows amd64 binary in StageDir"
}
foreach ($f in @('install.ps1', 'WINDOWS.md', 'setup.bat', 'nbvpn-setup.iss')) {
  $src = Join-Path $Here $f
  if (Test-Path -LiteralPath $src) {
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $StageDir $f)
  }
}

function Find-ISCC {
  $candidates = @(
    ${env:ISCC},
    (Join-Path ${env:ProgramFiles} 'Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:LOCALAPPDATA} 'Programs\Inno Setup 6\ISCC.exe'),
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
if ($iscc) {
  Write-Host "==> Building Inno Setup with $iscc"
  $iss = Join-Path $StageDir 'nbvpn-setup.iss'
  & $iscc "/DMyAppVersion=$Version" "/DSrcDir=$StageDir" "/DSrcExe=$ExeName" "/DOutputDir=$OutDir" $iss
  if ($LASTEXITCODE -ne 0) { throw "ISCC failed: $LASTEXITCODE" }
  $setup = Join-Path $OutDir 'NetBridge-nbvpn-Setup.exe'
  if (-not (Test-Path -LiteralPath $setup)) { throw "Expected $setup" }
  Get-FileHash $setup -Algorithm SHA256 |
    ForEach-Object { "$($_.Hash.ToLower())  NetBridge-nbvpn-Setup.exe" } |
    Set-Content (Join-Path $OutDir 'NetBridge-nbvpn-Setup.exe.sha256')
  Write-Host "OK: $setup"
  exit 0
}

Write-Warning "Inno Setup (ISCC) not found — producing interim zip bundle NetBridge-nbvpn-Setup-zip.zip"
Write-Warning "Install Inno Setup 6 or choco install innosetup for a real Setup.exe"
$zip = Join-Path $OutDir 'NetBridge-nbvpn-Setup-zip.zip'
if (Test-Path $zip) { Remove-Item -Force $zip }
$toZip = @(
  (Join-Path $StageDir $ExeName),
  (Join-Path $StageDir 'install.ps1'),
  (Join-Path $StageDir 'setup.bat'),
  (Join-Path $StageDir 'WINDOWS.md')
) | Where-Object { Test-Path $_ }
Compress-Archive -Path $toZip -DestinationPath $zip -Force
# Also write a README for the zip
$readme = Join-Path $OutDir 'README-SETUP.txt'
@"
NetBridge nbvpn — interim Windows package (no Inno Setup in this build environment)

1. Extract this zip
2. Right-click setup.bat → Run as administrator
   (or: powershell -ExecutionPolicy Bypass -File .\install.ps1)

Prefer downloading NetBridge-nbvpn-Setup.exe from GitHub Releases when CI builds with Inno.
WireGuard: https://www.wireguard.com/install/
"@ | Set-Content $readme
Write-Host "OK interim: $zip"
exit 0
