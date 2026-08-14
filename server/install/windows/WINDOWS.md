# Windows Server — nbvpn MVP

NetBridge VPN **node** on Windows Server (or Windows 10/11 lab). Linux install path is unchanged (`server/install/install.sh`) and **already installs** `wireguard` / `wireguard-tools` via apt or dnf/yum.

## Preferred install: Setup.exe

| Artifact | When |
|----------|------|
| **`NetBridge-nbvpn-Setup.exe`** | **Primary** — download and Run as Administrator (no CLI). **Bundles + silently installs** pinned WireGuard for Windows when missing |
| `bootstrap.ps1` one-liner | Advanced / headless — like Linux `curl \| bash` |
| `install.ps1` + `nbvpn-windows-amd64*.exe` | Manual advanced / scripting (same WG auto-install) |
| `nbvpn-windows-amd64-win2012.exe` | Server **2012 / 2012 R2** only (Go 1.20 binary; **no** official WG auto-install) |

### Store UX

1. **Most users:** download Setup.exe → right-click → Run as administrator.
2. **Advanced:** PowerShell one-liner (auto-elevates; picks Setup vs 2012 path):

```powershell
irm https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/windows/bootstrap.ps1 | iex
```

Download from [GitHub Releases](https://github.com/PHPJourney/netbridge/releases). After Setup / install:

```powershell
# Open a NEW PowerShell / cmd (PATH refresh). Then:
where.exe nbvpn
nbvpn show          # URI + file paths + QR PNG (no terminal QR on Windows by default)
explorer $env:ProgramData\nbvpn   # ProgramData is often HIDDEN
nbvpn status        # CLI status — NOT the same as a Windows Service named "nbvpn"
nbvpn start         # elevates tunnel via WireGuardTunnel$nbvpn (WG must be installed)
```

### PATH vs WireGuard service (common confusion)

| What you look for | What it actually is |
|-------------------|---------------------|
| `nbvpn` on PATH | CLI binary under `C:\Program Files\NetBridge\nbvpn.exe` (Setup / `install.ps1` add **Machine** PATH) |
| `nbvpn status` | Prints tunnel/profile state; **not** a Service Control Manager name |
| Windows Service | **`WireGuardTunnel$nbvpn`** — after WireGuard is installed (Setup does this) and `nbvpn install` / `start` succeeds |
| “找不到服务进程” | Usually means WG install failed / legacy OS dry-run **or** you searched for a service named `nbvpn` — there isn’t one |

Client Setup (`NetBridge-windows-setup.exe`) does **not** need PATH (GUI app). Server Setup **must** put `nbvpn` on system PATH.

If `nbvpn` is not found after Setup: close old terminals, open a **new** elevated prompt, run `where.exe nbvpn`. If still missing, check System → Environment Variables → Path for `C:\Program Files\NetBridge`.

## WireGuard dependency (bundled)

| Topic | Policy |
|-------|--------|
| **What** | Official **WireGuard for Windows** amd64 MSI (enterprise silent path) |
| **Pin** | `server/install/windows/wireguard-bundle.json` (version, URL, SHA256) |
| **Setup** | CI downloads MSI into Setup → `{app}\vendor\wireguard\` |
| **Install** | `install.ps1` → `Install-WireGuard.ps1`: if `wireguard.exe` **already present → skip** (no upgrade). Else silent `msiexec /i … DO_NOT_LAUNCH=1 /qn` |
| **Offline** | Bundled MSI preferred; if missing, download pinned URL + SHA256 verify |
| **Failure** | On Win10+/Server 2016+: **hard error** with manual link (use `-SkipWireGuard` only for dry-run labs) |
| **License** | WireGuard is **GPLv2** — see Setup license page / `THIRDPARTY-NOTICE.txt` |
| **Server 2012** | Official WG **1.1+ does not support** 2012/2012 R2 — auto-install **skipped**, keys/profiles still written, message is explicit (not silent dry-run) |

After a successful WG install you should be able to run `nbvpn start` in a **new elevated** PowerShell. If MSI returned **3010**, **reboot once** then `nbvpn start`.

## What works (MVP)

| Capability | Status |
|------------|--------|
| `NetBridge-nbvpn-Setup.exe` (Inno) | Yes (CI windows-2022 + Inno Setup 6; includes `nbvpn-gui.exe` + pinned WG MSI) |
| Cross-compile `nbvpn-windows-amd64.exe` (Win10+) | Yes |
| Cross-compile `nbvpn-gui-windows-amd64.exe` | Yes (local browser UI; shells out to `nbvpn`) |
| Cross-compile `nbvpn-windows-amd64-win2012.exe` | Yes (**Go 1.20**; GUI not required on 2012) |
| `nbvpn install` / `show` (URI + PNG + `.nbvpn.json` + `.conf`) | Yes — even without WireGuard (dry-run / 2012) |
| Terminal QR in console | **Skipped by default on Windows** (`nbvpn show --qr` opt-in; no ANSI unless forced) |
| Tunnel via **WireGuard for Windows** | Auto-installed on Win10+/2016+; then `nbvpn start` |
| Host firewall UDP **51820** | Setup / `install.ps1` |
| IPv4 forwarding | Yes |
| Client internet (NAT) | `New-NetNat` on Server **2016+**; **skipped on 2012** → RRAS/ICS |

## Which binary?

| Target OS | Artifact | Build toolchain |
|-----------|----------|-----------------|
| **Server 2012 / 2012 R2** | `nbvpn-windows-amd64-win2012.exe` + `install.ps1` | **Go ≤ 1.20** |
| **Windows 10/11, Server 2016+** | **`NetBridge-nbvpn-Setup.exe`** or `nbvpn-windows-amd64.exe` | Go 1.22+ |

**Flutter NetBridge client** needs **Windows 10+** — see `clients/netbridge/dist/WINDOWS-BUILD.md` and **`NetBridge-windows-setup.exe`**.

## Prerequisites

1. Elevated install (Setup.exe or Administrator PowerShell).
2. **WireGuard for Windows** — **included** by Setup / `install.ps1` on Win10+/Server 2016+ (no separate trip to wireguard.com for the normal path).
3. Cloud security group: inbound **UDP 51820**.

### Linux note

`server/install/deb-family.sh` / `rhel-family.sh` already install `wireguard` / `wireguard-tools` (and related packages) before `nbvpn install`. No change required for this Windows-focused work.

### Server 2012 / 2012 R2 (lab)

- OS is **out of support**; current official WireGuard MSI targets **Windows 10 / Server 2016+**.
- Use **win2012** exe + `install.ps1` (Setup.exe targets modern Windows).
- `New-NetNat` is **skipped** — configure **RRAS NAT** or **ICS** for client internet.
- WG auto-install is **skipped with an explicit banner**; install still writes `%ProgramData%\nbvpn` (keys, PNG, JSON, conf). Real tunnel needs a newer Windows Server (or a self-managed historical WG build).

## Install

### A. Setup.exe (recommended on Server 2016+)

1. Download `NetBridge-nbvpn-Setup.exe` from Releases.
2. Run as Administrator; accept the short third-party notice (WireGuard GPLv2).
3. Wizard runs `install.ps1`, which installs WireGuard if missing, then `nbvpn install`.
4. Open a **new** elevated PowerShell:

```powershell
where.exe nbvpn
nbvpn show --uri
nbvpn status
nbvpn start
explorer $env:ProgramData\nbvpn
```

### B. PowerShell (advanced / 2012)

```powershell
mkdir C:\NetBridge\deploy -Force
# copy install.ps1 + Install-WireGuard.ps1 + wireguard-bundle.json
# + nbvpn-windows-amd64-win2012.exe (or amd64.exe) into that folder
# optional: vendor\wireguard\wireguard-amd64-*.msi for offline
cd C:\NetBridge\deploy
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Or: `setup.bat` (same folder) as Administrator.

`install.ps1` will:

1. Detect WireGuard; if missing on modern Windows, install pinned MSI (bundle or download + SHA256)
2. Copy `nbvpn.exe` → install dir (default `C:\Program Files\NetBridge`) and write **Machine** PATH + broadcast `WM_SETTINGCHANGE`
3. Print `where.exe nbvpn` verification (open a **new** terminal if an old session still fails)
4. Enable IPv4 forwarding; **NetNat only if API supports it** (not 2012)
5. Open firewall UDP 51820
6. Run `nbvpn install` (creates data dir + peer exports)
7. Print a **dir verification** of `%ProgramData%\nbvpn`

Inno Setup also appends `{app}` to system PATH (`ChangesEnvironment=yes`) before/with `install.ps1`.

### Data directory (hidden)

Default: `%ProgramData%\nbvpn` (override: `NBVPN_DATA_DIR`).

**ProgramData is a hidden folder.** If Explorer “cannot find” it under `C:\`:

```powershell
explorer C:\ProgramData\nbvpn
# or View → Hidden items in Explorer
dir $env:ProgramData\nbvpn\peers
```

After `nbvpn show` / `show --qr`, nbvpn also:

- Prints a conspicuous **Wrote QR PNG** block + `explorer /select,"…"` hint
- Tries to open/reveal the PNG
- Copies to **Desktop** (`nbvpn-peer-*.png`) and `%PUBLIC%\Documents\nbvpn\` (non-hidden)

Files after install: `server.json`, `nbvpn.conf`, `peers\<id>.nbvpn.json`, `.png`, `.conf`.

## GUI + CLI (both supported)

| Tool | Role |
|------|------|
| **`nbvpn-gui.exe`** | Local browser UI: **Start / Stop / Status**, open data dir, open peer QR, copy URI, show `nbvpn config` |
| **`nbvpn.exe`** | Full CLI (unchanged) — install, peer, config set endpoint, etc. |

Setup installs both under `C:\Program Files\NetBridge\` and adds a Start Menu shortcut **NetBridge nbvpn GUI**.

```powershell
# After Setup (new terminal):
nbvpn-gui          # or Start Menu → NetBridge nbvpn GUI
nbvpn status       # CLI still works
```

GUI shells out to the installed `nbvpn.exe` (same directory / PATH) — no second copy of tunnel logic.

## Show / QR on Windows

| Command | Behavior |
|---------|----------|
| `nbvpn show` | URI + paths + **PNG** (Desktop copy + reveal on Windows); **no** terminal block QR |
| `nbvpn show --uri` | URI only |
| `nbvpn show --qr` | Terminal QR **opt-in**; still **clamped** (~48–56 cols); dense URIs → skip + recommend PNG |
| Open `.png` | Preferred for phone scan (Desktop copy or ProgramData) |

## Cross-compile — Docker (Mac)

```bash
./server/nbvpn/scripts/build-windows-docker.sh all
```

Local Setup.exe (Windows host with Inno Setup 6):

```powershell
# after placing exe + scripts in a stage folder:
.\server\install\windows\build-setup.ps1 -StageDir C:\stage
# downloads pinned WG MSI into stage\vendor\wireguard unless -SkipWireGuardDownload
```

## Manual tunnel / service name

```powershell
wireguard.exe /installtunnelservice "$env:ProgramData\nbvpn\nbvpn.conf"
sc.exe query WireGuardTunnel`$nbvpn
# There is no Windows Service named "nbvpn". CLI: nbvpn status | start | stop
```

## Gaps vs Linux (honest)

1. **NAT on 2012**: no `New-NetNat` — use RRAS/ICS.
2. **Server 2012 + current WG**: no official tunnel — dry-run profiles only.
3. **arm64 Windows** not in MVP artifacts.
4. **Reboot**: rare (`msiexec` 3010) before Wintun/WireGuardNT loads.

## Related

- Client Setup: `NetBridge-windows-setup.exe` (Flutter)
- Linux: `server/install/install.sh` (apt/dnf installs WireGuard tools)
- CI: `.github/workflows/build-server.yml` → artifact `NetBridge-nbvpn-Setup.exe`
- Pin file: `server/install/windows/wireguard-bundle.json`
