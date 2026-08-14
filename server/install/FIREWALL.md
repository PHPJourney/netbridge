# Firewall & endpoint — nbvpn

WireGuard listens on **UDP** (default **51820**). Clients cannot handshake until both layers allow that port.

## 1. Host firewall (on the VPS)

### ufw (Debian / Ubuntu)

```bash
sudo ufw allow 51820/udp comment 'nbvpn WireGuard'
sudo ufw reload
sudo ufw status | grep 51820
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
- Opening only TCP 22/80/443 is **not** enough for WireGuard.

If `nbvpn status` shows the interface up but phones never get a handshake, check the **cloud** panel first.

## 3. Public endpoint

Client profiles embed `server.endpoint` (host:port). After install, verify:

```bash
nbvpn config          # look at endpoint:
nbvpn show --uri      # URI must contain that host:port (warning goes to stderr)
```

If public IP detection failed or you use a DNS name / floating IP:

```bash
sudo nbvpn config set endpoint YOUR_PUBLIC_IP_OR_DNS
# optional explicit port:
sudo nbvpn config set endpoint vpn.example.com:51820
nbvpn show            # re-export URI / QR / JSON for peers
```

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

- Prefer **QR PNG** (`/var/lib/nbvpn/peers/<id>.png`) over terminal QR when SSH columns wrap.
- `nbvpn show --uri` is pipe-friendly: only the URI is on stdout; the secret warning is on stderr.
- Never commit URIs, peer JSON, or VPS passwords into git.

See also: `VPS-SMOKE.md`, `server/nbvpn/README.md`.
