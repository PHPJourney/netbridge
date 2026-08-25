#!/usr/bin/env bash
# NetBridge VPN — entry installer: detect distro and dispatch to family script.
#
# Supports: Debian, Ubuntu, RHEL, CentOS (Linux/Stream), Rocky, Alma, Fedora
#
# Usage (as root):
#   curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/install.sh | sudo bash
#   sudo ./server/install/install.sh
#
# All Linux one-liners (install.sh / deb* / rhel* / centos*) run environment
# assessment + remediation via preflight_linux / family ensure_* before nbvpn.
#
# Env:
#   NBVPN_BINARY_URL / NBVPN_DOWNLOAD_URL  exact URL for prebuilt nbvpn (optional)
#   NBVPN_VERSION            pin Release tag (e.g. v0.1.11) when auto-resolving
#   NBVPN_SKIP_INSTALL       if 1, skip `nbvpn install`
#   NBVPN_SKIP_FIREWALL      if 1, skip ufw / firewalld allow rules
#   NBVPN_LISTEN_PORT        override port for firewall rules (default from nbvpn config)
#   NBVPN_SKIP_PREFLIGHT_REPOS  if 1, do not rewrite CentOS repos to vault
#   NBVPN_SKIP_KERNEL_UPDATE     if 1, skip kernel package updates on RHEL family
#   NBVPN_SPLIT_TUNNEL=1         new installs: client AllowedIPs = VPN subnet only (not 0.0.0.0/0)
#
# Docs: LINUX-PREFLIGHT.md  |  FIREWALL.md §7
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
  # Shared assessment before family remediation (family scripts re-run preflight_linux).
  preflight_linux soft
  case "${OS_ID}" in
    debian|ubuntu)
      log "dispatch → deb-family.sh (preflight done; apt remediation next)"
      exec bash "${NBVPN_INSTALL_DIR}/deb-family.sh"
      ;;
    rhel|centos|rocky|almalinux|fedora)
      log "dispatch → rhel-family.sh (OS_ID=${OS_ID}; preflight done; dnf/yum remediation next)"
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
          err "unsupported OS (${OS_ID}). Use: debian.sh / ubuntu.sh / centos.sh / rhel.sh — see LINUX-PREFLIGHT.md"
          ;;
      esac
      ;;
  esac
}

dispatch "$@"
