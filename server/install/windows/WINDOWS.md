# Windows Server — nbvpn MVP

NetBridge VPN **node** on Windows Server (or Windows 10/11 lab). Linux install path is unchanged (`server/install/install.sh`).

## What works (MVP)

| Capability | Status |
|------------|--------|
| Cross-compile `nbvpn-windows-amd64.exe` (Win10+) | Yes (host Go or Docker) |
| Cross-compile `nbvpn-windows-amd64-win2012.exe` (Server 2012 R2) | Yes (**Go 1.20** / Docker `golang:1.20.14`) |
| `nbvpn install` / `show` (URI + terminal QR + `.nbvpn.json` + PNG) | Yes |
| `peer add` / `list` / `revoke`, `config`, `status` | Yes |
| Tunnel via **WireGuard for Windows** (`wireguard.exe` + Wintun) | Yes when WireGuard is installed (newer Windows) |
| Host firewall UDP **51820** | `install.ps1` creates rule |
| IPv4 forwarding | `install.ps1` + conf `PostUp` |
| Client internet (NAT) | Best-effort `New-NetNat`; else RRAS/ICS (see gaps) |

## Which binary?

| Target OS | Artifact | Build toolchain |
|-----------|----------|-----------------|
| **Server 2012 / 2012 R2** | `nbvpn-windows-amd64-win2012.exe` | **Go ≤ 1.20** (Go 1.21+ dropped 7/8/2012) |
| **Windows 10/11, Server 2016+** | `nbvpn-windows-amd64.exe` | Go 1.22+ (current repo default) |

**Flutter NetBridge client** is a separate app: it needs **Windows 10+** and cannot run as a desktop client on Server 2012. See `clients/netbridge/dist/WINDOWS-BUILD.md`.

## Prerequisites

