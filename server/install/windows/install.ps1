#Requires -RunAsAdministrator
<#
.SYNOPSIS
  NetBridge nbvpn — Windows Server install (MVP)

.DESCRIPTION
  Installs nbvpn.exe, enables IPv4 forwarding + optional NetNat (Server 2016+),
  opens UDP firewall, then runs `nbvpn install` (keys, first peer, profiles;
  WireGuard tunnel service when available).

  Prefer NetBridge-nbvpn-Setup.exe from GitHub Releases when available.
  This script remains the advanced / Server 2012 path.

  Prerequisites:
    - Windows Server 2019/2022 recommended; Server 2012 R2 needs Go 1.20-built exe
    - Administrator PowerShell (Windows PowerShell 4+ / 5.1)
    - WireGuard for Windows: https://www.wireguard.com/install/
      (optional for dry-run profile export; required for a real tunnel)

.PARAMETER SkipInstall
  Only place binary + networking prep; do not run `nbvpn install`.

.PARAMETER BinaryUrl
  Download nbvpn-windows-amd64.exe from this URL when no local binary is found.

.PARAMETER InstallDir
  Where to place nbvpn.exe (default: C:\Program Files\NetBridge)

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipInstall,
  [string]$BinaryUrl = $env:NBVPN_BINARY_URL,
  [string]$InstallDir = $(if ($env:INSTALL_BIN_DIR) { $env:INSTALL_BIN_DIR } else { 'C:\Program Files\NetBridge' }),
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' })
)

$ErrorActionPreference = 'Stop'

function Write-Log([string]$Message) { Write-Host "==> $Message" }
function Write-Warn([string]$Message) { Write-Warning $Message }

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CommandPath($cmd) {
  if (-not $cmd) { return $null }
  if ($cmd.Source) { return [string]$cmd.Source }
  if ($cmd.Path) { return [string]$cmd.Path }
  if ($cmd.FullName) { return [string]$cmd.FullName }
  return $null
}

function Join-SafePath([string]$Base, [string]$Child) {
  if (-not $Base -or $Base.Length -eq 0) { return $null }
  if (-not $Child) { return $Base }
  return (Join-Path -Path $Base -ChildPath $Child)
}

function Get-WindowsBuildInfo {
  $ver = [Environment]::OSVersion.Version
  $isLegacy = ($ver.Major -lt 10)  # Server 2012 / 2012 R2 = 6.2 / 6.3
  return @{
    Version   = $ver
    IsLegacy  = $isLegacy
    Caption   = ("Windows {0}.{1}" -f $ver.Major, $ver.Minor)
  }
}

function Test-SupportsNewNetNat {
  $cmd = Get-Command New-NetNat -ErrorAction SilentlyContinue
  if (-not $cmd) { return $false }
  try {
    $params = $cmd.Parameters
    if (-not $params) { return $false }
    return [bool]($params.ContainsKey('InternalIPInterfaceAddressPrefix'))
  } catch {
    return $false
  }
}

if (-not (Test-IsAdmin)) {
  throw "Run as Administrator: powershell -ExecutionPolicy Bypass -File install.ps1"
}

$ScriptDir = $null
if ($PSScriptRoot -and ($PSScriptRoot -is [string]) -and $PSScriptRoot.Length -gt 0) {
  $ScriptDir = $PSScriptRoot
}
if (-not $ScriptDir -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
  $ScriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
}
if (-not $ScriptDir -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Definition) {
  $def = [string]$MyInvocation.MyCommand.Definition
  if ($def -and (Test-Path -LiteralPath $def)) {
    $ScriptDir = Split-Path -Parent -Path $def
  }
}
if (-not $ScriptDir) {
  $ScriptDir = (Get-Location).Path
}
Write-Log "ScriptDir: $ScriptDir"

$osInfo = Get-WindowsBuildInfo
Write-Log ("OS: {0} (legacy={1})" -f $osInfo.Caption, $osInfo.IsLegacy)

