# Firewall & endpoint — nbvpn

WireGuard listens on **UDP** (default **51820**). Clients cannot handshake until both layers allow that port.

## 1. Host firewall (on the VPS)

Linux install scripts (`deb-family.sh`, `rhel-family.sh`, `install.sh`) **automatically**:

- `ufw allow <listenPort>/udp` (when `ufw` is installed)
- `firewall-cmd --permanent --add-port=<listenPort>/udp` (when `firewalld` is running)
- Set `DEFAULT_FORWARD_POLICY=ACCEPT` in `/etc/default/ufw` when ufw is present

Skip with `NBVPN_SKIP_FIREWALL=1`. Override port with `NBVPN_LISTEN_PORT=51820`.

Manual commands if needed:

```bash
sudo ufw allow 51820/udp comment 'nbvpn WireGuard'
sudo ufw reload
sudo ufw status | grep 51820
```

`ufw allow 51820/udp` typically opens the port for **both IPv4 and IPv6** when the host has IPv6 enabled. Verify with `sudo ufw status verbose` (look for `51820/udp` under IPv6 / `Anywhere (v6)`).

If you use raw **ip6tables** instead of ufw:

```bash
sudo ip6tables -I INPUT -p udp --dport 51820 -j ACCEPT
```

### firewalld (RHEL / Rocky / Alma / CentOS)

```bash
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

### iptables (legacy)

```bash
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT
# persist per your distro (iptables-persistent / netfilter-persistent)
```

### Windows Firewall (Windows Server)

`server/install/windows/install.ps1` creates rule **NetBridge nbvpn UDP 51820**. Manual:

```powershell
New-NetFirewallRule -DisplayName "NetBridge nbvpn UDP 51820" `
  -Direction Inbound -Protocol UDP -LocalPort 51820 -Action Allow
```

See also `server/install/windows/WINDOWS.md` (forwarding / NetNat / RRAS).

## 2. Cloud security group / ACL

Many providers (阿里云 / AWS / GCP / 腾讯云 / …) filter **before** the host firewall.

- Inbound rule: **UDP 51820** from the clients you expect (`0.0.0.0/0` for public self-hosted, or tighter CIDRs).
- **IPv6 clients:** also allow **UDP 51820** for IPv6 (`::/0` or your IPv6 CIDRs) in the cloud security group / ACL. Some panels have a separate IPv6 rule set.
- Opening only TCP 22/80/443 is **not** enough for WireGuard.

If `nbvpn status` shows the interface up but phones never get a handshake, check the **cloud** panel first.

## 3. Public endpoint

Client profiles embed `server.endpoint` (host:port). Optional dual-stack fields: `server.endpointV6` + `server.ipv6Enabled`. After install, verify:

```bash
nbvpn config          # endpoint / endpointV6 / ipv6Enabled
nbvpn show --uri      # URI must contain that host:port (warning goes to stderr)
```

If public IP detection failed or you use a DNS name / floating IP:

```bash
sudo nbvpn config set endpoint YOUR_PUBLIC_IP_OR_DNS
# optional explicit port:
sudo nbvpn config set endpoint vpn.example.com:51820
```

### Dual IP / IPv6

WireGuard listens dual-stack by default on Linux (`ListenPort` accepts IPv4 + IPv6). Profiles still carry **one active Endpoint** at connect time:

```bash
# Primary (usually IPv4) — also use this to switch among multiple IPv4 addresses
sudo nbvpn config set endpoint 203.0.113.10

# Optional IPv6 (auto-enables ipv6Enabled=on)
sudo nbvpn config set endpoint-v6 2001:db8::1
# or: sudo nbvpn config set endpoint-v6 '[2001:db8::1]:51820'

# Toggle without clearing the stored IPv6 address
sudo nbvpn config set ipv6 on
sudo nbvpn config set ipv6 off

nbvpn show            # re-export URI / QR / JSON for peers
```

- Second **IPv4**: change the primary with `config set endpoint` (no separate `endpoint-v4-2` field).
- Client: when `ipv6Enabled` and `endpointV6` are present, connect uses the IPv6 endpoint; otherwise the primary.

NAT / CGNAT: the VPS must have a **reachable** UDP address; home CGNAT often cannot host inbound WireGuard without a relay (out of scope for nbvpn).

## 4. IP forwarding + NAT (required for client internet)

UDP 51820 open only lets clients **handshake**. Full-tunnel internet needs the VPS to **forward and MASQUERADE** traffic from `10.8.0.0/24`.

`nbvpn` writes this into `/etc/wireguard/nbvpn.conf` as `PostUp` / `PostDown`, and drops `net.ipv4.ip_forward=1` in `/etc/sysctl.d/99-nbvpn-forward.conf`.

If **ufw** is enabled, also allow routed traffic (otherwise FORWARD stays DROP):

```bash
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw reload
```

Verify:

```bash
sysctl net.ipv4.ip_forward                    # = 1
sudo iptables -t nat -L POSTROUTING -n -v     # MASQUERADE for 10.8.0.0/24
sudo wg show                                  # handshake + growing rx/tx
```

Symptom mapping: phone shows VPN key + traffic counters but no usable internet → almost always this section (not the APK).

## 5. Quick connectivity checklist

| Check | Expect |
|-------|--------|
| `nbvpn status` | `service: active`, `interface: nbvpn (up)` |
| Host firewall | UDP 51820 ALLOW |
| Cloud SG | UDP 51820 inbound |
| `ip_forward` + MASQUERADE | See §4 |
| `endpoint` | Real public IP or DNS, not empty / not `0.0.0.0` |
| Client import | Fresh URI after any `config set endpoint` |

## 6. Peer UX (operators)

