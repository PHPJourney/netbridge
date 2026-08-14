#Requires -Version 4
<#
.SYNOPSIS
  Detect / install pinned WireGuard for Windows (amd64 MSI).

.DESCRIPTION
  Dot-source from install.ps1 or call Ensure-WireGuardForWindows.
  Policy:
    - If wireguard.exe already present → skip (do not upgrade).
    - Windows 10+ / Server 2016+: install bundled MSI, or download pinned URL + SHA256.
    - Server 2012 / 2012 R2: do not install modern MSI; return LegacyUnsupported.
    - Silent MSI: msiexec /i … DO_NOT_LAUNCH=1 /qn

.NOTES
  Bundle pin: wireguard-bundle.json next to this script (or under vendor\wireguard).
#>

function Get-WireGuardBundlePin {
  param([string[]]$SearchRoots)
  foreach ($root in $SearchRoots) {
    if (-not $root) { continue }
    foreach ($rel in @(
      'wireguard-bundle.json',
      'vendor\wireguard\wireguard-bundle.json'
    )) {
      $p = Join-Path $root $rel
      if (Test-Path -LiteralPath $p) {
        try {
          return (Get-Content -LiteralPath $p -Raw -ErrorAction Stop | ConvertFrom-Json)
        } catch {
          Write-Warning "Failed to parse $p : $_"
        }
      }
    }
  }
  return $null
}

function Find-WireGuardExe {
  $cmd = Get-Command wireguard.exe -ErrorAction SilentlyContinue
  if ($cmd) {
    if ($cmd.Source) { return [string]$cmd.Source }
    if ($cmd.Path) { return [string]$cmd.Path }
  }
  $cands = @(
    (Join-Path ${env:ProgramFiles} 'WireGuard\wireguard.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wireguard.exe')
  )
  foreach ($p in $cands) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  return $null
}

function Add-WireGuardToSessionPath {
  param([string]$WireGuardExe)
  if (-not $WireGuardExe) { return }
  $dir = Split-Path -Parent -Path $WireGuardExe
  if (-not $dir) { return }
  $env:Path = "$dir;$env:Path"
  $wg = Join-Path $dir 'wg.exe'
  if (Test-Path -LiteralPath $wg) {
    # already on Path via $dir
  }
}

function Test-WireGuardLegacyOs {
  $ver = [Environment]::OSVersion.Version
  return ($ver.Major -lt 10)
}

function Get-FileSha256Hex {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())
  }
  # Server 2012 / PS4 fallback
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $fs = [System.IO.File]::OpenRead($Path)
    try {
      $bytes = $sha.ComputeHash($fs)
    } finally {
      $fs.Close()
    }
  } finally {
    $sha.Dispose()
  }
  return ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
}

function Save-RemoteFileChecked {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [string]$ExpectedSha256 = ''
  )
  $parent = Split-Path -Parent -Path $OutFile
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  Write-Host "==> Downloading $Uri"
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
  } catch {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($Uri, $OutFile)
  }
  if (-not (Test-Path -LiteralPath $OutFile)) {
    throw "Download failed: $Uri"
  }
  if ($ExpectedSha256) {
    $got = Get-FileSha256Hex -Path $OutFile
    $want = $ExpectedSha256.ToLowerInvariant()
    if ($got -ne $want) {
      Remove-Item -Force -LiteralPath $OutFile -ErrorAction SilentlyContinue
      throw "SHA256 mismatch for $OutFile`n  expected: $want`n  got:      $got"
    }
    Write-Host "==> SHA256 OK ($got)"
  }
}

function Find-BundledWireGuardMsi {
  param(
    [string[]]$SearchRoots,
    [string]$Filename
  )
  foreach ($root in $SearchRoots) {
    if (-not $root) { continue }
    foreach ($rel in @(
      (Join-Path 'vendor\wireguard' $Filename),
      $Filename,
      (Join-Path 'wireguard' $Filename)
    )) {
      $p = Join-Path $root $rel
      if (Test-Path -LiteralPath $p) { return $p }
    }
  }
  return $null
}

function Install-WireGuardMsiSilent {
  param(
    [Parameter(Mandatory = $true)][string]$MsiPath,
    [string]$ExtraProps = 'DO_NOT_LAUNCH=1'
  )
  if (-not (Test-Path -LiteralPath $MsiPath)) {
    throw "MSI not found: $MsiPath"
  }
  $logDir = Join-Path $env:ProgramData 'nbvpn'
  if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  }
  $msiLog = Join-Path $logDir 'wireguard-msiexec.log'
  Write-Host "==> Silent install: msiexec /i `"$MsiPath`" $ExtraProps /qn /norestart /l*v `"$msiLog`""
  $argList = @('/i', $MsiPath)
  if ($ExtraProps) {
    foreach ($tok in ($ExtraProps -split '\s+')) {
      if ($tok) { $argList += $tok }
    }
  }
  $argList += @('/qn', '/norestart', '/l*v', $msiLog)
  # Use -Wait so Setup / install.ps1 does not continue before MSI finishes.
  $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
  if ($null -eq $p) { throw 'msiexec failed to start' }
  # 0 = success; 3010 = success reboot required
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
    throw ("msiexec exited {0} installing WireGuard MSI (log: {1})" -f $p.ExitCode, $msiLog)
  }
  if ($p.ExitCode -eq 3010) {
    Write-Warning 'WireGuard MSI reports reboot required (3010). A reboot may be needed before the tunnel driver loads.'
  }
  return $p.ExitCode
}

