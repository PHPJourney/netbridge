#!/usr/bin/env bash
# NetBridge VPN — Debian / Ubuntu family installer (apt + WireGuard).
#
# Usage (as root):
#   sudo ./server/install/deb-family.sh
#   sudo ./server/install/debian.sh
#   sudo ./server/install/ubuntu.sh
#   curl -fsSL …/debian.sh | sudo bash   # via _bootstrap.sh
#
# Env: NBVPN_VERSION, NBVPN_BINARY_URL, INSTALL_BIN_DIR, NBVPN_SKIP_INSTALL, NBVPN_DATA_DIR
# Preflight: preflight_linux in _common.sh (all Linux one-liners).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "${SCRIPT_DIR}/_common.sh"

# Install userspace + remediate kernel module (headers/dkms when needed).
ensure_wireguard_deb() {
  log "installing WireGuard packages (apt) — environment adaptation"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl ca-certificates iproute2 || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wireguard wireguard-tools curl ca-certificates iproute2 || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      wireguard-tools curl ca-certificates iproute2

  if ! wireguard_kernel_ok; then
    log "WireGuard kmod not loaded — trying wireguard-dkms + linux-headers"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      "linux-headers-$(uname -r)" 2>/dev/null || \
      warn "linux-headers-$(uname -r) not available"
    DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-dkms 2>/dev/null || \
      DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard 2>/dev/null || \
      warn "wireguard-dkms install skipped or failed"
    if command -v dkms >/dev/null 2>&1; then
      dkms autoinstall 2>/dev/null || true
    fi
    modprobe wireguard 2>/dev/null || true
  fi

  DEBIAN_FRONTEND=noninteractive apt-get install -y openresolv 2>/dev/null || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y resolvconf 2>/dev/null || \
    warn "openresolv/resolvconf not installed; DNS= in wg configs may need manual handling"

  if kernel_reboot_pending_deb; then
    warn "kernel modules dir for $(uname -r) missing — a reboot may be required"
    print_reboot_required_bilingual
    exit 1
  fi

  ensure_wireguard_kernel
}

main() {
  preflight_linux
  case "${OS_ID}" in
    debian|ubuntu) ;;
    *)
      case " ${OS_LIKE} " in
        *"debian"*|*"ubuntu"*) ;;
        *)
          warn "OS_ID=${OS_ID} is not debian/ubuntu; continuing with apt anyway"
          ;;
      esac
      ;;
  esac
  if [[ "${PKG_FAMILY}" != "apt" ]]; then
    warn "expected apt-get but PKG_FAMILY=${PKG_FAMILY}"
  fi
  ensure_wireguard_deb
  require_cmd wg
  require_cmd wg-quick
  log "wg=$(command -v wg)  wg-quick=$(command -v wg-quick)"
  nbvpn_install_finish
  verify_nbvpn_on_path
}

main "$@"
