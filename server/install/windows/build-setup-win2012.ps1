#Requires -Version 4
<#
.SYNOPSIS
  Build NetBridge-nbvpn-Setup-win2012.exe (Inno Setup) for Server 2012 / 2012 R2.

.DESCRIPTION
  Stages win2012 CLI + Win32 GUI + WireGuard 0.5.3 MSI + install scripts.
  Does NOT bundle Fyne GUI or modern WireGuard 1.1 MSI.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$StageDir,
  [string]$OutDir = '',
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' }),
  [string]$ExeName = 'nbvpn-windows-amd64-win2012.exe',
  [string]$GuiName = 'nbvpn-gui-win2012.exe',
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
  throw "Missing $exe — place the win2012 amd64 binary in StageDir"
}
$gui = Join-Path $StageDir $GuiName
if (-not (Test-Path -LiteralPath $gui)) {
  throw "Missing $gui — build cmd/nbvpn-gui-win2012 (CGO=0 Win32) into StageDir"
}

foreach ($f in @(
  'install.ps1',
  'Install-WireGuard.ps1',
  'wireguard-bundle-win2012.json',
  'WINDOWS.md',
  'THIRDPARTY-NOTICE.txt',
  'nbvpn-setup-win2012.iss',
  'nbvpn-manage.cmd',
  'nbvpn-open-cmd.cmd',
  'nbvpn-status.cmd',
  'README-WIN2012.txt'
)) {
  $src = Join-Path $Here $f
  if (Test-Path -LiteralPath $src) {
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $StageDir $f)
  }
}

$icoCandidates = @(
  (Join-Path $Here '..\..\nbvpn\assets\branding\netbridge.ico'),
  (Join-Path $Here 'netbridge.ico'),
  (Join-Path $StageDir 'netbridge.ico')
)
foreach ($ico in $icoCandidates) {
  if ($ico -and (Test-Path -LiteralPath $ico)) {
    Copy-Item -Force -LiteralPath $ico -Destination (Join-Path $StageDir 'netbridge.ico')
    Write-Host "==> Staged Setup icon: $ico"
    break
  }
}

# --- Stage legacy WireGuard 0.5.3 MSI ---
$wgHelper = Join-Path $Here 'Install-WireGuard.ps1'
if (Test-Path -LiteralPath $wgHelper) { . $wgHelper }

$pinPath = Join-Path $StageDir 'wireguard-bundle-win2012.json'
if (-not (Test-Path -LiteralPath $pinPath)) {
  $pinPath = Join-Path $Here 'wireguard-bundle-win2012.json'
}
$wgVendor = Join-Path $StageDir 'vendor\wireguard'
New-Item -ItemType Directory -Force -Path $wgVendor | Out-Null
Copy-Item -Force -LiteralPath $pinPath -Destination (Join-Path $wgVendor 'wireguard-bundle-win2012.json')
# CI already stages pin into StageDir; Copy-Item to self fails on PowerShell 7.
$pinStage = Join-Path $StageDir 'wireguard-bundle-win2012.json'
if ((Resolve-Path -LiteralPath $pinPath).Path -ne [System.IO.Path]::GetFullPath($pinStage)) {
  Copy-Item -Force -LiteralPath $pinPath -Destination $pinStage
}

$pin = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json
$msiName = [string]$pin.filename
$msiDest = Join-Path $wgVendor $msiName
$sha = ([string]$pin.sha256).ToLowerInvariant()

function Test-MsiHash([string]$Path, [string]$Expected) {
  $got = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  return ($got -eq $Expected.ToLowerInvariant())
}

$needFetch = -not (Test-Path -LiteralPath $msiDest)
if (-not $needFetch -and -not (Test-MsiHash -Path $msiDest -Expected $sha)) {
  Write-Warning "Stale/bad MSI hash — re-downloading"
  $needFetch = $true
}

if ($needFetch -and -not $SkipWireGuardDownload) {
  $urls = New-Object System.Collections.ArrayList
  if ($pin.url) { [void]$urls.Add([string]$pin.url) }
  if ($pin.urlFallbacks) {
    foreach ($u in @($pin.urlFallbacks)) { if ($u) { [void]$urls.Add([string]$u) } }
  }
  $ok = $false
  foreach ($tryUrl in $urls) {
    try {
      Write-Host "==> Fetching legacy WireGuard MSI: $tryUrl"
      if (Get-Command Save-RemoteFileChecked -ErrorAction SilentlyContinue) {
        Save-RemoteFileChecked -Uri $tryUrl -OutFile $msiDest -ExpectedSha256 $sha
      } else {
        Invoke-WebRequest -Uri $tryUrl -OutFile $msiDest -UseBasicParsing
        if (-not (Test-MsiHash -Path $msiDest -Expected $sha)) {
          throw "SHA256 mismatch for $msiDest"
        }
      }
      $ok = $true
      break
    } catch {
      Write-Warning "Fetch failed: $_"
      Remove-Item -Force -LiteralPath $msiDest -ErrorAction SilentlyContinue
    }
  }
  if (-not $ok) {
    throw "Could not download WireGuard $msiName (sha256 $sha). Place MSI under $wgVendor and re-run."
  }
}

if (-not (Test-Path -LiteralPath $msiDest)) {
  throw "Missing required MSI: $msiDest (WireGuard 0.5.3 for Server 2012)"
}
if (-not (Test-MsiHash -Path $msiDest -Expected $sha)) {
  throw "MSI SHA256 mismatch for $msiDest"
}
# Refuse accidental modern 1.1 in this product
$bad11 = Get-ChildItem -LiteralPath $wgVendor -Filter '*1.1*.msi' -ErrorAction SilentlyContinue
if ($bad11) {
  throw "Modern WireGuard 1.1 MSI must not be staged into Setup-win2012: $($bad11.FullName)"
}
Write-Host "==> Bundled legacy WireGuard MSI: $msiDest"

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
if (-not $iscc) {
  throw "Inno Setup (ISCC) not found. Install with: choco install innosetup -y"
}

$iss = Join-Path $StageDir 'nbvpn-setup-win2012.iss'
Write-Host "==> Building win2012 Inno Setup with $iscc"
& $iscc "/DMyAppVersion=$Version" "/DSrcDir=$StageDir" "/DSrcExe=$ExeName" "/DSrcGuiExe=$GuiName" "/DOutputDir=$OutDir" $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed: $LASTEXITCODE" }

$setup = Join-Path $OutDir 'NetBridge-nbvpn-Setup-win2012.exe'
if (-not (Test-Path -LiteralPath $setup)) { throw "Expected $setup" }
Get-FileHash $setup -Algorithm SHA256 |
  ForEach-Object { "$($_.Hash.ToLower())  NetBridge-nbvpn-Setup-win2012.exe" } |
  Set-Content (Join-Path $OutDir 'NetBridge-nbvpn-Setup-win2012.exe.sha256')
Write-Host "OK: $setup"
exit 0
