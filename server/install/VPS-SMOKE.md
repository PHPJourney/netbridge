# VPS Smoke Checklist — nbvpn (S02)

> Aligns with `docs/dev-workflow/slices/S02-server-nbvpn/acceptance.md`.  
> Run on a clean **Linux** VPS (Debian / Ubuntu / RHEL / CentOS / Rocky / Alma).  
> This machine (macOS dry-run) cannot close AC-01 / AC-05 / SV-02.

## Preconditions

- [ ] Root / sudo SSH to VPS
- [ ] Outbound HTTPS (install + public IP detect)
- [ ] UDP **51820** (or chosen listen port) open in **cloud firewall + host firewall** — see `FIREWALL.md`
- [ ] Repo cloned **or** `NBVPN_BINARY_URL` pointing at a Linux `nbvpn` binary
  - Or copy `server/nbvpn/dist/nbvpn-linux-amd64` (from `scripts/build-release.sh`) onto the VPS

## One-shot install

```bash
# From repo root on the VPS (auto-detect distro → deb-family / rhel-family):
sudo ./server/install/install.sh

# Explicit family / distro:
#   sudo ./server/install/deb-family.sh   # Debian / Ubuntu
#   sudo ./server/install/debian.sh
#   sudo ./server/install/ubuntu.sh
#   sudo ./server/install/rhel-family.sh  # RHEL / CentOS / Rocky / Alma
#   sudo ./server/install/centos.sh
#   sudo ./server/install/rhel.sh

# Or with prebuilt binary:
# sudo NBVPN_BINARY_URL='https://…/nbvpn-linux-amd64' ./server/install/install.sh
```

Expect: WireGuard tools installed → **kernel can `modprobe wireguard`** → `nbvpn` on PATH → `nbvpn install` creates node + first peer.

**CentOS 8 note:** if journal shows `Unknown device type` / `Protocol not supported`, the kernel lacks WireGuard. Upgrade to `kernel >= 4.18.0-553.el8_10` then install `kmod-wireguard` (see `FIREWALL.md` §7). Do not use `--skip-broken`.

## One-command verify

```bash
sudo ./server/install/smoke-verify.sh
```

Expect: PASS (or PASS with skips only if dry-run / no terminal glyphs). FAIL blocks claiming S02.

## Manual S02 map

| Acceptance | Command / check | Pass when |
|------------|-----------------|-----------|
| AC-01 一键安装 | `install.sh` + `nbvpn status` | Interface up (not dry-run); connection info printed |
| AC-02 终端二维码 | `nbvpn show` | Half-block QR visible; **wide terminal** (≥100 cols) or use PNG |
| AC-03 URI + 文件 | `nbvpn show --uri` / `--file` | URI `nbvpn:1?…` on **stdout**; warning on stderr; `.nbvpn.json` under data dir |
| AC-04 config | `nbvpn config` | Endpoint/public key; **no** server private key |
| AC-05 服务管理 | `nbvpn stop` → `status` → `start` → `restart` | States match; errors readable |
| AC-06 傻瓜式 | Only docs + above | No hand-written WireGuard conf required |

## QR paths (terminal + PNG)

After `nbvpn show` / `peer add`:

| Artifact | Typical path | Notes |
|----------|--------------|--------|
| URI | stdout | Same payload as QR |
| Profile JSON | `/var/lib/nbvpn/peers/<id>.nbvpn.json` | mode 0600 |
| **QR PNG** | `/var/lib/nbvpn/peers/<id>.png` | mode 0600; **prefer for phone scan** if SSH wraps |
| Terminal QR | stdout ANSI half-blocks | Forced light bg / dark modules |

Fallback printed by CLI: use `--file`, `--uri`, or open the PNG.

```bash
# Copy PNG off-box for camera scan (example):
scp root@VPS:/var/lib/nbvpn/peers/*.png .
```

## Peer lifecycle

```bash
nbvpn peer add phone
nbvpn peer list
nbvpn show                 # exports for a peer
nbvpn peer revoke <id>     # removes .nbvpn.json + .png; old profile must not connect
```

## Client spot-check (after server PASS)

1. Import URI or scan **PNG** (not wrapped terminal) into 网桥 VPN.
2. Connect from at least one platform (Android first — real tunnel ready).
3. Confirm handshake / traffic; revoke peer and confirm old profile fails.

## Record evidence for QA

Paste into `docs/delivery/nbvpn/05-qa.md`:

- OS release (`cat /etc/os-release`)
- `smoke-verify.sh` full output
- `nbvpn config` / `status` (redact nothing sensitive beyond confirming no server private key)
- PNG path + whether phone scan succeeded

## Still blocked without this VPS

- DEF-03 / S02 AC-01 & AC-05 real wg  
- SV-02 four-distro matrix (repeat install per family)  
- Four-client E2E (S05 AC-01)
