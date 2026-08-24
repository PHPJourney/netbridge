#!/usr/bin/env bash
# Shared helpers for NetBridge nbvpn install scripts.
# Sourced by family/distro scripts — do not run directly.
# shellcheck shell=bash

NBVPN_VERSION="${NBVPN_VERSION:-1.0.0}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-/usr/local/bin}"

# When sourced from a family script under server/install/
# NBVPN_INSTALL_DIR set by _bootstrap.sh for curl|bash one-liners.
if [[ -n "${NBVPN_INSTALL_DIR:-}" ]]; then
  _INSTALL_DIR="${NBVPN_INSTALL_DIR}"
else
  _INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
REPO_ROOT="$(cd "${_INSTALL_DIR}/../.." && pwd)"
NBVPN_SRC="${REPO_ROOT}/server/nbvpn"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
err()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "run as root (sudo $0)"
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_VERSION="${VERSION_ID:-}"
  else
    OS_ID="unknown"
    OS_LIKE=""
    OS_VERSION=""
  fi
  log "detected OS: ${OS_ID} ${OS_VERSION} (like: ${OS_LIKE:-n/a})"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "required command missing: $1"
}

install_nbvpn_binary() {
  mkdir -p "${INSTALL_BIN_DIR}"
  local arch
  arch="$(uname -m)"
  local dist_bin=""
  case "${arch}" in
    x86_64|amd64) dist_bin="${NBVPN_SRC}/dist/nbvpn-linux-amd64" ;;
    aarch64|arm64) dist_bin="${NBVPN_SRC}/dist/nbvpn-linux-arm64" ;;
  esac

  # Bundled next to install scripts (e.g. /opt/netbridge/server/install/../nbvpn/…)
  local bundled=""
  case "${arch}" in
    x86_64|amd64) bundled="${_INSTALL_DIR}/../nbvpn/dist/nbvpn-linux-amd64" ;;
    aarch64|arm64) bundled="${_INSTALL_DIR}/../nbvpn/dist/nbvpn-linux-arm64" ;;
  esac
  # Also accept binary dropped beside install tree on VPS: /opt/netbridge/nbvpn
  local opt_bin="/opt/netbridge/nbvpn"
  local opt_named=""
  case "${arch}" in
    x86_64|amd64) opt_named="/opt/netbridge/nbvpn-linux-amd64" ;;
    aarch64|arm64) opt_named="/opt/netbridge/nbvpn-linux-arm64" ;;
  esac

  if [[ -n "${dist_bin}" && -x "${dist_bin}" ]]; then
    log "installing release binary from ${dist_bin}"
    install -m 0755 "${dist_bin}" "${INSTALL_BIN_DIR}/nbvpn"
  elif [[ -n "${bundled}" && -x "${bundled}" ]]; then
    log "installing release binary from ${bundled}"
    install -m 0755 "${bundled}" "${INSTALL_BIN_DIR}/nbvpn"
  elif [[ -x "${opt_bin}" ]]; then
    log "installing binary from ${opt_bin}"
    install -m 0755 "${opt_bin}" "${INSTALL_BIN_DIR}/nbvpn"
  elif [[ -n "${opt_named}" && -x "${opt_named}" ]]; then
    log "installing binary from ${opt_named}"
    install -m 0755 "${opt_named}" "${INSTALL_BIN_DIR}/nbvpn"
  elif [[ -x "${NBVPN_SRC}/nbvpn" ]]; then
    log "installing prebuilt binary from ${NBVPN_SRC}/nbvpn"
    install -m 0755 "${NBVPN_SRC}/nbvpn" "${INSTALL_BIN_DIR}/nbvpn"
  elif command -v go >/dev/null 2>&1 && [[ -f "${NBVPN_SRC}/go.mod" ]]; then
    log "building nbvpn from source (Go $(go version | awk '{print $3}'))"
    (cd "${NBVPN_SRC}" && go build -o nbvpn .)
    install -m 0755 "${NBVPN_SRC}/nbvpn" "${INSTALL_BIN_DIR}/nbvpn"
  elif [[ -n "${NBVPN_BINARY_URL:-}" ]]; then
    log "downloading nbvpn from ${NBVPN_BINARY_URL}"
    local tmp
    tmp="$(mktemp)"
    curl -fsSL "${NBVPN_BINARY_URL}" -o "${tmp}"
    install -m 0755 "${tmp}" "${INSTALL_BIN_DIR}/nbvpn"
    rm -f "${tmp}"
  else
    err "no nbvpn binary found. Build with: ./server/nbvpn/scripts/build-release.sh  or set NBVPN_BINARY_URL"
  fi
  require_cmd "${INSTALL_BIN_DIR}/nbvpn"
  log "installed ${INSTALL_BIN_DIR}/nbvpn (label ${NBVPN_VERSION})"
  "${INSTALL_BIN_DIR}/nbvpn" help >/dev/null || warn "nbvpn help returned non-zero"
}

run_nbvpn_install() {
  if [[ "${NBVPN_SKIP_INSTALL:-0}" == "1" ]]; then
    log "NBVPN_SKIP_INSTALL=1 — skipping nbvpn install"
  else
    log "running: nbvpn install"
    "${INSTALL_BIN_DIR}/nbvpn" install
  fi
}

ensure_ufw_forward() {
  # Full-tunnel clients need FORWARD ACCEPT when ufw is active.
  if [[ -f /etc/default/ufw ]] && command -v ufw >/dev/null 2>&1; then
    if grep -q '^DEFAULT_FORWARD_POLICY="DROP"' /etc/default/ufw 2>/dev/null; then
      log "setting ufw DEFAULT_FORWARD_POLICY=ACCEPT (required for VPN client internet)"
      sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
      ufw reload >/dev/null 2>&1 || true
    fi
  fi
}

post_install_hints() {
  cat <<'EOF'

--------------------------------------------------------------------
Next steps:

  nbvpn show                 # URI + terminal QR + file + PNG paths
  nbvpn show --uri           # copy URI only (stdout)
  nbvpn show --file          # print .nbvpn.json (+ PNG) paths
  # default data dir: /var/lib/nbvpn

  # Verify:
  sudo server/install/smoke-verify.sh

  # Firewall (host + cloud security group): allow UDP 51820 (or your listen port)
  #   Docs: server/install/FIREWALL.md
  #   ufw allow 51820/udp && ufw reload
  # NAT / forwarding is baked into nbvpn.conf PostUp (ip_forward + MASQUERADE).
  # If VPN icon+traffic but no internet: check sysctl net.ipv4.ip_forward=1
  #   and: sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
  # Then on a client: import URI / scan PNG / import .nbvpn.json
  #   Trial guide: docs/delivery/nbvpn/TRY-CONNECT.md
--------------------------------------------------------------------
EOF
}

nbvpn_install_finish() {
  install_nbvpn_binary
  run_nbvpn_install
  ensure_ufw_forward
  log "done."
  post_install_hints
}
