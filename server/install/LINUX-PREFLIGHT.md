# Linux install preflight / environment remediation

**All** Linux one-liner entry points run environment assessment and adaptation before finishing `nbvpn` install:

| Entry | Path |
| --- | --- |
| `install.sh` | `preflight_linux` → dispatch → `deb-family.sh` or `rhel-family.sh` |
| `debian.sh` / `ubuntu.sh` | `_bootstrap.sh` → `deb-family.sh` → `preflight_linux` + apt remediation |
| `centos.sh` / `rhel.sh` | `_bootstrap.sh` → `rhel-family.sh` → `preflight_linux` + dnf/yum remediation |
| `curl \| bash` | Same as above (bootstrap fetches `_common.sh` + family scripts) |

Shared helpers live in `_common.sh`: `preflight_linux`, `wireguard_kernel_ok`, `ensure_wireguard_kernel` / `require_wireguard_kernel`, `configure_host_firewall`.

Goal: make the host able to load WireGuard, install tools + `/usr/local/bin/nbvpn`, configure host firewall. If that cannot be achieved, scripts **exit non-zero** with copy-paste next steps (no fake success).

See also: `FIREWALL.md` §7.

## What `preflight_linux` probes

| Check | Why |
| --- | --- |
| Root (`EUID=0`) | Package + module install |
| Arch (`x86_64` / `aarch64`) | Binary selection |
| `/etc/os-release` | Debian/Ubuntu vs RHEL/CentOS Stream/Rocky/Alma |
| Package manager (`apt` / `dnf` / `yum`) | Correct install path |
| `systemd` | Service enable/start |
| `curl` / `ip` / `modprobe` | Download binary, create links, load modules |
| `uname -r` | Match kmod/dkms to running kernel |
| `modprobe wireguard` / `ip link add … type wireguard` | Real kernel capability |
| `wg` / `wg-quick` | Userspace tools (may be installed next) |

## Adaptation by family

### Debian / Ubuntu (`deb-family.sh`)

1. `apt-get update` + install `wireguard` / `wireguard-tools` / `curl` / `iproute2`
2. If `modprobe wireguard` still fails → `linux-headers-$(uname -r)` + `wireguard-dkms` + `dkms autoinstall`
3. Re-probe via `ensure_wireguard_kernel` — hard fail with apt copy-paste if still missing
4. `nbvpn` binary → `configure_host_firewall` (ufw)

### RHEL / Rocky / Alma / CentOS / CentOS Stream (`rhel-family.sh`)

1. Install `wireguard-tools` (+ `epel-release` as needed)
2. If kmod missing:
   - `dnf`/`yum` update `kernel` / `kernel-core` / `kernel-modules`
   - On **CentOS 8 / Stream**: if update is a no-op or mirrors dead → **backup** `/etc/yum.repos.d`, switch toward **vault.centos.org**, retry
   - Install `elrepo-release` + `kmod-wireguard` (no `--skip-broken`)
   - If newer kernel installed but not running → **exit, ask for reboot**, re-run installer
3. `ensure_wireguard_kernel` — hard fail with Rocky/Alma migrate guidance if still missing
4. `nbvpn` binary → `configure_host_firewall` (firewalld when active)

### Why `yum update kernel` often says “Nothing to do”

On **CentOS Stream 8** (EOL), default metalink/mirror trees often no longer publish newer kernels. A kernel such as `4.18.0-408.el8` stays put; ELRepo `kmod-wireguard` typically needs **≥ `4.18.0-553.el8_10`**. Vault may still have packages; if not, migrate to Rocky/Alma 8/9.

## Repo backup / restore (CentOS only)

```text
/etc/yum.repos.d  →  /etc/yum.repos.d.nbvpn-backup.<timestamp>
```

```bash
sudo rm -rf /etc/yum.repos.d
sudo mv /etc/yum.repos.d.nbvpn-backup.YYYYMMDDHHMMSS /etc/yum.repos.d
sudo dnf clean all   # or yum clean all
```

## After success

- Binary: `/usr/local/bin/nbvpn` (`PATH` includes `/usr/local/bin`)
- Host firewall: ufw and/or firewalld — see `FIREWALL.md`
- Cloud security groups still must allow UDP listen port manually

## Skip flags

| Env | Effect |
| --- | --- |
| `NBVPN_SKIP_PREFLIGHT_REPOS=1` | Do not rewrite CentOS yum/dnf repos to vault |
| `NBVPN_SKIP_KERNEL_UPDATE=1` | Do not attempt kernel package updates (RHEL family) |
| `NBVPN_SKIP_FIREWALL=1` | Skip host firewall rules |
| `NBVPN_SKIP_INSTALL=1` | Install binary/tools only; skip `nbvpn install` |
