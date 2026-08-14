#Requires -Version 4
<#
.SYNOPSIS
  Build NetBridge-nbvpn-Setup.exe (Inno Setup) or fall back to a zip + setup.bat bundle.

.PARAMETER StageDir
  Folder containing nbvpn-windows-amd64.exe, install.ps1, WINDOWS.md

.PARAMETER OutDir
  Output directory (default: StageDir\dist)

.PARAMETER SkipWireGuardDownload
  Do not fetch the pinned WireGuard MSI (Setup will rely on install-time download).

.EXAMPLE
  .\build-setup.ps1 -StageDir C:\staging
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$StageDir,
  [string]$OutDir = '',
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' }),
  [string]$ExeName = 'nbvpn-windows-amd64.exe',
  [switch]$SkipWireGuardDownload
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
foreach ($f in @(
  'install.ps1',
  'Install-WireGuard.ps1',
  'wireguard-bundle.json',
  'WINDOWS.md',
  'THIRDPARTY-NOTICE.txt',
  'setup.bat',
  'nbvpn-setup.iss'
)) {
  $src = Join-Path $Here $f
  if (Test-Path -LiteralPath $src) {
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $StageDir $f)
  }
}

# --- Stage pinned WireGuard MSI (offline / reproducible Setup) ---
$wgHelper = Join-Path $Here 'Install-WireGuard.ps1'
if (Test-Path -LiteralPath $wgHelper) { . $wgHelper }

$pinPath = Join-Path $StageDir 'wireguard-bundle.json'
if (-not (Test-Path -LiteralPath $pinPath)) {
  $pinPath = Join-Path $Here 'wireguard-bundle.json'
}
$wgVendor = Join-Path $StageDir 'vendor\wireguard'
New-Item -ItemType Directory -Force -Path $wgVendor | Out-Null
if (Test-Path -LiteralPath $pinPath) {
  Copy-Item -Force -LiteralPath $pinPath -Destination (Join-Path $wgVendor 'wireguard-bundle.json')
}

if (-not $SkipWireGuardDownload -and (Test-Path -LiteralPath $pinPath)) {
  $pin = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json
  $msiName = [string]$pin.filename
  $msiDest = Join-Path $wgVendor $msiName
  $needFetch = -not (Test-Path -LiteralPath $msiDest)
  if (-not $needFetch -and $pin.sha256) {
    if (Get-Command Get-FileSha256Hex -ErrorAction SilentlyContinue) {
      $got = Get-FileSha256Hex -Path $msiDest
    } else {
      $got = (Get-FileHash -LiteralPath $msiDest -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    if ($got -ne ([string]$pin.sha256).ToLowerInvariant()) {
      Write-Warning "Stale/bad MSI hash — re-downloading"
      $needFetch = $true
    }
  }
  if ($needFetch) {
    Write-Host "==> Fetching pinned WireGuard MSI for Setup bundle"
    if (Get-Command Save-RemoteFileChecked -ErrorAction SilentlyContinue) {
      Save-RemoteFileChecked -Uri ([string]$pin.url) -OutFile $msiDest -ExpectedSha256 ([string]$pin.sha256)
    } else {
      Invoke-WebRequest -Uri ([string]$pin.url) -OutFile $msiDest -UseBasicParsing
      $got = (Get-FileHash -LiteralPath $msiDest -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($got -ne ([string]$pin.sha256).ToLowerInvariant()) {
        throw "WireGuard MSI SHA256 mismatch: expected $($pin.sha256), got $got"
      }
    }
  } else {
    Write-Host "==> Using existing bundled MSI: $msiDest"
  }
} else {
  Write-Warning "Skipping WireGuard MSI fetch — Setup will download at install time if online"
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
$zipStage = Join-Path $OutDir '_zipstage'
if (Test-Path $zipStage) { Remove-Item -Recurse -Force $zipStage }
New-Item -ItemType Directory -Force -Path $zipStage | Out-Null
foreach ($p in @(
  $ExeName, 'install.ps1', 'Install-WireGuard.ps1', 'wireguard-bundle.json',
  'setup.bat', 'WINDOWS.md', 'THIRDPARTY-NOTICE.txt'
)) {
  $src = Join-Path $StageDir $p
  if (Test-Path -LiteralPath $src) {
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $zipStage $p)
  }
}
if (Test-Path -LiteralPath $wgVendor) {
  $zv = Join-Path $zipStage 'vendor\wireguard'
  New-Item -ItemType Directory -Force -Path $zv | Out-Null
  Copy-Item -Force -Path (Join-Path $wgVendor '*') -Destination $zv -ErrorAction SilentlyContinue
}
Compress-Archive -Path (Join-Path $zipStage '*') -DestinationPath $zip -Force
Remove-Item -Recurse -Force $zipStage -ErrorAction SilentlyContinue
$readme = Join-Path $OutDir 'README-SETUP.txt'
@"
NetBridge nbvpn — interim Windows package (no Inno Setup in this build environment)

1. Extract this zip
2. Right-click setup.bat → Run as administrator
   (or: powershell -ExecutionPolicy Bypass -File .\install.ps1)

Prefer downloading NetBridge-nbvpn-Setup.exe from GitHub Releases when CI builds with Inno.
WireGuard: Setup/install.ps1 auto-installs the pinned MSI (wireguard-bundle.json) on Win10+/Server 2016+.
Third-party: THIRDPARTY-NOTICE.txt (WireGuard GPLv2).
"@ | Set-Content $readme
Write-Host "OK interim: $zip"
exit 0