1. **Windows Server 2019 / 2022** (x64) recommended for production nodes; elevated PowerShell.
2. Install **[WireGuard for Windows](https://www.wireguard.com/install/)** (provides `wireguard.exe`, `wg.exe`, Wintun).
3. Public IP / DNS reachable; **cloud security group** allows inbound **UDP 51820**.

### Server 2012 / 2012 R2 (lab)

- OS is **out of support**; official WireGuard for Windows / Wintun targets newer Windows.
- Binaries built with **Go 1.21+** fail with 「此应用无法在你的电脑上运行」 — use the **win2012** artifact only.
- Prefer **2019/2022** for production. On 2012, `nbvpn install` / `show` may still run for keys/URI/QR; full tunnel + NAT **not guaranteed**.

## Install (elevated PowerShell)

### Deploy folder (typical for 2012 lab)

```powershell
# On the Windows host, create a folder and copy:
#   install.ps1
#   nbvpn-windows-amd64-win2012.exe   # or nbvpn-windows-amd64.exe on Win10+
mkdir C:\NetBridge\deploy -Force
# copy files into C:\NetBridge\deploy\ then:
cd C:\NetBridge\deploy
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` is PowerShell **4**-safe (Server 2012 R2). It looks for:

1. `nbvpn-windows-amd64-win2012.exe` / `nbvpn-windows-amd64.exe` next to the script
2. `C:\NetBridge\deploy\…` and `C:\ProgramData\NetBridge\…`
3. Repo `server\nbvpn\dist\…` when run from a full clone
4. `-BinaryUrl` / `$env:NBVPN_BINARY_URL`

Or with a prebuilt binary URL:

```powershell
$env:NBVPN_BINARY_URL = 'http://…/store/…/nbvpn-windows-amd64-win2012.exe'
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script:

1. Copies `nbvpn.exe` to `C:\Program Files\NetBridge` (and adds to PATH)
2. Enables IPv4 forwarding; tries `New-NetNat` for `10.8.0.0/24` (skipped if unavailable)
3. Opens Windows Firewall UDP 51820
4. Runs `nbvpn install` (unless `-SkipInstall` / `NBVPN_SKIP_INSTALL=1`)

Then:

```powershell
nbvpn show          # URI + QR + profile (secrets!)
nbvpn show --uri
nbvpn status
nbvpn peer add phone
```

Default data dir: `%ProgramData%\nbvpn` (override with `NBVPN_DATA_DIR`).

## Cross-compile — Docker (recommended on Mac)

Pinned Go images avoid host toolchain drift:

```bash
# both artifacts
./server/nbvpn/scripts/build-windows-docker.sh all

# Server 2012 R2 only (golang:1.20.14)
./server/nbvpn/scripts/build-windows-docker.sh win2012
# → server/nbvpn/dist/nbvpn-windows-amd64-win2012.exe

# Win10 / Server 2016+ (golang:1.22.10)
./server/nbvpn/scripts/build-windows-docker.sh win10
# → server/nbvpn/dist/nbvpn-windows-amd64.exe
```

Equivalent one-liners:

```bash
# win2012
docker run --rm -v "$PWD:/src" -w /src/server/nbvpn golang:1.20.14 \
  bash -c "sed -i 's/^go .*/go 1.20/' go.mod; sed -i '/^toolchain /d' go.mod; \
    GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o dist/nbvpn-windows-amd64-win2012.exe ."

# win10+
docker run --rm -v "$PWD:/src" -w /src/server/nbvpn golang:1.22.10 \
  bash -c 'GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o dist/nbvpn-windows-amd64.exe .'
```

> Prefer the script: it builds in `/tmp` so the host `go.mod` (`go 1.22`) is not rewritten on disk.

## Cross-compile — host Go / release script

```bash
cd server/nbvpn
./scripts/build-release.sh windows          # modern (host Go)
./scripts/build-release.sh windows-2012     # GOTOOLCHAIN=go1.20.14
# → dist/nbvpn-windows-amd64.exe / dist/nbvpn-windows-amd64-win2012.exe
```

## Manual tunnel (if script skipped service)

```powershell
# After nbvpn install wrote %ProgramData%\nbvpn\nbvpn.conf
wireguard.exe /installtunnelservice "$env:ProgramData\nbvpn\nbvpn.conf"
sc.exe query WireGuardTunnel`$nbvpn
nbvpn show
```

Uninstall tunnel / data:

```powershell
nbvpn uninstall --yes
# or: wireguard.exe /uninstalltunnelservice nbvpn
```

## Gaps vs Linux parity (honest)

1. **NAT**: `New-NetNat` needs a supported SKU (often Hyper-V present; usually **not** on 2012). If it fails, clients may **connect but have no internet** until you enable **RRAS NAT** or **ICS**.
2. **No systemd / wg-quick**: service is `WireGuardTunnel$nbvpn` via `wireguard.exe`.
3. **No chocolatey/MSI packaging yet** — PowerShell + `.exe` only.
4. **Not fully E2E tested** on every Windows Server SKU in CI.
5. **arm64 Windows** not in MVP release artifacts (amd64 only).
6. Profile / URI / QR are the same contract as Linux — client apps do not care which OS runs the node.

## Related

- Linux: `server/install/install.sh`, `FIREWALL.md`
- CLI: `server/nbvpn/README.md`
- Contract: `docs/delivery/nbvpn/03-contract.md`
- Client Windows: `clients/netbridge/dist/WINDOWS-BUILD.md` (**Win10+ only**)


## CI artifact (GitHub Actions)

Workflow: `.github/workflows/build-server.yml`

| Artifact | Go | Target |
|----------|-----|--------|
| `nbvpn-windows-amd64-win2012.exe` | **1.20** | Server 2012 / 2012 R2 |
| `nbvpn-windows-amd64.exe` | 1.22+ | Win10+ / Server 2016+ |

Download from the workflow run **Artifacts** or from a GitHub **Release** after tagging `v*`. Bundle zip also includes `server/install/windows/install.ps1` + this doc.

```powershell
# Example after copying win2012 exe + install.ps1 to the 2012 host:
cd C:\NetBridge\deploy
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Flutter **client** is not built for / does not run on Server 2012.

