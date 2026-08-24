#!/usr/bin/env bash
# Bootstrap for curl | bash one-liners: fetch companion scripts from GitHub raw.
# Sourced by install.sh / *-family wrappers — not run directly.
# shellcheck shell=bash

NBVPN_INSTALL_REPO="${NBVPN_INSTALL_REPO:-PHPJourney/netbridge}"
NBVPN_INSTALL_BRANCH="${NBVPN_INSTALL_BRANCH:-main}"
NBVPN_INSTALL_RAW_BASE="${NBVPN_INSTALL_RAW_BASE:-https://raw.githubusercontent.com/${NBVPN_INSTALL_REPO}/${NBVPN_INSTALL_BRANCH}/server/install}"

nbvpn_bootstrap_log() { printf '==> %s\n' "$*" >&2; }
nbvpn_bootstrap_err() { printf 'error: %s\n' "$*" >&2; exit 1; }

nbvpn_bootstrap_fetch() {
  local name="$1"
  local dest="$2"
  curl -fsSL "${NBVPN_INSTALL_RAW_BASE}/${name}" -o "${dest}"
}

# Resolve directory containing a complete install script bundle.
# Sets NBVPN_INSTALL_DIR. Args: deb|rhel|both
nbvpn_bootstrap_ensure_dir() {
  local mode="${1:-both}"

  local caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-}}"
  if [[ -n "${caller}" && "${caller}" != "-" && -f "${caller}" ]]; then
    local dir
    dir="$(cd "$(dirname "${caller}")" && pwd)"
    if [[ -f "${dir}/_common.sh" ]]; then
      case "${mode}" in
        deb)
          if [[ -f "${dir}/deb-family.sh" ]]; then
            NBVPN_INSTALL_DIR="${dir}"
            export NBVPN_INSTALL_DIR
            return 0
          fi
          ;;
        rhel)
          if [[ -f "${dir}/rhel-family.sh" ]]; then
            NBVPN_INSTALL_DIR="${dir}"
            export NBVPN_INSTALL_DIR
            return 0
          fi
          ;;
        both)
          if [[ -f "${dir}/deb-family.sh" && -f "${dir}/rhel-family.sh" ]]; then
            NBVPN_INSTALL_DIR="${dir}"
            export NBVPN_INSTALL_DIR
            return 0
          fi
          ;;
      esac
    fi
  fi

  command -v curl >/dev/null 2>&1 || nbvpn_bootstrap_err "curl required for remote install (or clone repo and run ./server/install/*.sh locally)"

  NBVPN_INSTALL_DIR="${NBVPN_INSTALL_WORKDIR:-$(mktemp -d /tmp/netbridge-install.XXXXXX)}"
  export NBVPN_INSTALL_DIR
  nbvpn_bootstrap_log "curl 管道安装：从 GitHub 拉取配套脚本 → ${NBVPN_INSTALL_DIR}"

  nbvpn_bootstrap_fetch "_common.sh" "${NBVPN_INSTALL_DIR}/_common.sh"
  case "${mode}" in
    deb)
      nbvpn_bootstrap_fetch "deb-family.sh" "${NBVPN_INSTALL_DIR}/deb-family.sh"
      ;;
    rhel)
      nbvpn_bootstrap_fetch "rhel-family.sh" "${NBVPN_INSTALL_DIR}/rhel-family.sh"
      ;;
    both)
      nbvpn_bootstrap_fetch "deb-family.sh" "${NBVPN_INSTALL_DIR}/deb-family.sh"
      nbvpn_bootstrap_fetch "rhel-family.sh" "${NBVPN_INSTALL_DIR}/rhel-family.sh"
      ;;
  esac

  if [[ -z "${NBVPN_BINARY_URL:-}" ]]; then
    local arch
    arch="$(uname -m)"
    case "${arch}" in
      aarch64|arm64)
        export NBVPN_BINARY_URL="https://github.com/${NBVPN_INSTALL_REPO}/releases/latest/download/nbvpn-linux-arm64"
        ;;
      *)
        export NBVPN_BINARY_URL="https://github.com/${NBVPN_INSTALL_REPO}/releases/latest/download/nbvpn-linux-amd64"
        ;;
    esac
    nbvpn_bootstrap_log "NBVPN_BINARY_URL=${NBVPN_BINARY_URL}"
  fi
}

# Load _bootstrap.sh from repo dir or GitHub (for entry scripts).
nbvpn_bootstrap_load() {
  local entry="${1:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-}}}"
  if [[ -n "${entry}" && "${entry}" != "-" && -f "${entry}" ]]; then
    local dir
    dir="$(cd "$(dirname "${entry}")" && pwd)"
    if [[ -f "${dir}/_bootstrap.sh" ]]; then
      # shellcheck source=/dev/null
      source "${dir}/_bootstrap.sh"
      return 0
    fi
  fi
  local base="${NBVPN_INSTALL_RAW_BASE:-https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install}"
  local tmp
  tmp="$(mktemp -d /tmp/netbridge-bootstrap.XXXXXX)"
  curl -fsSL "${base}/_bootstrap.sh" -o "${tmp}/_bootstrap.sh"
  # shellcheck source=/dev/null
  source "${tmp}/_bootstrap.sh"
}
