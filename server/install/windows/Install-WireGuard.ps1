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
    - msiexec 3010 (reboot required) → treat as success; success = wireguard.exe on disk.

.NOTES
  Bundle pin: wireguard-bundle.json next to this script (or under vendor\wireguard).
  msiexec args must be a SINGLE quoted string — Start-Process -ArgumentList @(...)
  mangles paths under "C:\Program Files\..." (space) and yields exit 1619 / 1603.
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
      if (Test-Path -LiteralPath $p) { return (Get-Item -LiteralPath $p).FullName }
    }
    # Any amd64 MSI under vendor\wireguard (filename drift / pin rename)
    $vendor = Join-Path $root 'vendor\wireguard'
    if (Test-Path -LiteralPath $vendor) {
      $hit = Get-ChildItem -LiteralPath $vendor -Filter 'wireguard-amd64*.msi' -ErrorAction SilentlyContinue |
        Select-Object -First 1
      if ($hit) { return $hit.FullName }
    }
  }
  return $null
}

function Get-MsiexecExitHint {
  param([int]$Code)
  switch ($Code) {
    0     { return 'success' }
    3010  { return 'success (reboot required)' }
    1602  { return 'user cancelled' }
    1603  { return 'fatal install error (see MSI log)' }
    1618  { return 'another install in progress — wait and retry' }
    1619  { return 'package could not be opened (path/quoting/permissions)' }
    1625  { return 'install forbidden by system policy' }
    1638  { return 'another version already installed' }
    1641  { return 'success (installer initiated reboot)' }
    default { return 'see MSI log' }
  }
}

function Get-MsiexecLogTail {
  param(
    [string]$LogPath,
    [int]$MaxLines = 40
  )
  if (-not $LogPath -or -not (Test-Path -LiteralPath $LogPath)) { return '' }
  try {
    $lines = Get-Content -LiteralPath $LogPath -ErrorAction Stop
    if (-not $lines) { return '' }
    $interesting = @($lines | Where-Object {
      $_ -match 'error|fail|return value|Product:|MainEngineThread|installation operation' 
    } | Select-Object -Last $MaxLines)
    if (-not $interesting -or $interesting.Count -eq 0) {
      $interesting = @($lines | Select-Object -Last [Math]::Min(15, $lines.Count))
    }
    return ($interesting -join "`n")
  } catch {
    return ''
  }
}

function Install-WireGuardMsiSilent {
  param(
    [Parameter(Mandatory = $true)][string]$MsiPath,
    [string]$ExtraProps = 'DO_NOT_LAUNCH=1',
    [string]$SetupLogDir = ''
  )
  if (-not (Test-Path -LiteralPath $MsiPath)) {
    throw "MSI not found: $MsiPath"
  }
  $resolvedMsi = (Get-Item -LiteralPath $MsiPath).FullName

  $logDir = $SetupLogDir
  if (-not $logDir) { $logDir = Join-Path $env:ProgramData 'nbvpn' }
  if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  }
  $msiLog = Join-Path $logDir 'wireguard-msiexec.log'
  # Also mirror under TEMP for users who cannot browse ProgramData easily
  $msiLogTemp = Join-Path $env:TEMP 'nbvpn-wireguard-msiexec.log'

  Write-Host "==> Silent install: msiexec /i `"$resolvedMsi`" $ExtraProps /qn /norestart"
  Write-Host "==> msiexec log: $msiLog"
  Write-Host "==> msiexec log (TEMP copy): $msiLogTemp"

  # CRITICAL: one ArgumentList string with quoted paths.
  # Array form breaks on "C:\Program Files\NetBridge\vendor\wireguard\*.msi".
  $arg = "/i `"$resolvedMsi`""
  if ($ExtraProps) {
    foreach ($tok in ($ExtraProps -split '\s+')) {
      if ($tok) { $arg += " $tok" }
    }
  }
  $arg += " /qn /norestart /l*v `"$msiLog`""

  $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arg -Wait -PassThru -WindowStyle Hidden
  if ($null -eq $p) { throw 'msiexec failed to start' }

  if (Test-Path -LiteralPath $msiLog) {
    Copy-Item -Force -LiteralPath $msiLog -Destination $msiLogTemp -ErrorAction SilentlyContinue
  }

  $code = [int]$p.ExitCode
  $hint = Get-MsiexecExitHint -Code $code
  Write-Host ("==> msiexec exit {0} ({1})" -f $code, $hint)

  # 0 / 3010 / 1641 = success family
  if ($code -eq 0 -or $code -eq 3010 -or $code -eq 1641) {
    if ($code -eq 3010 -or $code -eq 1641) {
      Write-Warning 'WireGuard MSI reports reboot required. Reboot before nbvpn start if the tunnel driver fails to load.'
    }
    return $code
  }

  # 1638 = product already installed (version conflict) — accept if exe exists
  if ($code -eq 1638) {
    $existing = Find-WireGuardExe
    if ($existing) {
      Write-Warning "msiexec 1638 (another version present) but wireguard.exe found — treating as OK ($existing)"
      return 0
    }
  }

  $tail = Get-MsiexecLogTail -LogPath $msiLog
  $msg = @"
msiexec exited $code ($hint) installing WireGuard MSI.
MSI: $resolvedMsi
Log: $msiLog
TEMP: $msiLogTemp
"@
  if ($tail) { $msg += "`n---`n$tail`n---" }
  throw $msg
}

