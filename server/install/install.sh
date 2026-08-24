#!/usr/bin/env bash
# NetBridge VPN — entry installer: detect distro and dispatch to family script.
#
# Supports: Debian, Ubuntu, RHEL, CentOS, Rocky, Alma
#
# Usage (as root):
#   curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/install.sh | sudo bash
#   sudo ./server/install/install.sh
#
# Env:
#   NBVPN_BINARY_URL    download prebuilt nbvpn if no local binary/Go
#   NBVPN_SKIP_INSTALL  if 1, skip `nbvpn install`
set -eo pipefail

_src="${BASH_SOURCE[0]:-}"
if [[ -n "${_src}" && "${_src}" != "-" && -f "$(dirname "${_src}")/_bootstrap.sh" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "${_src}")/_bootstrap.sh"
else
  _btmp="$(mktemp -d /tmp/netbridge-bootstrap.XXXXXX)"
  curl -fsSL "https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/_bootstrap.sh" -o "${_btmp}/_bootstrap.sh"
  # shellcheck source=/dev/null
  source "${_btmp}/_bootstrap.sh"
fi
set -u

nbvpn_bootstrap_ensure_dir both

# shellcheck source=./_common.sh
. "${NBVPN_INSTALL_DIR}/_common.sh"

dispatch() {
  need_root
  detect_os
  case "${OS_ID}" in
    debian|ubuntu)
      log "dispatch → deb-family.sh"
      exec bash "${NBVPN_INSTALL_DIR}/deb-family.sh"
      ;;
    rhel|centos|rocky|almalinux|fedora)
      log "dispatch → rhel-family.sh (OS_ID=${OS_ID})"
      exec bash "${NBVPN_INSTALL_DIR}/rhel-family.sh"
      ;;
    *)
      case " ${OS_LIKE} " in
        *"debian"*|*"ubuntu"*)
          log "dispatch → deb-family.sh (ID_LIKE)"
          exec bash "${NBVPN_INSTALL_DIR}/deb-family.sh"
          ;;
        *"rhel"*|*"fedora"*|*"centos"*)
          log "dispatch → rhel-family.sh (ID_LIKE)"
          exec bash "${NBVPN_INSTALL_DIR}/rhel-family.sh"
          ;;
        *)
          err "unsupported OS (${OS_ID}). Use: debian.sh / ubuntu.sh / centos.sh / rhel.sh"
          ;;
      esac
      ;;
  esac
}

dispatch "$@"
