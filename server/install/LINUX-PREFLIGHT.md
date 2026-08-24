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
   - On **CentOS 8 / Stream**: **first** backup `/etc/yum.repos.d`, rewrite toward **vault.centos.org**, including cloud-vendor overlays (`*aliyun*`, `*mirrors*`, …), disable metalink/mirrorlist, then **print / verify** effective BaseOS/AppStream baseurls (must not stay on frozen Aliyun/CDN trees)
   - `dnf`/`yum` update `kernel` / `kernel-core` / `kernel-modules`
   - If vault switch still leaves stale mirrors, or update is still a no-op while running kernel **&lt; `4.18.0-553`** → **fast fail** with Rocky/Alma migrate steps (no second empty yum loop)
   - Install `elrepo-release` + `kmod-wireguard` (no `--skip-broken`; no historical Stream kABI guesswork)
   - If newer kernel installed but not running → **exit, ask for reboot**, re-run installer
3. `ensure_wireguard_kernel` — hard fail with migrate guidance if still missing
4. `nbvpn` binary → `configure_host_firewall` (firewalld when active)

### Why `yum update kernel` often says “Nothing to do”

On **CentOS Stream 8** (EOL), default metalink/mirror trees and **cloud images** (Aliyun, Tencent, Huawei, …) often no longer publish newer kernels. A kernel such as `4.18.0-408.el8` stays put; ELRepo `kmod-wireguard` typically needs **≥ `4.18.0-553.el8_10`**.

`vault.centos.org/centos/8-stream/` still carries later Stream 8 kernels (including `4.18.0-553.*`) **if** dnf actually uses vault. If cloud repo overlays keep winning, metadata looks “OK” while updates stay frozen — the installer treats that as **unhealable** and tells you to migrate.

Do **not** rely on old ELRepo kmods for arbitrary Stream kernels (kABI mismatch is common). Prefer Rocky/Alma.

### CentOS vault URLs (Stream 8)

| Repo | baseurl |
| --- | --- |
| BaseOS | `https://vault.centos.org/centos/8-stream/BaseOS/$basearch/os/` |
| AppStream | `https://vault.centos.org/centos/8-stream/AppStream/$basearch/os/` |
| extras | `https://vault.centos.org/centos/8-stream/extras/$basearch/os/` |
| Rocky mirror of vault | `https://dl.rockylinux.org/vault/centos/8-stream/...` |

After rewrite, check:

```bash
dnf repolist -v | grep -E 'Repo-id|Repo-baseurl|Repo-status'
# BaseOS/AppStream must show vault.centos.org (or dl.rockylinux.org/vault/centos),
# NOT mirrors.aliyun.com / other frozen CDNs
```

### Migrate to Rocky Linux 8 (shortest path)

When the installer says the current mirror has no usable kernel upgrade:

```bash
# Repos should already point at vault (installer backs up yum.repos.d).
# If migrate2rocky still complains about mirrors, set BaseOS/AppStream to vault
# URLs above (or Rocky's vault mirror), then:

curl -fLO https://raw.githubusercontent.com/rocky-linux/rocky-tools/main/migrate2rocky/migrate2rocky.sh
chmod +x migrate2rocky.sh
sudo ./migrate2rocky.sh -r
sudo reboot

# after reboot:
curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/install.sh | sudo bash
```

AlmaLinux 8/9 via `almalinux-deploy` is an equivalent path.

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
