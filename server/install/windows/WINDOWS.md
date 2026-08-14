# Windows Server — nbvpn MVP

NetBridge VPN **node** on Windows Server (or Windows 10/11 lab). Linux install path is unchanged (`server/install/install.sh`).

## Preferred install: Setup.exe

| Artifact | When |
|----------|------|
| **`NetBridge-nbvpn-Setup.exe`** | **Primary** — Inno Setup installer (Program Files + elevated `install.ps1`) |
| `install.ps1` + `nbvpn-windows-amd64*.exe` | Advanced / Server 2012 lab / scripting |
| `nbvpn-windows-amd64-win2012.exe` | Server **2012 / 2012 R2** only (Go 1.20 binary) |

Download from [GitHub Releases](https://github.com/PHPJourney/netbridge/releases). After Setup / install:

```powershell
# Open a NEW PowerShell / cmd (PATH refresh). Then:
where.exe nbvpn
nbvpn show          # URI + file paths + QR PNG (no terminal QR on Windows by default)
explorer $env:ProgramData\nbvpn   # ProgramData is often HIDDEN
nbvpn status        # CLI status — NOT the same as a Windows Service named "nbvpn"
```

### PATH vs WireGuard service (common confusion)

| What you look for | What it actually is |
|-------------------|---------------------|
| `nbvpn` on PATH | CLI binary under `C:\Program Files\NetBridge\nbvpn.exe` (Setup / `install.ps1` add **Machine** PATH) |
| `nbvpn status` | Prints tunnel/profile state; **not** a Service Control Manager name |
| Windows Service | **`WireGuardTunnel$nbvpn`** — only after **WireGuard for Windows** is installed and `nbvpn install` / `start` succeeds |
| “找不到服务进程” | Usually means WireGuard is missing (dry-run) **or** you searched for a service named `nbvpn` — there isn’t one |

Client Setup (`NetBridge-windows-setup.exe`) does **not** need PATH (GUI app). Server Setup **must** put `nbvpn` on system PATH.

If `nbvpn` is not found after Setup: close old terminals, open a **new** elevated prompt, run `where.exe nbvpn`. If still missing, check System → Environment Variables → Path for `C:\Program Files\NetBridge`.

## What works (MVP)

| Capability | Status |
|------------|--------|
| `NetBridge-nbvpn-Setup.exe` (Inno) | Yes (CI windows-2022 + Inno Setup 6) |
| Cross-compile `nbvpn-windows-amd64.exe` (Win10+) | Yes |
| Cross-compile `nbvpn-windows-amd64-win2012.exe` | Yes (**Go 1.20**) |
| `nbvpn install` / `show` (URI + PNG + `.nbvpn.json` + `.conf`) | Yes — **even without WireGuard** (dry-run) |
| Terminal QR in console | **Skipped by default on Windows** (`nbvpn show --qr` opt-in; no ANSI unless forced) |
| Tunnel via **WireGuard for Windows** | Yes when WireGuard is installed |
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
2. **[WireGuard for Windows](https://www.wireguard.com/install/)** for a **real tunnel** (optional for key/profile export).
3. Cloud security group: inbound **UDP 51820**.

### Server 2012 / 2012 R2 (lab)

- OS is **out of support**; WireGuard/Wintun targets newer Windows.
- Use **win2012** exe + `install.ps1` (Setup.exe targets modern Windows).
- `New-NetNat` is **skipped** — configure **RRAS NAT** or **ICS** for client internet.
- Without WireGuard: install still writes `%ProgramData%\nbvpn` (keys, PNG, JSON, conf).

## Install

### A. Setup.exe (recommended on Server 2016+)

1. Download `NetBridge-nbvpn-Setup.exe` from Releases.
2. Run as Administrator; follow the wizard (runs `install.ps1`).
3. Install WireGuard if prompted / missing, then re-run Setup or `nbvpn install`.
4. Open profiles:

```powershell
explorer $env:ProgramData\nbvpn
nbvpn show --uri
```

### B. PowerShell (advanced / 2012)

```powershell
mkdir C:\NetBridge\deploy -Force
# copy install.ps1 + nbvpn-windows-amd64-win2012.exe (or amd64.exe) into that folder
cd C:\NetBridge\deploy
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Or: `setup.bat` (same folder) as Administrator.

`install.ps1` will:

1. Copy `nbvpn.exe` → install dir (default `C:\Program Files\NetBridge`) and write **Machine** PATH + broadcast `WM_SETTINGCHANGE`
2. Print `where.exe nbvpn` verification (open a **new** terminal if an old session still fails)
3. Enable IPv4 forwarding; **NetNat only if API supports it** (not 2012)
4. Open firewall UDP 51820
5. Run `nbvpn install` (creates data dir + peer exports even without WireGuard)
6. Print a **dir verification** of `%ProgramData%\nbvpn`

Inno Setup also appends `{app}` to system PATH (`ChangesEnvironment=yes`) before/with `install.ps1`.

### Data directory (hidden)

Default: `%ProgramData%\nbvpn` (override: `NBVPN_DATA_DIR`).

**ProgramData is a hidden folder.** If Explorer “cannot find” it:

```powershell
explorer C:\ProgramData\nbvpn
# or View → Hidden items in Explorer
dir $env:ProgramData\nbvpn\peers
```

Files after install: `server.json`, `nbvpn.conf`, `peers\<id>.nbvpn.json`, `.png`, `.conf`.

## Show / QR on Windows

| Command | Behavior |
|---------|----------|
| `nbvpn show` | URI + paths + **PNG path**; **no** terminal block QR |
| `nbvpn show --uri` | URI only |
| `nbvpn show --qr` | Terminal QR **opt-in**; still **clamped** (~48–56 cols); dense URIs → skip + recommend PNG |
| Open `.png` | Preferred for phone scan |

## Cross-compile — Docker (Mac)

```bash
./server/nbvpn/scripts/build-windows-docker.sh all
```

Local Setup.exe (Windows host with Inno Setup 6):

```powershell
# after placing exe + scripts in a stage folder:
.\server\install\windows\build-setup.ps1 -StageDir C:\stage
```

## Manual tunnel / service name

```powershell
wireguard.exe /installtunnelservice "$env:ProgramData\nbvpn\nbvpn.conf"
sc.exe query WireGuardTunnel`$nbvpn
# There is no Windows Service named "nbvpn". CLI: nbvpn status | start | stop
```

## Gaps vs Linux (honest)

1. **NAT on 2012**: no `New-NetNat` — use RRAS/ICS.
2. **WireGuard missing**: dry-run profiles only until WG is installed.
3. **arm64 Windows** not in MVP artifacts.

## Related

- Client Setup: `NetBridge-windows-setup.exe` (Flutter)
- Linux: `server/install/install.sh`
- CI: `.github/workflows/build-server.yml` → artifact `NetBridge-nbvpn-Setup.exe`