$RepoRoot = $null
$tryRoots = @(
  (Join-SafePath $ScriptDir '..\..\..'),
  (Join-SafePath $ScriptDir '..\..')
)
foreach ($candRoot in $tryRoots) {
  if (-not $candRoot) { continue }
  $resolved = Resolve-Path -LiteralPath $candRoot -ErrorAction SilentlyContinue
  if ($resolved) {
    $RepoRoot = [string]$resolved.Path
    break
  }
}

$NbVpnSrc = $null
if ($RepoRoot) {
  $cand = Join-SafePath $RepoRoot 'server\nbvpn'
  if ($cand -and (Test-Path -LiteralPath $cand)) { $NbVpnSrc = $cand }
}

Write-Log "NetBridge nbvpn Windows install (label $Version)"
Write-Log "InstallDir: $InstallDir"

# --- WireGuard tools (soft-fail) ---
$wgMissing = $false
$wgCmd = Get-Command wg.exe -ErrorAction SilentlyContinue
$wireguardCmd = Get-Command wireguard.exe -ErrorAction SilentlyContinue
$wireguardPath = Get-CommandPath $wireguardCmd
$wgPath = Get-CommandPath $wgCmd

if (-not $wireguardPath) {
  $wgPaths = @(
    (Join-SafePath ${env:ProgramFiles} 'WireGuard\wireguard.exe'),
    (Join-SafePath ${env:ProgramFiles(x86)} 'WireGuard\wireguard.exe')
  )
  foreach ($p in $wgPaths) {
    if ($p -and (Test-Path -LiteralPath $p)) {
      $wireguardPath = $p
      $parent = Split-Path -Parent -Path $p
      if ($parent) { $env:Path = "$parent;$env:Path" }
      break
    }
  }
}

if (-not $wgPath -and $wireguardPath) {
  $wgParent = Split-Path -Parent -Path $wireguardPath
  if ($wgParent) {
    $wgCand = Join-SafePath $wgParent 'wg.exe'
    if ($wgCand -and (Test-Path -LiteralPath $wgCand)) {
      $env:Path = "$wgParent;$env:Path"
      $wgCmd = Get-Command wg.exe -ErrorAction SilentlyContinue
      $wgPath = Get-CommandPath $wgCmd
      if (-not $wgPath) { $wgPath = $wgCand }
    }
  }
}

if (-not $wireguardPath) {
  $wgMissing = $true
  Write-Warn "WireGuard for Windows NOT FOUND — continuing in dry-run (keys/profiles only)."
  Write-Host @"

********************************************************************************
  MUST install WireGuard before a real VPN tunnel:
    https://download.wireguard.com/windows-client/wireguard-installer.exe
    https://www.wireguard.com/install/
  After WireGuard is installed, re-run this script (or: nbvpn install).
  On Server 2012 R2, official WireGuard/Wintun support is limited — prefer 2019+.
********************************************************************************

"@
} else {
  Write-Log "Found wireguard: $wireguardPath"
}

