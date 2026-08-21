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
    - WireGuard for Windows: auto-installed from pinned MSI on Win10+/Server 2016+
      when missing (wireguard-bundle.json). Server 2012: official WG unsupported —
      profiles only (dry-run). Use -SkipWireGuard to force dry-run.

.PARAMETER SkipInstall
  Only place binary + networking prep; do not run `nbvpn install`.

.PARAMETER SkipWireGuard
  Do not auto-install WireGuard (keys/profiles only). Default: install if missing.

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
  [switch]$SkipWireGuard,
  [string]$BinaryUrl = $env:NBVPN_BINARY_URL,
  [string]$InstallDir = $(if ($env:INSTALL_BIN_DIR) { $env:INSTALL_BIN_DIR } else { 'C:\Program Files\NetBridge' }),
  [string]$Version = $(if ($env:NBVPN_VERSION) { $env:NBVPN_VERSION } else { '1.0.0' })
)

$ErrorActionPreference = 'Stop'

# Setup / operator logs (Inno MsgBox points here on failure)
$script:NbVpnSetupLog = Join-Path $env:TEMP ("nbvpn-setup-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$script:NbVpnSetupLogLatest = Join-Path $env:TEMP 'nbvpn-setup-latest.log'
$script:NbVpnSetupLastError = Join-Path $env:TEMP 'nbvpn-setup-last-error.txt'
try {
  '' | Set-Content -LiteralPath $script:NbVpnSetupLogLatest -Encoding UTF8
  if (Test-Path -LiteralPath $script:NbVpnSetupLastError) {
    Remove-Item -Force -LiteralPath $script:NbVpnSetupLastError -ErrorAction SilentlyContinue
  }
} catch { }

function Write-SetupFile([string]$Message) {
  $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $Message
  try {
    Add-Content -LiteralPath $script:NbVpnSetupLog -Value $line -Encoding UTF8
    Add-Content -LiteralPath $script:NbVpnSetupLogLatest -Value $line -Encoding UTF8
  } catch { }
}

function Write-Log([string]$Message) {
  Write-Host "==> $Message"
  Write-SetupFile $Message
}
function Write-Warn([string]$Message) {
  Write-Warning $Message
  Write-SetupFile "WARN: $Message"
}

function Save-SetupFailure([string]$Message) {
  $body = @"
NetBridge nbvpn install.ps1 FAILED

$Message

Setup log: $($script:NbVpnSetupLog)
Latest log: $($script:NbVpnSetupLogLatest)
msiexec log: $(Join-Path $env:ProgramData 'nbvpn\wireguard-msiexec.log')
msiexec TEMP: $(Join-Path $env:TEMP 'nbvpn-wireguard-msiexec.log')

If this is Server 2012/2012 R2: use nbvpn-windows-amd64-win2012.exe + install.ps1
(modern Setup.exe is for Windows 10 / Server 2016+).
"@
  try {
    Set-Content -LiteralPath $script:NbVpnSetupLastError -Value $body -Encoding UTF8
    Write-SetupFile "FAIL: $Message"
  } catch { }
  Write-Host ""
  Write-Host "=== FAILURE DETAILS (also in $($script:NbVpnSetupLastError)) ==="
  Write-Host $body
}

# Persist unexpected throws for Inno MsgBox (exit code alone is not enough)
trap {
  try {
    Save-SetupFailure ("Unhandled: " + $_.Exception.Message)
  } catch { }
  break
}

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

# Setup already places nbvpn.exe in InstallDir; Copy-Item A→A fails on PS7 / Win2012.
function Test-SameFilePath([string]$A, [string]$B) {
  if (-not $A -or -not $B) { return $false }
  $norm = {
    param([string]$p)
    try {
      if (Test-Path -LiteralPath $p) {
        return ([string](Resolve-Path -LiteralPath $p).Path).TrimEnd('\')
      }
    } catch { }
    try {
      return [System.IO.Path]::GetFullPath($p).TrimEnd('\')
    } catch {
      return $p.TrimEnd('\')
    }
  }
  $pa = & $norm $A
  $pb = & $norm $B
  return [string]::Equals($pa, $pb, [StringComparison]::OrdinalIgnoreCase)
}

function Copy-FileUnlessSame([string]$Source, [string]$Destination, [string]$Label = 'binary') {
  if (Test-SameFilePath -A $Source -B $Destination) {
    Write-Log ("{0} already at destination — skip Copy-Item self-overwrite: {1}" -f $Label, $Destination)
    return
  }
  Copy-Item -Force -LiteralPath $Source -Destination $Destination
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
  $msg = "Run as Administrator: powershell -ExecutionPolicy Bypass -File install.ps1"
  Save-SetupFailure $msg
  throw $msg
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
Write-Log "Setup log: $($script:NbVpnSetupLog)"

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

# --- WireGuard for Windows (auto-install pinned MSI when missing) ---
$wgHelper = Join-SafePath $ScriptDir 'Install-WireGuard.ps1'
if (-not $wgHelper -or -not (Test-Path -LiteralPath $wgHelper)) {
  $msg = "Missing Install-WireGuard.ps1 next to install.ps1 ($ScriptDir)"
  Save-SetupFailure $msg
  throw $msg
}
. $wgHelper

# Search both script dir (Setup unpack) and InstallDir — MSI lives in {app}\vendor\wireguard
$wgSearchRoots = @()
if ($ScriptDir) { $wgSearchRoots += $ScriptDir }
if ($InstallDir -and ($InstallDir -ne $ScriptDir)) { $wgSearchRoots += $InstallDir }
# Explicit vendor hints for logging / Find-BundledWireGuardMsi roots
foreach ($r in @($ScriptDir, $InstallDir)) {
  if (-not $r) { continue }
  $v = Join-SafePath $r 'vendor\wireguard'
  if ($v -and (Test-Path -LiteralPath $v)) {
    Write-Log "Found vendor\wireguard: $v"
    Get-ChildItem -LiteralPath $v -ErrorAction SilentlyContinue | ForEach-Object {
      Write-Log ("  vendor file: {0} ({1} bytes)" -f $_.Name, $_.Length)
    }
  }
}
$skipWg = $SkipWireGuard -or ($env:NBVPN_SKIP_WIREGUARD -eq '1')
$setupLogDir = Join-Path $env:ProgramData 'nbvpn'
$wgResult = Ensure-WireGuardForWindows -SearchRoots $wgSearchRoots -AllowDownload -SkipInstall:$skipWg -SetupLogDir $setupLogDir

$wgMissing = $false
$wgRebootSuggested = [bool]$wgResult.RebootSuggested
$wireguardPath = $wgResult.Path

switch ($wgResult.Status) {
  'Present' { Write-Log $wgResult.Message }
  'Installed' { Write-Log $wgResult.Message }
  'LegacyUnsupported' {
    $wgMissing = $true
    Write-Host @"

********************************************************************************
  WireGuard auto-install skipped/unavailable on this host (legacy pin missing,
  ForceLegacyDryRun, or refused modern 1.1 MSI).
  Continuing with keys/profiles only (dry-run).
  Server 2012: use NetBridge-nbvpn-Setup-win2012.exe (bundles WG 0.5.3 + Win32 GUI).
********************************************************************************

"@
    Write-Log $wgResult.Message
  }
  'Skipped' {
    $wgMissing = $true
    Write-Warn $wgResult.Message
  }
  default {
    # Failed auto-install: hard-fail on all OS (2012 now has 0.5.3 pin via Setup-win2012).
    $msg = @"
WireGuard for Windows could not be installed automatically.

$($wgResult.Message)

Server 2012 / 2012 R2: use NetBridge-nbvpn-Setup-win2012.exe (bundles wireguard-amd64-0.5.3.msi).
Win10+/2016+: use NetBridge-nbvpn-Setup.exe or ensure wireguard-bundle.json is present.
Advanced dry-run only: re-run with -SkipWireGuard
"@
    Save-SetupFailure $msg
    throw $msg
  }
}

if ($wireguardPath) {
  $wgParent = Split-Path -Parent -Path $wireguardPath
  if ($wgParent) {
    $env:Path = "$wgParent;$env:Path"
    $wgCand = Join-SafePath $wgParent 'wg.exe'
    if ($wgCand -and (Test-Path -LiteralPath $wgCand)) {
      Write-Log "Found wg.exe: $wgCand"
    }
  }
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
  Copy-FileUnlessSame -Source $src -Destination $TargetExe -Label 'nbvpn.exe'
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
  Copy-FileUnlessSame -Source $tmp -Destination $TargetExe -Label 'nbvpn.exe'
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
    Copy-FileUnlessSame -Source (Join-SafePath $NbVpnSrc 'nbvpn.exe') -Destination $TargetExe -Label 'nbvpn.exe'
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
# Exact segment match (avoid false positives from substring -notlike)
$pathParts = @($machinePath -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
$pathHasInstall = $false
foreach ($part in $pathParts) {
  if ([string]::Equals($part.TrimEnd('\'), $InstallDir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    $pathHasInstall = $true
    break
  }
}
if (-not $pathHasInstall) {
  Write-Log "Adding $InstallDir to machine PATH"
  if ($machinePath.Length -gt 0) {
    [Environment]::SetEnvironmentVariable('Path', "$machinePath;$InstallDir", 'Machine')
  } else {
    [Environment]::SetEnvironmentVariable('Path', $InstallDir, 'Machine')
  }
} else {
  Write-Log "InstallDir already on machine PATH"
}
$env:Path = "$InstallDir;$env:Path"

# Broadcast WM_SETTINGCHANGE so new Explorer / some apps see PATH immediately.
# Existing open terminals still need a restart — tell the operator below.
try {
  if (-not ('Win32.NativeMethods' -as [type])) {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
  IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
  uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
  }
  $HWND_BROADCAST = [IntPtr]0xffff
  $WM_SETTINGCHANGE = 0x1a
  $result = [UIntPtr]::Zero
  [void][Win32.NativeMethods]::SendMessageTimeout(
    $HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment',
    2, 5000, [ref]$result)
  Write-Log "Broadcast WM_SETTINGCHANGE (Environment)"
} catch {
  Write-Warn "Could not broadcast environment change: $_"
}

Write-Log "Checking nbvpn binary runs: $TargetExe"
& $TargetExe version
if ($LASTEXITCODE -ne 0) {
  if ($osInfo.IsLegacy) {
    $msg = @"
Bundled nbvpn.exe failed to run on this OS (exit $LASTEXITCODE).
Server 2012/2012 R2 needs nbvpn-windows-amd64-win2012.exe (Go ≤ 1.20), not the
Win10+ binary inside modern NetBridge-nbvpn-Setup.exe.
Download the win2012 asset from GitHub Releases and run install.ps1 next to it.
Setup log: $($script:NbVpnSetupLog)
"@
    Save-SetupFailure $msg
    throw $msg
  }
  Write-Warn "nbvpn version returned non-zero (exit $LASTEXITCODE)"
}

Write-Host ""
Write-Host "=== PATH verification ==="
Write-Host "nbvpn.exe: $TargetExe"
$whereOut = & where.exe nbvpn 2>$null
if ($LASTEXITCODE -eq 0 -and $whereOut) {
  Write-Log "where.exe nbvpn:"
  $whereOut | ForEach-Object { Write-Host "  $_" }
} else {
  Write-Warn "where.exe nbvpn failed in THIS session — open a NEW Administrator terminal, then run: where.exe nbvpn"
}
Write-Host "Machine Path write applied this run: $(-not $pathHasInstall)"
# Re-read after write
$verifyPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$verified = $false
if ($verifyPath) {
  foreach ($part in @($verifyPath -split ';')) {
    if ($part -and [string]::Equals($part.TrimEnd('\'), $InstallDir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
      $verified = $true
      break
    }
  }
}
if ($verified) {
  Write-Log "Verified: $InstallDir is on Machine PATH"
} else {
  Write-Warn "Machine PATH may not contain $InstallDir — check System Properties → Environment Variables"
}

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
  $msg = "nbvpn install exited $code (this is not always a WireGuard MSI failure — see Setup log)"
  Save-SetupFailure $msg
  throw $msg
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
Write-Host 'PATH: open a NEW terminal (or log off/on) if nbvpn is not found in an old window.'
Write-Host "Show URI / files / PNG:  nbvpn show"
Write-Host "  (terminal QR skipped on Windows by default; open the .png or use --uri)"
Write-Host "CLI status (profiles / dry-run):  nbvpn status"
Write-Host '  NOTE: nbvpn is a CLI — it is NOT a Windows Service by itself.'
Write-Host '  The tunnel service is WireGuardTunnel$nbvpn (needs WireGuard for Windows).'
if (-not $wgMissing) {
  Write-Host '  WireGuard is present — try: nbvpn start   (elevated; reboot once if MSI reported 3010)'
}
Write-Host "Docs: server\install\windows\WINDOWS.md"
Write-Host "Remember cloud ACL / security group: inbound UDP 51820"
if ($wgRebootSuggested) {
  Write-Host ""
  Write-Host "*** WireGuard MSI requested a reboot (exit 3010). Reboot, then: nbvpn start ***"
}
if ($wgMissing) {
  Write-Host ""
  Write-Host "*** WireGuard missing / unsupported on this OS — keys/profiles only (dry-run) ***"
  Write-Host "*** On Win10+/Server 2016+: re-run Setup/install.ps1 (auto-installs pinned WG MSI) ***"
  Write-Host "*** Do not look for a service named 'nbvpn' — tunnel is WireGuardTunnel`$nbvpn ***"
}
