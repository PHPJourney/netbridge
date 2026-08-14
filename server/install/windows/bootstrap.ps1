<#
.SYNOPSIS
  NetBridge nbvpn — Windows one-liner bootstrap (like Linux curl | bash)

.DESCRIPTION
  Detects OS, downloads the correct installer from GitHub Releases, and runs
  elevated install. Prefer Setup.exe on Server 2016+ / Windows 10+ (Setup bundles
  WireGuard MSI); on Server 2012 / 2012 R2 downloads win2012 exe + install.ps1
  (official WG not auto-installed on 2012).

.EXAMPLE
  irm https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/windows/bootstrap.ps1 | iex
#>
[CmdletBinding()]
param(
  [string]$ReleaseBase = $(if ($env:NBVPN_RELEASE_BASE) { $env:NBVPN_RELEASE_BASE } else { 'https://github.com/PHPJourney/netbridge/releases/latest/download' }),
  [string]$InstallPs1Url = $(if ($env:NBVPN_INSTALL_PS1_URL) { $env:NBVPN_INSTALL_PS1_URL } else { 'https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/windows/install.ps1' }),
  [string]$BootstrapUrl = $(if ($env:NBVPN_BOOTSTRAP_URL) { $env:NBVPN_BOOTSTRAP_URL } else { 'https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/windows/bootstrap.ps1' }),
  [string]$SetupName = 'NetBridge-nbvpn-Setup.exe',
  [string]$Win2012Name = 'nbvpn-windows-amd64-win2012.exe'
)

$ErrorActionPreference = 'Stop'

function Write-Log([string]$Message) { Write-Host "==> $Message" }
function Write-Warn([string]$Message) { Write-Warning $Message }

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-IsLegacyWindows {
  $ver = [Environment]::OSVersion.Version
  # Server 2012 / 2012 R2 = 6.2 / 6.3; Windows 10+ / Server 2016+ = 10.0
  return ($ver.Major -lt 10)
}

function Save-RemoteFile([string]$Uri, [string]$OutFile) {
  Write-Log "Downloading $Uri"
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
  } catch {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($Uri, $OutFile)
  }
  if (-not (Test-Path -LiteralPath $OutFile)) {
    throw "Download failed: $Uri"
  }
}

# --- Elevate if needed (works for irm | iex and -File) ---
if (-not (Test-IsAdmin)) {
  Write-Log "Not elevated — re-launching as Administrator…"
  $tmpScript = Join-Path $env:TEMP ("nbvpn-bootstrap-" + [guid]::NewGuid().ToString('n') + '.ps1')
  Save-RemoteFile -Uri $BootstrapUrl -OutFile $tmpScript
  $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`""
  $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arg -PassThru -Wait
  if ($null -eq $p) { throw 'UAC elevation was cancelled or failed.' }
  exit $p.ExitCode
}

$work = Join-Path $env:TEMP ("nbvpn-bootstrap-work-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
  $legacy = Get-IsLegacyWindows
  Write-Log ("OS build {0}.{1} (legacy={2})" -f [Environment]::OSVersion.Version.Major, [Environment]::OSVersion.Version.Minor, $legacy)

  if (-not $legacy) {
    $setupPath = Join-Path $work $SetupName
    $setupUrl = ($ReleaseBase.TrimEnd('/') + '/' + $SetupName)
    Save-RemoteFile -Uri $setupUrl -OutFile $setupPath
    Write-Log "Starting Setup (elevated GUI)…"
    $proc = Start-Process -FilePath $setupPath -Wait -PassThru
    if ($null -eq $proc) { throw 'Failed to start Setup.exe' }
    if ($proc.ExitCode -ne 0) {
      throw ("Setup.exe exited with code {0}" -f $proc.ExitCode)
    }
    Write-Log 'Setup finished. Open a NEW PowerShell and run: nbvpn show'
    return
  }

  # Server 2012 / 2012 R2 — no modern Setup; use install.ps1 + win2012 exe
  Write-Warn 'Legacy Windows detected — using win2012 exe + install.ps1 (no GUI Setup).'
  $exePath = Join-Path $work $Win2012Name
  $ps1Path = Join-Path $work 'install.ps1'
  $exeUrl = ($ReleaseBase.TrimEnd('/') + '/' + $Win2012Name)
  Save-RemoteFile -Uri $exeUrl -OutFile $exePath
  Save-RemoteFile -Uri $InstallPs1Url -OutFile $ps1Path

  Write-Log "Running install.ps1…"
  $inst = Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`"" -Wait -PassThru
  if ($null -eq $inst -or $inst.ExitCode -ne 0) {
    $code = if ($inst) { $inst.ExitCode } else { -1 }
    throw ("install.ps1 exited with code {0}" -f $code)
  }
  Write-Log 'Install finished. Open a NEW PowerShell and run: nbvpn show'
}
finally {
  Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
}