<#
.SYNOPSIS
  Ensure WireGuard for Windows is available for nbvpn tunnel ops.

.OUTPUTS
  Hashtable: Status (Present|Installed|LegacyUnsupported|Skipped|Failed), Path, Message, RebootSuggested, MsiexecLog
#>
function Ensure-WireGuardForWindows {
  [CmdletBinding()]
  param(
    [string[]]$SearchRoots,
    [switch]$AllowDownload,
    [switch]$SkipInstall,
    [switch]$ForceLegacyDryRun,
    [string]$SetupLogDir = ''
  )

  $result = @{
    Status           = 'Failed'
    Path             = $null
    Message          = ''
    RebootSuggested  = $false
    MsiexecLog       = ''
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
This host looks like Server 2012 / 2012 R2 — automatic WG install is SKIPPED (not a hard failure).
Profiles/keys will still be written (dry-run). For a real tunnel, use Server 2016+
or install a historically compatible WireGuard build yourself:
  https://www.wireguard.com/install/
On 2012 prefer: nbvpn-windows-amd64-win2012.exe + install.ps1 (not modern Setup.exe alone).
'@
    Write-Warning $result.Message
    return $result
  }

  $pin = Get-WireGuardBundlePin -SearchRoots $SearchRoots
  if (-not $pin) {
    $result.Message = @"
wireguard-bundle.json not found next to install scripts.
Searched roots: $($SearchRoots -join '; ')
Expected: <root>\wireguard-bundle.json or <root>\vendor\wireguard\wireguard-bundle.json
"@
    Write-Warning $result.Message
    return $result
  }

  $filename = [string]$pin.filename
  $sha = [string]$pin.sha256
  $url = [string]$pin.url
  $extra = if ($pin.msiexecExtra) { [string]$pin.msiexecExtra } else { 'DO_NOT_LAUNCH=1' }

  Write-Host "==> WireGuard pin: $($pin.version) / $filename"
  Write-Host "==> SearchRoots: $($SearchRoots -join ' | ')"

  $msi = Find-BundledWireGuardMsi -SearchRoots $SearchRoots -Filename $filename
  if (-not $msi) {
    if (-not $AllowDownload) {
      $result.Message = "Bundled MSI missing ($filename) under: $($SearchRoots -join '; ') — download disabled"
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
        $result.Message = "Bundled MSI SHA256 mismatch (expected $($sha.ToLowerInvariant()), got $got)`nMSI: $msi"
        Write-Warning $result.Message
        return $result
      }
      Write-Host "==> Bundled MSI SHA256 OK"
    }
  }

  $downloadedTmp = $false
  if ($msi -and $env:TEMP -and $msi.StartsWith([string]$env:TEMP, [StringComparison]::OrdinalIgnoreCase)) {
    $downloadedTmp = $true
  }

  $logDir = $SetupLogDir
  if (-not $logDir) { $logDir = Join-Path $env:ProgramData 'nbvpn' }
  $result.MsiexecLog = Join-Path $logDir 'wireguard-msiexec.log'

  try {
    $code = Install-WireGuardMsiSilent -MsiPath $msi -ExtraProps $extra -SetupLogDir $logDir
    if ($code -eq 3010 -or $code -eq 1641) { $result.RebootSuggested = $true }
  } catch {
    # Partial install: msiexec non-zero but binary appeared
    $maybe = Find-WireGuardExe
    if ($maybe) {
      Write-Warning "msiexec reported failure but wireguard.exe is present — accepting ($maybe)"
      Add-WireGuardToSessionPath -WireGuardExe $maybe
      $result.Status = 'Installed'
      $result.Path = $maybe
      $result.Message = "WireGuard present after msiexec warning: $maybe (`n$_)"
      return $result
    }
    $result.Message = @"
WireGuard silent install failed:
$_

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

  # Refresh discovery after MSI — success criterion is wireguard.exe on disk
  Start-Sleep -Seconds 2
  $existing = Find-WireGuardExe
  if (-not $existing) {
    $probe = Join-Path ${env:ProgramFiles} 'WireGuard\wireguard.exe'
    if (Test-Path -LiteralPath $probe) { $existing = $probe }
  }
  if (-not $existing) {
    $tail = Get-MsiexecLogTail -LogPath $result.MsiexecLog
    $result.Message = @"
WireGuard MSI finished (exit OK/3010) but wireguard.exe was not found under Program Files.
Msiexec log: $($result.MsiexecLog)
TEMP copy: $(Join-Path $env:TEMP 'nbvpn-wireguard-msiexec.log')
Try a NEW elevated PowerShell, or reboot if msiexec returned 3010, then:
  nbvpn install
  nbvpn start
$tail
"@
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
