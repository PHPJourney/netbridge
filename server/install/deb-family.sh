#!/usr/bin/env bash
# NetBridge VPN — Debian / Ubuntu family installer (apt + WireGuard).
#
# Usage (as root):
#   sudo ./server/install/deb-family.sh
#   sudo ./server/install/debian.sh
#   sudo ./server/install/ubuntu.sh
#   curl -fsSL …/debian.sh | sudo bash   # via _bootstrap.sh
#
# Env: NBVPN_VERSION, NBVPN_BINARY_URL / NBVPN_DOWNLOAD_URL, INSTALL_BIN_DIR, NBVPN_SKIP_INSTALL, NBVPN_DATA_DIR
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

  # Newer linux-image packages (e.g. 5.15.0-190 while running 5.15.0-187) are
  # informational when WireGuard already works — soft warn only, do not fail.
  if kernel_reboot_pending_deb; then
    if wireguard_kernel_ok; then
      warn "kernel modules dir for $(uname -r) looks incomplete, but WireGuard works — continuing (reboot optional)"
    else
      warn "kernel modules dir for $(uname -r) missing — reboot required before WireGuard can load"
      print_reboot_required_bilingual
      exit 1
    fi
  elif wireguard_kernel_ok; then
    # apt may have installed a newer image than uname -r; that is not an install failure.
    local running newest_img
    running="$(uname -r 2>/dev/null || true)"
    newest_img="$(dpkg -l 'linux-image-[0-9]*' 2>/dev/null | awk '/^ii/{print $2}' | sed 's/^linux-image-//' | sort -V | tail -1 || true)"
    if [[ -n "${running}" && -n "${newest_img}" && "${newest_img}" != "${running}" ]]; then
      warn "newer kernel package installed (${newest_img}) than running (${running}) — informational; reboot later if desired"
    fi
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
