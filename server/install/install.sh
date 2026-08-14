#!/usr/bin/env bash
# NetBridge VPN — entry installer: detect distro and dispatch to family script.
#
# Supports: Debian, Ubuntu, RHEL, CentOS, Rocky, Alma
#
# Usage (as root):
#   curl -fsSL …/install.sh | bash
#   sudo ./server/install/install.sh
#
# Prefer explicit family/distro scripts when known:
#   sudo ./server/install/debian.sh | ubuntu.sh | centos.sh | rhel.sh
#   sudo ./server/install/deb-family.sh | rhel-family.sh
#
# Env:
#   NBVPN_VERSION       informational label (default 1.0.0)
#   NBVPN_BINARY_URL    download prebuilt nbvpn if no local binary/Go
#   INSTALL_BIN_DIR     default /usr/local/bin
#   NBVPN_SKIP_INSTALL  if 1, only install tools+binary (skip `nbvpn install`)
#   NBVPN_DATA_DIR      passed through to nbvpn
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./_common.sh
. "${SCRIPT_DIR}/_common.sh"

dispatch() {
  need_root
  detect_os
  case "${OS_ID}" in
    debian)
      log "dispatch → debian.sh / deb-family.sh"
      exec bash "${SCRIPT_DIR}/deb-family.sh"
      ;;
    ubuntu)
      log "dispatch → ubuntu.sh / deb-family.sh"
      exec bash "${SCRIPT_DIR}/deb-family.sh"
      ;;
    rhel|centos|rocky|almalinux|fedora)
      log "dispatch → rhel-family.sh (OS_ID=${OS_ID})"
      exec bash "${SCRIPT_DIR}/rhel-family.sh"
      ;;
    *)
      case " ${OS_LIKE} " in
        *"debian"*|*"ubuntu"*)
          log "dispatch → deb-family.sh (ID_LIKE)"
          exec bash "${SCRIPT_DIR}/deb-family.sh"
          ;;
        *"rhel"*|*"fedora"*|*"centos"*)
          log "dispatch → rhel-family.sh (ID_LIKE)"
          exec bash "${SCRIPT_DIR}/rhel-family.sh"
          ;;
        *)
          err "unsupported OS (${OS_ID}). Use: debian.sh / ubuntu.sh / centos.sh / rhel.sh"
          ;;
      esac
      ;;
  esac
}

dispatch "$@"
