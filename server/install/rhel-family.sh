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

install_wireguard_rhel() {
  log "installing WireGuard (dnf/yum)"
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y epel-release || true
    dnf install -y wireguard-tools curl ca-certificates || \
      dnf install -y wireguard-tools kmod-wireguard curl ca-certificates || true
  else
    yum install -y epel-release || true
    yum install -y wireguard-tools curl ca-certificates || true
  fi
  if ! command -v wg-quick >/dev/null 2>&1; then
    err "wireguard-tools not available from repos; install manually then re-run"
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
}

main "$@"