```bash
nbvpn peer add phone     # prints URI + QR + file (secrets!)
nbvpn peer list          # active vs revoked
nbvpn show phone         # re-export one peer
nbvpn peer revoke phone  # removes export files; old profiles stop working
```

- Terminal half-block QR is primary; if SSH columns wrap, widen the session, use `nbvpn show --qr-size N`, or open the optional **QR PNG** (`/var/lib/nbvpn/peers/<id>.png`).
- `nbvpn show --uri` is pipe-friendly: only the URI is on stdout; the secret warning is on stderr.
- Never commit URIs, peer JSON, or VPS passwords into git.

See also: `VPS-SMOKE.md`, `server/nbvpn/README.md`.

## 7. CentOS 8 / RHEL 8 — `Unknown device type` (missing WireGuard module)

**Symptom:** `nbvpn status` shows `systemd: failed`, `interface: nbvpn (down)`; journal has:

```text
ip link add nbvpn type wireguard
Error: Unknown device type.
Unable to access interface: Protocol not supported
```

`lsmod | grep wireguard` is empty. This is **not** an nbvpn config bug — the running kernel has no WireGuard module.

### Diagnose

```bash
uname -r
lsmod | grep wireguard
sudo modprobe wireguard
# Module not found / Protocol not supported → need kmod or newer kernel
rpm -q wireguard-tools kmod-wireguard 2>/dev/null || true
systemctl status wg-quick@nbvpn --no-pager
journalctl -u wg-quick@nbvpn -n 50 --no-pager
command -v nbvpn; ls -la /usr/local/bin/nbvpn
```

### Fix (recommended order)

**1. Same host — upgrade kernel to el8_10 (≥ `4.18.0-553.el8_10`), then install `kmod-wireguard`**

CentOS 8 / Stream is EOL; the installer rewrites repos to **vault.centos.org** and must displace cloud mirrors (Aliyun etc.). `kmod-wireguard` from elrepo often requires `kernel >= 4.18.0-553.el8_10` — an older kernel (e.g. `4.18.0-408.el8`) **cannot** load that kmod. Do **not** use `--skip-broken`. If vault still has no ≥553 kernel (or cloud overlays keep winning), migrate to Rocky/Alma (`LINUX-PREFLIGHT.md`).

```bash
# Confirm BaseOS/AppStream use vault (not mirrors.aliyun.com), then:
sudo dnf install -y kernel kernel-core kernel-modules   # aim for ≥ 4.18.0-553.el8_10
# or on yum-only hosts:
# sudo yum update -y kernel kernel-core kernel-modules

sudo reboot
# after reboot:
uname -r   # must be ≥ 4.18.0-553.el8_10 (or a kernel that ships WG)

sudo yum install -y epel-release elrepo-release
sudo yum install -y kmod-wireguard wireguard-tools
# or: sudo dnf install -y elrepo-release kmod-wireguard wireguard-tools

sudo modprobe wireguard
lsmod | grep wireguard

sudo systemctl restart wg-quick@nbvpn
nbvpn status
```

**2. Or migrate** to Rocky Linux 8 / AlmaLinux 8 (or newer) with a current kernel, then re-run `server/install/centos.sh` / `rhel-family.sh`. Shortest Rocky path: `migrate2rocky.sh -r` (see `LINUX-PREFLIGHT.md`).

**3. Do not** pretend success with tools-only install — without a loadable module, `wg-quick@nbvpn` will keep failing.

### Installer preflight (automatic — all Linux one-liners)

`install.sh`, `debian.sh` / `ubuntu.sh`, and `centos.sh` / `rhel.sh` all call shared `preflight_linux` (`_common.sh`), then family remediation:

- **Debian/Ubuntu:** apt `wireguard` / tools / `wireguard-dkms` + headers when `modprobe` fails; newer kernel package vs running `uname -r` is informational when WireGuard already works
- **RHEL/Rocky/Alma/CentOS/Stream:** epel/elrepo, kernel update, CentOS EOL vault switch (incl. cloud overlays), `kmod-wireguard`, reboot prompt / migrate fail
- Host firewall via `configure_host_firewall` (ufw / firewalld)
- Fail with actionable steps instead of a fake success

If download fails with `curl: (22) …/nbvpn-linux-amd64` **404**, the **filename is correct** but GitHub `releases/latest` is a client-only Release (no server binary). Workaround: `NBVPN_BINARY_URL=…/releases/download/v0.1.11/nbvpn-linux-amd64` — see `LINUX-PREFLIGHT.md` § Binary download.

Full write-up: **`LINUX-PREFLIGHT.md`**.

## 8. Uninstall (full clean)

`nbvpn uninstall` removes **all** nbvpn-managed host artifacts (not a partial uninstall that leaves system config behind):

```bash
sudo nbvpn uninstall              # preview + type yes
sudo nbvpn uninstall --yes        # full clean (default)
sudo nbvpn uninstall --yes --keep-data   # keep /var/lib/nbvpn for reinstall
```

Removed on Linux:

| Artifact | Notes |
|----------|--------|
| `wg-quick@nbvpn` | stop + `systemctl disable` |
| `/etc/wireguard/nbvpn.conf` | system WireGuard config |
| `/var/lib/nbvpn` (or `NBVPN_DATA_DIR`) | keys, peers, profiles — skipped with `--keep-data` |
| `/etc/sysctl.d/99-nbvpn-forward.conf` | only if file contains `# Managed by nbvpn` |
| iptables FORWARD + MASQUERADE | PostDown + best-effort duplicate cleanup |

`nbvpn` does **not** revert ufw `DEFAULT_FORWARD_POLICY` changes you made manually (see §4).