# --- Place nbvpn.exe ---
if (-not $InstallDir -or $InstallDir.Length -eq 0) {
  throw "InstallDir is empty"
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$TargetExe = Join-SafePath $InstallDir 'nbvpn.exe'
if (-not $TargetExe) { throw "Failed to resolve target exe path" }

$candidates = New-Object System.Collections.ArrayList
if ($NbVpnSrc) {
  [void]$candidates.Add((Join-SafePath $NbVpnSrc 'dist\nbvpn-windows-amd64-win2012.exe'))
  [void]$candidates.Add((Join-SafePath $NbVpnSrc 'dist\nbvpn-windows-amd64.exe'))
  [void]$candidates.Add((Join-SafePath $NbVpnSrc 'nbvpn.exe'))
  [void]$candidates.Add((Join-SafePath $NbVpnSrc 'nbvpn-windows-amd64-win2012.exe'))
  [void]$candidates.Add((Join-SafePath $NbVpnSrc 'nbvpn-windows-amd64.exe'))
}
[void]$candidates.Add((Join-SafePath $ScriptDir 'nbvpn-windows-amd64-win2012.exe'))
[void]$candidates.Add((Join-SafePath $ScriptDir 'nbvpn-windows-amd64.exe'))
[void]$candidates.Add((Join-SafePath $ScriptDir 'nbvpn.exe'))
[void]$candidates.Add('C:\ProgramData\NetBridge\nbvpn-windows-amd64-win2012.exe')
[void]$candidates.Add('C:\ProgramData\NetBridge\nbvpn-windows-amd64.exe')
[void]$candidates.Add('C:\NetBridge\deploy\nbvpn-windows-amd64-win2012.exe')
[void]$candidates.Add('C:\NetBridge\deploy\nbvpn-windows-amd64.exe')

$src = $null
foreach ($c in $candidates) {
  if ($c -and (Test-Path -LiteralPath $c)) {
    $src = $c
    break
  }
}

if ($src) {
  Write-Log "Installing binary from $src"
  Copy-Item -Force -LiteralPath $src -Destination $TargetExe
} elseif ($BinaryUrl) {
  Write-Log "Downloading nbvpn from $BinaryUrl"
  $tmpName = "nbvpn-windows-amd64-$([guid]::NewGuid().ToString('n')).exe"
  $tmp = Join-SafePath $env:TEMP $tmpName
  if (-not $tmp) { throw "TEMP is empty; cannot download" }
  try {
    Invoke-WebRequest -Uri $BinaryUrl -OutFile $tmp -UseBasicParsing
  } catch {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($BinaryUrl, $tmp)
  }
  Copy-Item -Force -LiteralPath $tmp -Destination $TargetExe
  Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
} elseif (Get-Command go.exe -ErrorAction SilentlyContinue) {
  if (-not $NbVpnSrc -or -not (Test-Path -LiteralPath (Join-SafePath $NbVpnSrc 'go.mod'))) {
    throw "No binary and no go.mod under server\nbvpn. Set -BinaryUrl or place nbvpn-windows-amd64*.exe next to this script."
  }
  Write-Log "Building nbvpn.exe from source with Go (use Go 1.20.x on Server 2012 R2)"
  Push-Location $NbVpnSrc
  try {
    & go build -o nbvpn.exe .
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }
    Copy-Item -Force -LiteralPath (Join-SafePath $NbVpnSrc 'nbvpn.exe') -Destination $TargetExe
  } finally {
    Pop-Location
  }
} else {
  throw @"
No nbvpn binary found.
Place next to this script (prefer for Server 2012 R2):
  nbvpn-windows-amd64-win2012.exe
Or Win10+/Server 2016+:
  nbvpn-windows-amd64.exe
Or set -BinaryUrl / NBVPN_BINARY_URL
Or use NetBridge-nbvpn-Setup.exe from GitHub Releases.
Build: ./server/nbvpn/scripts/build-windows-docker.sh win2012|win10
"@
}

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if (-not $machinePath) { $machinePath = '' }
if ($machinePath -notlike "*$InstallDir*") {
  Write-Log "Adding $InstallDir to machine PATH"
  if ($machinePath.Length -gt 0) {
    [Environment]::SetEnvironmentVariable('Path', "$machinePath;$InstallDir", 'Machine')
  } else {
    [Environment]::SetEnvironmentVariable('Path', $InstallDir, 'Machine')
  }
}
$env:Path = "$InstallDir;$env:Path"

& $TargetExe version
if ($LASTEXITCODE -ne 0) { Write-Warn "nbvpn version returned non-zero" }

# --- IP forward + NAT ---
Write-Log "Enabling IPv4 forwarding"
try {
  netsh interface ipv4 set global forwarding=enabled | Out-Null
} catch {
  Write-Warn "netsh forwarding: $_"
}

if (Get-Command Get-NetIPInterface -ErrorAction SilentlyContinue) {
  try {
    Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Set-NetIPInterface -Forwarding Enabled -ErrorAction SilentlyContinue
  } catch {
    Write-Warn "Set-NetIPInterface forwarding: $_"
  }
}

