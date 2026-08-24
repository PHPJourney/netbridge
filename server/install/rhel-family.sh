#!/usr/bin/env bash
# NetBridge VPN — RHEL / CentOS / Rocky / Alma family installer (dnf/yum + WireGuard).
#
# Usage (as root):
#   sudo ./server/install/rhel-family.sh
#   sudo ./server/install/centos.sh
#   sudo ./server/install/rhel.sh
#
# Env: NBVPN_VERSION, NBVPN_BINARY_URL, INSTALL_BIN_DIR, NBVPN_SKIP_INSTALL, NBVPN_DATA_DIR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "${SCRIPT_DIR}/_common.sh"

# Probe whether the running kernel can create a WireGuard interface.
wireguard_kernel_ok() {
  if lsmod 2>/dev/null | grep -q '^wireguard'; then
    return 0
  fi
  if modprobe wireguard 2>/dev/null; then
    return 0
  fi
  # Some kernels ship WG built-in (no module); try a throwaway link.
  if command -v ip >/dev/null 2>&1; then
    local tmp="nbvpnprobe$$"
    if ip link add "${tmp}" type wireguard 2>/dev/null; then
      ip link del "${tmp}" 2>/dev/null || true
      return 0
    fi
    ip link del "${tmp}" 2>/dev/null || true
  fi
  return 1
}

ensure_elrepo_kmod() {
  # CentOS/RHEL 8 often ship wireguard-tools without a kernel module.
  local major=""
  major="${OS_VERSION%%.*}"
  case "${OS_ID}" in
    centos|rhel|rocky|almalinux)
      if [[ "${major}" == "8" || "${major}" == "7" ]]; then
        log "EL${major}: ensuring elrepo / kmod-wireguard (kernel module required)"
        if command -v dnf >/dev/null 2>&1; then
          dnf install -y epel-release || true
          dnf install -y elrepo-release || \
            dnf install -y https://www.elrepo.org/elrepo-release-${major}.el${major}.elrepo.noarch.rpm || true
          dnf install -y kmod-wireguard || \
            dnf install -y --enablerepo=elrepo kmod-wireguard || true
        else
          yum install -y epel-release || true
          yum install -y elrepo-release || \
            yum install -y https://www.elrepo.org/elrepo-release-${major}.el${major}.elrepo.noarch.rpm || true
          yum install -y kmod-wireguard || \
            yum install -y --enablerepo=elrepo kmod-wireguard || true
        fi
      fi
      ;;
  esac
}

install_wireguard_rhel() {
  log "installing WireGuard (dnf/yum)"
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y epel-release || true
    dnf install -y wireguard-tools curl ca-certificates iproute || \
      dnf install -y wireguard-tools kmod-wireguard curl ca-certificates iproute || true
  else
    yum install -y epel-release || true
    yum install -y wireguard-tools curl ca-certificates iproute || \
      yum install -y wireguard-tools kmod-wireguard curl ca-certificates iproute || true
  fi
  if ! command -v wg-quick >/dev/null 2>&1; then
    err "wireguard-tools not available from repos; install manually then re-run"
  fi

  ensure_elrepo_kmod

  if wireguard_kernel_ok; then
    log "WireGuard kernel support OK (modprobe / ip link type wireguard)"
  else
    local kver
    kver="$(uname -r 2>/dev/null || echo unknown)"
    cat >&2 <<EOF
error: kernel cannot create WireGuard interfaces (Unknown device type / Protocol not supported).

  Running kernel: ${kver}
  (modprobe wireguard failed — module not in /lib/modules/${kver})

  Diagnosis:
    uname -r
    lsmod | grep wireguard
    sudo modprobe wireguard
    sudo ip link add nbvpn type wireguard   # fails → missing kmod

  CentOS 8 / RHEL 8 — elrepo kmod-wireguard typically needs:
    kernel >= 4.18.0-553.el8_10
  Older kernels (e.g. 4.18.0-408.el8) will NOT load current kmod-wireguard.
  Do NOT use --skip-broken (tools install without a usable module).

  Fix (same host):
    1) Upgrade kernel to el8_10 (≥ 4.18.0-553.el8_10), reboot
    2) yum/dnf install epel-release elrepo-release kmod-wireguard wireguard-tools
    3) modprobe wireguard && systemctl restart wg-quick@nbvpn

  Or migrate to Rocky/Alma Linux 8+ with a current kernel, then re-run this installer.
  CentOS 8 is EOL — vault.centos.org mirrors may be required for updates.

  Docs: server/install/FIREWALL.md §7 CentOS 8 / missing WireGuard module
EOF
    err "WireGuard kernel module missing (kernel may be too old; need ≥ 4.18.0-553.el8_10 on EL8) — refusing to pretend install succeeded"
  fi
}

verify_nbvpn_on_path() {
  if ! command -v nbvpn >/dev/null 2>&1; then
    if [[ -x "${INSTALL_BIN_DIR}/nbvpn" ]]; then
      warn "nbvpn installed at ${INSTALL_BIN_DIR}/nbvpn but not on PATH — ensure ${INSTALL_BIN_DIR} is in PATH"
    else
      err "nbvpn binary missing after install (expected ${INSTALL_BIN_DIR}/nbvpn)"
    fi
  else
    log "nbvpn on PATH: $(command -v nbvpn)"
  fi
}

main() {
  need_root
  detect_os
  case "${OS_ID}" in
    rhel|centos|rocky|almalinux|fedora) ;;
    *)
      case " ${OS_LIKE} " in
        *"rhel"*|*"fedora"*|*"centos"*) ;;
        *)
          warn "OS_ID=${OS_ID} is not RHEL-family; continuing with dnf/yum anyway"
          ;;
      esac
      ;;
  esac
  install_wireguard_rhel
  require_cmd wg
  require_cmd wg-quick
  log "wg=$(command -v wg)  wg-quick=$(command -v wg-quick)"
  nbvpn_install_finish
  verify_nbvpn_on_path
}

main "$@"