<#
.SYNOPSIS
  Ensure WireGuard for Windows is available for nbvpn tunnel ops.

.OUTPUTS
  Hashtable: Status (Present|Installed|LegacyUnsupported|Skipped|Failed), Path, Message, RebootSuggested
#>
function Ensure-WireGuardForWindows {
  [CmdletBinding()]
  param(
    [string[]]$SearchRoots,
    [switch]$AllowDownload,
    [switch]$SkipInstall,
    [switch]$ForceLegacyDryRun
  )

  $result = @{
    Status           = 'Failed'
    Path             = $null
    Message          = ''
    RebootSuggested  = $false
  }

  $existing = Find-WireGuardExe
  if ($existing) {
    Add-WireGuardToSessionPath -WireGuardExe $existing
    $result.Status = 'Present'
    $result.Path = $existing
    $result.Message = "WireGuard already installed — skip ($existing)"
    Write-Host "==> $($result.Message)"
    return $result
  }

  if ($SkipInstall) {
    $result.Status = 'Skipped'
    $result.Message = 'SkipWireGuard set — not installing WireGuard'
    Write-Warning $result.Message
    return $result
  }

  if ((Test-WireGuardLegacyOs) -or $ForceLegacyDryRun) {
    $result.Status = 'LegacyUnsupported'
    $result.Message = @'
Official WireGuard for Windows (1.1+) requires Windows 10 / Server 2016+.
This host looks like Server 2012 / 2012 R2 — automatic WG install is SKIPPED.
Profiles/keys will still be written (dry-run). For a real tunnel, use Server 2016+
or install a historically compatible WireGuard build yourself:
  https://www.wireguard.com/install/
'@
    Write-Warning $result.Message
    return $result
  }

  $pin = Get-WireGuardBundlePin -SearchRoots $SearchRoots
  if (-not $pin) {
    $result.Message = 'wireguard-bundle.json not found next to install scripts'
    Write-Warning $result.Message
    return $result
  }

  $filename = [string]$pin.filename
  $sha = [string]$pin.sha256
  $url = [string]$pin.url
  $extra = if ($pin.msiexecExtra) { [string]$pin.msiexecExtra } else { 'DO_NOT_LAUNCH=1' }

  $msi = Find-BundledWireGuardMsi -SearchRoots $SearchRoots -Filename $filename
  if (-not $msi) {
    if (-not $AllowDownload) {
      $result.Message = "Bundled MSI missing ($filename) and download disabled"
      Write-Warning $result.Message
      return $result
    }
    $tmp = Join-Path $env:TEMP ("nbvpn-wg-" + [guid]::NewGuid().ToString('n') + '-' + $filename)
    try {
      Save-RemoteFileChecked -Uri $url -OutFile $tmp -ExpectedSha256 $sha
      $msi = $tmp
    } catch {
      $result.Message = @"
Failed to download WireGuard MSI: $_
Manual install (then re-run install.ps1 / Setup):
  $url
  https://www.wireguard.com/install/
"@
      Write-Warning $result.Message
      return $result
    }
  } else {
    Write-Host "==> Using bundled MSI: $msi"
    if ($sha) {
      $got = Get-FileSha256Hex -Path $msi
      if ($got -ne $sha.ToLowerInvariant()) {
        $result.Message = "Bundled MSI SHA256 mismatch (expected $($sha.ToLowerInvariant()), got $got)"
        Write-Warning $result.Message
        return $result
      }
      Write-Host "==> Bundled MSI SHA256 OK"
    }
  }

  $downloadedTmp = $false
  if ($msi -and $msi.StartsWith([string]$env:TEMP, [StringComparison]::OrdinalIgnoreCase)) {
    $downloadedTmp = $true
  }

  try {
    $code = Install-WireGuardMsiSilent -MsiPath $msi -ExtraProps $extra
    if ($code -eq 3010) { $result.RebootSuggested = $true }
  } catch {
    $result.Message = @"
WireGuard silent install failed: $_
Install manually, then re-run:
  msiexec /i `"$msi`" $extra /qn
  or download: $url
  https://www.wireguard.com/install/
"@
    Write-Warning $result.Message
    return $result
  } finally {
    if ($downloadedTmp -and $msi -and (Test-Path -LiteralPath $msi)) {
      Remove-Item -Force -LiteralPath $msi -ErrorAction SilentlyContinue
    }
  }

  # Refresh discovery after MSI
  Start-Sleep -Seconds 2
  $existing = Find-WireGuardExe
  if (-not $existing) {
    # msiexec may not update PATH for this process; probe default location
    $probe = Join-Path ${env:ProgramFiles} 'WireGuard\wireguard.exe'
    if (Test-Path -LiteralPath $probe) { $existing = $probe }
  }
  if (-not $existing) {
    $result.Message = @'
WireGuard MSI finished but wireguard.exe was not found under Program Files.
Try opening a NEW elevated PowerShell, or reboot if msiexec returned 3010, then:
  nbvpn install
  nbvpn start
'@
    Write-Warning $result.Message
    return $result
  }

  Add-WireGuardToSessionPath -WireGuardExe $existing
  $result.Status = 'Installed'
  $result.Path = $existing
  $result.Message = "Installed WireGuard $($pin.version) → $existing"
  Write-Host "==> $($result.Message)"
  return $result
}
