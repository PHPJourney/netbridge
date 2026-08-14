#!/usr/bin/env bash
# NetBridge VPN — Debian / Ubuntu family installer (apt + WireGuard).
#
# Usage (as root):
#   sudo ./server/install/deb-family.sh
#   sudo ./server/install/debian.sh
#   sudo ./server/install/ubuntu.sh
#
# Env: NBVPN_VERSION, NBVPN_BINARY_URL, INSTALL_BIN_DIR, NBVPN_SKIP_INSTALL, NBVPN_DATA_DIR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "${SCRIPT_DIR}/_common.sh"

install_wireguard_deb() {
  log "installing WireGuard (apt)"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wireguard wireguard-tools curl ca-certificates || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      wireguard-tools curl ca-certificates
  DEBIAN_FRONTEND=noninteractive apt-get install -y openresolv 2>/dev/null || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y resolvconf 2>/dev/null || \
    warn "openresolv/resolvconf not installed; DNS= in wg configs may need manual handling"
}

main() {
  need_root
  detect_os
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
  install_wireguard_deb
  require_cmd wg
  require_cmd wg-quick
  log "wg=$(command -v wg)  wg-quick=$(command -v wg-quick)"
  nbvpn_install_finish
}

main "$@"