$natName = 'nbvpnNat'
$natPrefix = '10.8.0.0/24'
if ($osInfo.IsLegacy) {
  Write-Warn @"
Server 2012 / 2012 R2: skipping New-NetNat (API not available / incomplete).
For client internet egress, enable RRAS NAT or ICS manually:
  1. Server Manager → Add Roles → Remote Access → Routing
  2. Routing and Remote Access → Configure → NAT
  3. Or share the public NIC via ICS (Network Connections → Properties → Sharing)
See WINDOWS.md.
"@
} elseif (Test-SupportsNewNetNat) {
  $existingNat = Get-NetNat -Name $natName -ErrorAction SilentlyContinue
  if (-not $existingNat) {
    Write-Log "Creating NetNat $natName for $natPrefix"
    try {
      New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $natPrefix | Out-Null
      Write-Log "NetNat created"
    } catch {
      Write-Warn @"
New-NetNat failed: $_.
Enable RRAS NAT or ICS for client internet. See WINDOWS.md.
"@
    }
  } else {
    Write-Log "NetNat $natName already present"
  }
} else {
  Write-Warn "New-NetNat with InternalIPInterfaceAddressPrefix not available. Configure RRAS/ICS (WINDOWS.md)."
}

# --- Firewall UDP 51820 ---
$fwName = 'NetBridge nbvpn UDP 51820'
if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
  $fw = Get-NetFirewallRule -DisplayName $fwName -ErrorAction SilentlyContinue
  if (-not $fw) {
    Write-Log "Opening inbound UDP 51820"
    New-NetFirewallRule -DisplayName $fwName -Direction Inbound -Protocol UDP -LocalPort 51820 -Action Allow |
      Out-Null
  } else {
    Write-Log "Firewall rule already present: $fwName"
  }
} else {
  Write-Log "Opening inbound UDP 51820 via netsh (no NetSecurity module)"
  netsh advfirewall firewall add rule name="$fwName" dir=in action=allow protocol=UDP localport=51820 | Out-Null
}

if ($SkipInstall -or $env:NBVPN_SKIP_INSTALL -eq '1') {
  Write-Log "SkipInstall set — not running nbvpn install"
  Write-Host "Next: nbvpn install"
  exit 0
}

Write-Log "Running: nbvpn install (creates %ProgramData%\nbvpn even without WireGuard)"
& $TargetExe install
$code = $LASTEXITCODE
if ($code -ne 0) {
  throw "nbvpn install exited $code"
}

# --- Verify data dir ---
$dataDir = Join-SafePath $env:ProgramData 'nbvpn'
if (-not $dataDir) { $dataDir = 'C:\ProgramData\nbvpn' }
Write-Host ""
Write-Host "=== Verify data directory ==="
Write-Host "ProgramData is often HIDDEN. Open with:"
Write-Host "  explorer $dataDir"
if (Test-Path -LiteralPath $dataDir) {
  Write-Log "Found: $dataDir"
  Get-ChildItem -LiteralPath $dataDir -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 40 FullName, Length |
    Format-Table -AutoSize
} else {
  Write-Warn "Expected data dir missing: $dataDir — check NBVPN_DATA_DIR or LocalAppData\nbvpn"
  $fallback = Join-SafePath $env:LOCALAPPDATA 'nbvpn'
  if ($fallback -and (Test-Path -LiteralPath $fallback)) {
    Write-Log "Found fallback: $fallback"
    Get-ChildItem -LiteralPath $fallback -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 40 FullName, Length |
      Format-Table -AutoSize
  }
}

Write-Host ""
Write-Host "=== Windows install finished ==="
Write-Host "Binary: $TargetExe"
Write-Host "Show URI / files / PNG:  nbvpn show"
Write-Host "  (terminal QR skipped on Windows by default; open the .png or use --uri)"
Write-Host "Docs: server\install\windows\WINDOWS.md"
Write-Host "Remember cloud ACL / security group: inbound UDP 51820"
if ($wgMissing) {
  Write-Host ""
  Write-Host "*** WireGuard still missing — install it, then re-run for a live tunnel ***"
}
