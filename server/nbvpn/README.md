# nbvpn — NetBridge VPN server CLI

WireGuard-based self-hosted VPN node manager. Implements the frozen contract in
`docs/delivery/nbvpn/03-contract.md` (NbVpnProfile v1, `nbvpn:` URI, QR, CLI).

## Build

```bash
cd server/nbvpn
go test ./...
go build -o nbvpn .
```

### Release binaries (linux amd64 + arm64 + windows amd64)

```bash
./server/nbvpn/scripts/build-release.sh              # linux amd64 + arm64
./server/nbvpn/scripts/build-release.sh windows      # windows amd64 .exe
./server/nbvpn/scripts/build-release.sh amd64 arm64 windows
# → dist/nbvpn-linux-amd64{,.sha256}
# → dist/nbvpn-linux-arm64{,.sha256}
# → dist/nbvpn-windows-amd64.exe{,.sha256}
```

Copy to VPS or point `NBVPN_BINARY_URL` at the amd64/arm64 artifact. Verify:

```bash
sha256sum -c dist/nbvpn-linux-amd64.sha256
sha256sum -c dist/nbvpn-windows-amd64.exe.sha256
```

## Install (Linux)

As root on Debian / Ubuntu / CentOS / RHEL / Rocky / Alma:

```bash
sudo bash server/install/install.sh
```

The script installs `wireguard-tools`, places `nbvpn` in `/usr/local/bin`, then runs `nbvpn install`.

Or build locally and copy:

```bash
go build -o nbvpn .
sudo install -m 0755 nbvpn /usr/local/bin/nbvpn
sudo nbvpn install
```

## Install (Windows Server)

See **`server/install/windows/WINDOWS.md`**. Short path (Administrator PowerShell):

1. Install [WireGuard for Windows](https://www.wireguard.com/install/)
2. Place `nbvpn-windows-amd64.exe` or run from repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\server\install\windows\install.ps1
nbvpn show
```

Data dir default: `%ProgramData%\nbvpn`.
## Quick start

```bash
sudo nbvpn install          # keys, first peer, enable wg-quick@nbvpn when available
nbvpn show                  # URI + file + PNG path + terminal QR (secrets!)
nbvpn show --uri            # URI on stdout; secret warning on stderr (pipe-friendly)
nbvpn config                # node summary (no server private key)
nbvpn config set endpoint 203.0.113.10   # if public IP was not detected
nbvpn status
nbvpn peer add phone
nbvpn peer list
nbvpn peer revoke phone
sudo nbvpn start|stop|restart
sudo nbvpn uninstall --yes
```

Firewall: open **UDP 51820** on the host **and** the cloud security group. See `server/install/FIREWALL.md`.

## Commands

| Command | Purpose |
|---------|---------|
| `install` | Create interface config, first peer, detect endpoint, enable service |
| `show [--uri\|--qr\|--file\|--all]` | Connection info (default `--all`) |
| `config` | Node summary without server private key |
| `config set endpoint <host[:port]>` | Set public endpoint for profiles |
| `status` / `start` / `stop` / `restart` | Service management |
| `peer add [name]` / `list` / `revoke <id\|name>` | Client peers |
| `uninstall` | Stop service and remove data (confirm or `--yes`) |
| `help` | Help |

## State & secrets

- Default data dir: Linux `/var/lib/nbvpn`；Windows `%ProgramData%\nbvpn`（override with `NBVPN_DATA_DIR`）
- Fallback if unwritable: Linux `/usr/local/var/lib/nbvpn`；Windows `%LOCALAPPDATA%\nbvpn`
- Peer profiles: `<data>/peers/<id>.nbvpn.json`
- WG conf: `<data>/nbvpn.conf`；Linux also `/etc/wireguard/nbvpn.conf` when tools exist；Windows uses `wireguard.exe /installtunnelservice`
- **URI / QR / `.nbvpn.json` contain the client private key** — do not publish them
- `config` / `status` never print the server private key

## Dry-run (macOS / no WireGuard)

Without `wg-quick` (Linux) or WireGuard for Windows, `install` still generates keys and profiles. `start`/`stop`/`status`
report dry-run. Useful for developing profile/URI/QR export:

```bash
export NBVPN_DATA_DIR=/tmp/nbvpn-dev
./nbvpn install
./nbvpn show --uri
```

## Profile / URI / QR

```text
nbvpn:1?<base64url(JSON of NbVpnProfile v1)>
```

`nbvpn show` terminal QR and `peers/<id>.png` always encode that **full URI** (starts with `nbvpn:1?`). The numeric `peer id` in `peer list` / PNG filenames is only a local handle — not the QR content. Store page SHA256 digests are package checksums, also not QR payloads.

See `docs/delivery/nbvpn/03-contract.md`.

## Related apps (this monorepo)

| Piece | Path | How to run |
|-------|------|------------|
| Client (网桥 VPN) | `clients/netbridge/` (Flutter) | `cd clients/netbridge && flutter run -d <device>` |
| Server CLI | `server/nbvpn/` → `nbvpn` on VPS | `cd server/nbvpn && go build -o nbvpn .` then install; or `nbvpn show` on node |
| Store preview | `apps/store` | `cd apps/store && npm run dev` (or serve `dist/`) |
