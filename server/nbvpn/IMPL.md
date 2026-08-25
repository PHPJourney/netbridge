# Backend implementation notes — nbvpn CLI

> Merge into `docs/delivery/nbvpn/04-impl-notes.md` § Backend.

## Module

- Path: `github.com/netbridge/nbvpn` (`server/nbvpn/`)
- Language: Go 1.22+
- Deps: `golang.zx2c4.com/wireguard/wgctrl/wgtypes`, `github.com/skip2/go-qrcode`

## Layout

| Path | Role |
|------|------|
| `server/nbvpn/` | CLI binary (`nbvpn`) |
| `server/nbvpn/internal/profile` | NbVpnProfile v1, URI encode/decode, `.conf` export |
| `server/nbvpn/internal/state` | 平台数据目录 persistence（`NBVPN_DATA_DIR`） |
| `server/nbvpn/internal/wg` | Keygen；Linux wg-quick/systemd；Windows wireguard.exe；dry-run |
| `server/nbvpn/internal/qr` | Terminal half-block QR (ANSI dark-on-light) + optional PNG of full URI |
| `server/nbvpn/internal/endpoint` | Public IP detect + endpoint normalize |
| `server/nbvpn/internal/cli` | Command surface |
| `server/install/install.sh` | Debian/Ubuntu/RHEL/CentOS bootstrap |
| `server/install/windows/` | Windows Server MVP（`install.ps1` + `WINDOWS.md`） |
| `server/install/smoke-verify.sh` | Post-install one-command checks (S02-oriented) |
| `server/install/VPS-SMOKE.md` | Human checklist + QR PNG / terminal paths |

## Data paths

- Default: Linux `/var/lib/nbvpn/`；Windows `%ProgramData%\nbvpn\`
- Fallback: Linux `/usr/local/var/lib/nbvpn/`；Windows `%LOCALAPPDATA%\nbvpn\`
- Override: `NBVPN_DATA_DIR`
- Server state: `server.json` (contains server private key — mode 0600)
- Peers: `peers/<id>.json` + `peers/<id>.nbvpn.json` + `peers/<id>.png` (QR of full URI, mode 0600)
- WG: `nbvpn.conf`；Linux → `/etc/wireguard/nbvpn.conf`；Windows → `wireguard.exe /installtunnelservice`

## CLI notes

- `config set endpoint <host[:port]>` implemented (default port = listenPort, usually 51820); refreshes peer JSON + PNG + `.conf`
- `config set endpoint-v6 <[ipv6]|host[:port]>` stores optional IPv6 endpoint and sets `ipv6Enabled=on`; refreshes peer exports
- `config set ipv6 on|off` toggles prefer-IPv6 without clearing `endpointV6` (on requires endpoint-v6 set)
- `config` / `status` show endpoint, endpointV6, ipv6Enabled
- Profile optional fields `endpointV6` / `ipv6Enabled` (omitempty); WireGuard conf uses ActiveEndpoint (single Endpoint)
- `show` prints secret warning; never prints server private key in `config`/`status`
- `show` writes terminal QR (half-block + forced light bg) and PNG beside the profile; prints fallback to `--file`/`--uri`/PNG if terminal scan fails; labels that QR payload = full `nbvpn:1?` URI (not numeric peer id / PNG filename)
- `peer revoke` marks revoked, removes export JSON + PNG, rewrites WG peers so old profiles fail
- `peer delete` removes peer metadata and all export files; rewrites WG peers; IP not recycled

## Terminal QR limitations

- Payload is always the full `nbvpn:1?<base64url>` URI (contract-valid); do not shorten the URI for density
- Half-block packing (`█▀▄`) keeps modules roughly square on typical ~2:1 terminal cells
- Width budget: `COLUMNS` / TTY size / `--qr-size N` via `EffectiveMaxCols` (default 120 when undetectable) — **not** a hard 48–56 clamp
- `--all` / `--qr` always print terminal QR unless `NBVPN_NO_TERMINAL_QR=1`; PNG is supplemental
- ANSI forces white background / near-black foreground so dark themes do not invert modules (Windows: ANSI off unless `NBVPN_FORCE_ANSI=1` / `FORCE_COLOR`)
- Real profiles ~73–89 modules after compact ECC — **very narrow SSH may still wrap**; widen terminal, `--qr-size`, or use optional PNG / `--file` / `--uri`
- Terminal encode uses Medium ECC (smaller matrix); PNG uses High (more robust for camera)
- win2012 GUI (`nbvpn-gui-win2012`): renders character QR in the text pane (does not auto-open Photos)

## Dry-run

On macOS, Linux without `wg-quick`, or Windows without WireGuard for Windows, install/show/peer still work; service ops print dry-run messages.

## Build / test / VPS smoke

```bash
cd server/nbvpn
go test ./...
go build -o nbvpn .

# Cross-compile release artifacts:
./scripts/build-release.sh amd64 arm64 windows
# → dist/nbvpn-linux-{amd64,arm64}{,.sha256}
# → dist/nbvpn-windows-amd64.exe{,.sha256}

# On Linux VPS (after clone or binary install):
sudo ./server/install/install.sh   # prefers dist/ binary matching host arch
sudo ./server/install/smoke-verify.sh
# Firewall / endpoint: server/install/FIREWALL.md
# Full checklist: server/install/VPS-SMOKE.md

# On Windows Server (elevated):
#   powershell -ExecutionPolicy Bypass -File .\server\install\windows\install.ps1
#   Docs: server/install/windows/WINDOWS.md
```

## Known limits

- Public IP detection uses HTTPS echo services; may fail behind strict egress — use `config set endpoint`
- IPv6 allowedIPs always included in default profiles; operators can later tighten via state edits (no CLI yet)
- `show --uri` / `--file` / `--qr` put the secret warning on **stderr** so stdout stays pipeable
- **Windows NAT**: `New-NetNat` may require Hyper-V/supported SKU; otherwise RRAS/ICS — not Linux iptables parity
