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

# Sets: OS_ID OS_LIKE OS_VERSION OS_NAME OS_VARIANT_ID OS_PRETTY
#        IS_CENTOS_STREAM ARCH KERNEL_RELEASE
detect_os() {
  OS_ID="unknown"
  OS_LIKE=""
  OS_VERSION=""
  OS_NAME=""
  OS_VARIANT_ID=""
  OS_PRETTY=""
  IS_CENTOS_STREAM=0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_VERSION="${VERSION_ID:-}"
    OS_NAME="${NAME:-}"
    OS_VARIANT_ID="${VARIANT_ID:-}"
    OS_PRETTY="${PRETTY_NAME:-}"
  fi
  # CentOS Stream vs CentOS Linux (EOL both; Stream 8 common on VPS)
  case "${OS_ID}" in
    centos)
      if [[ "${OS_NAME}" == *[Ss]tream* ]] || [[ "${OS_VARIANT_ID}" == "stream" ]] || \
         [[ "${OS_PRETTY}" == *[Ss]tream* ]] || [[ "${NAME:-}" == *[Ss]tream* ]]; then
        IS_CENTOS_STREAM=1
      elif [[ -f /etc/centos-release ]] && grep -qi stream /etc/centos-release 2>/dev/null; then
        IS_CENTOS_STREAM=1
      fi
      ;;
  esac
  ARCH="$(uname -m 2>/dev/null || echo unknown)"
  KERNEL_RELEASE="$(uname -r 2>/dev/null || echo unknown)"
  local stream_note=""
  [[ "${IS_CENTOS_STREAM}" == "1" ]] && stream_note=" [CentOS Stream]"
  log "detected OS: ${OS_ID} ${OS_VERSION}${stream_note} (like: ${OS_LIKE:-n/a}; arch=${ARCH}; kernel=${KERNEL_RELEASE})"
}

# Whether the running kernel can create a WireGuard interface.
wireguard_kernel_ok() {
  if lsmod 2>/dev/null | grep -q '^wireguard'; then
    return 0
  fi
  if command -v modprobe >/dev/null 2>&1 && modprobe wireguard 2>/dev/null; then
    return 0
  fi
  # Built-in (no module) — try a throwaway link.
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

# Detect package manager family for logging / docs.
# Sets: PKG_FAMILY (apt|dnf|yum|unknown) HAS_SYSTEMD HAS_CURL HAS_IP HAS_MODPROBE
detect_pkg_and_runtime() {
  PKG_FAMILY="unknown"
  if command -v apt-get >/dev/null 2>&1; then
    PKG_FAMILY="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_FAMILY="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_FAMILY="yum"
  fi
  HAS_SYSTEMD=0
  HAS_CURL=0
  HAS_IP=0
  HAS_MODPROBE=0
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system || -d /etc/systemd/system ]]; then
    HAS_SYSTEMD=1
  fi
  command -v curl >/dev/null 2>&1 && HAS_CURL=1
  command -v ip >/dev/null 2>&1 && HAS_IP=1
  command -v modprobe >/dev/null 2>&1 && HAS_MODPROBE=1
}

# Full host assessment used by install.sh and every family script.
# Sets: HAS_WG HAS_WG_QUICK HAS_WIREGUARD_KMOD PREFLIGHT_ARCH_OK (+ detect_pkg_and_runtime)
# Args: optional "soft" — warn instead of hard-fail on missing curl/ip (dispatch-only).
preflight_linux() {
  local mode="${1:-strict}"
  need_root
  detect_os
  detect_pkg_and_runtime

  HAS_WG=0
  HAS_WG_QUICK=0
  HAS_WIREGUARD_KMOD=0
  PREFLIGHT_ARCH_OK=0
  case "${ARCH:-$(uname -m)}" in
    x86_64|amd64|aarch64|arm64) PREFLIGHT_ARCH_OK=1 ;;
  esac
  command -v wg >/dev/null 2>&1 && HAS_WG=1
  command -v wg-quick >/dev/null 2>&1 && HAS_WG_QUICK=1
  if wireguard_kernel_ok; then
    HAS_WIREGUARD_KMOD=1
  fi

  log "preflight: OS=${OS_ID} ${OS_VERSION}$([[ "${IS_CENTOS_STREAM}" == "1" ]] && echo ' Stream') arch=${ARCH} kernel=${KERNEL_RELEASE:-$(uname -r)}"
  log "preflight: pkg=${PKG_FAMILY} systemd=${HAS_SYSTEMD} curl=${HAS_CURL} ip=${HAS_IP} modprobe=${HAS_MODPROBE}"
  log "preflight: wg=${HAS_WG} wg-quick=${HAS_WG_QUICK} wireguard_kmod=${HAS_WIREGUARD_KMOD}"

  if [[ "${PREFLIGHT_ARCH_OK}" != "1" ]]; then
    err "unsupported architecture: ${ARCH} (need x86_64/amd64 or aarch64/arm64)"
  fi
  if [[ "${HAS_CURL}" != "1" ]]; then
    warn "curl not found yet — family script will try to install it (required for NBVPN_BINARY_URL downloads)"
  fi
  if [[ "${HAS_IP}" != "1" ]]; then
    warn "ip (iproute2) not found yet — family script will install it with WireGuard packages"
  fi
  if [[ "${HAS_SYSTEMD}" != "1" ]]; then
    warn "systemd not detected — nbvpn may still install, but service enable/start can fail"
  fi
  # mode=soft|strict currently same for tooling; reserved for future dispatch-only leniency
  : "${mode}"
}

# Back-compat alias
preflight_probe() { preflight_linux "$@"; }

ensure_install_bin_on_path() {
  case ":${PATH}:" in
    *":${INSTALL_BIN_DIR}:"*) ;;
    *)
      export PATH="${INSTALL_BIN_DIR}:${PATH}"
      log "PATH prepended with ${INSTALL_BIN_DIR}"
      ;;
  esac
}

# Fail hard if WireGuard kernel support is still missing after family remediation.
require_wireguard_kernel() {
  if wireguard_kernel_ok; then
    log "WireGuard kernel support OK (modprobe / ip link type wireguard)"
    return 0
  fi
  local kver
  kver="$(uname -r 2>/dev/null || echo unknown)"
  cat >&2 <<EOF
error: WireGuard kernel module still unavailable after remediation.

  Running kernel: ${kver}
  OS: ${OS_ID:-?} ${OS_VERSION:-?}  pkg=${PKG_FAMILY:-?}

  Copy-paste next steps:
    uname -r
    sudo modprobe wireguard
    sudo ip link add nbvpnprobe type wireguard   # must succeed

  Debian/Ubuntu:
    sudo apt-get update
    sudo apt-get install -y wireguard wireguard-tools wireguard-dkms linux-headers-\$(uname -r)
    sudo modprobe wireguard

  RHEL/CentOS/Rocky/Alma:
    # if newer kernel was installed: sudo reboot  then re-run installer
    sudo dnf install -y epel-release elrepo-release kmod-wireguard wireguard-tools || \\
      sudo yum install -y epel-release elrepo-release kmod-wireguard wireguard-tools
    # CentOS 8 / Stream EOL: vault must displace cloud mirrors (Aliyun etc.);
    # if kernel stays < 4.18.0-553 → migrate Rocky/Alma (LINUX-PREFLIGHT.md)

  Docs: server/install/LINUX-PREFLIGHT.md  |  FIREWALL.md §7
EOF
  err "WireGuard kernel module missing — refusing to pretend install succeeded"
}

# Alias used by family scripts after package remediation.
ensure_wireguard_kernel() { require_wireguard_kernel "$@"; }

verify_nbvpn_on_path() {
  ensure_install_bin_on_path
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

# True if an installed kernel RPM is newer than the running uname -r.
kernel_reboot_pending() {
  if ! command -v rpm >/dev/null 2>&1; then
    return 1
  fi
  local running newest
  running="$(uname -r)"
  newest="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V | tail -1 || true)"
  [[ -n "${newest}" && "${newest}" != "${running}" ]]
}

# Debian: also detect linux-image newer than running (reboot pending).
kernel_reboot_pending_deb() {
  if ! command -v dpkg >/dev/null 2>&1; then
    return 1
  fi
  local running
  running="$(uname -r)"
  # If a headers/image package for a different version is newly installed, reboot may be needed.
  if [[ -d "/lib/modules/${running}" ]]; then
    return 1
  fi
  # Running kernel modules dir missing after upgrade → reboot required
  return 0
}

print_reboot_required_bilingual() {
  local running newest
  running="$(uname -r 2>/dev/null || echo unknown)"
  newest="unknown"
  if command -v rpm >/dev/null 2>&1; then
    newest="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V | tail -1 || echo unknown)"
  fi
  cat >&2 <<EOF
error: a newer kernel is installed but not yet running — reboot required before nbvpn can finish.

  运行中内核 / running: ${running}
  已安装较新内核 / installed newer: ${newest}

  中文：请立即 reboot，启动新内核后再重新执行本安装脚本。
  English: reboot into the new kernel, then re-run this installer.

  sudo reboot
  # after reboot:
  curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/install.sh | sudo bash

  Docs: server/install/LINUX-PREFLIGHT.md
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "required command missing: $1"
}

# GitHub repo used for Releases download (owner/name).
nbvpn_github_repo() {
  echo "${NBVPN_INSTALL_REPO:-PHPJourney/netbridge}"
}

# Canonical Linux asset basename for this arch (matches CI: nbvpn-linux-amd64 / arm64).
nbvpn_linux_asset_name() {
  case "$(uname -m)" in
    aarch64|arm64) echo "nbvpn-linux-arm64" ;;
    *) echo "nbvpn-linux-amd64" ;;
  esac
}

# True if URL returns HTTP 200 (follow redirects). Uses HEAD when possible.
nbvpn_url_ok() {
  local url="$1"
  local code
  code="$(curl -fsSIL -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 "${url}" 2>/dev/null | tail -1 || true)"
  [[ "${code}" == "200" ]]
}

# Find newest non-draft release that publishes $asset via GitHub API.
# Prints browser_download_url or empty. Soft-fails (no exit).
nbvpn_api_find_asset_url() {
  local repo="$1"
  local asset="$2"
  local api="https://api.github.com/repos/${repo}/releases?per_page=30"
  local json
  json="$(curl -fsSL --connect-timeout 10 --max-time 30 "${api}" 2>/dev/null || true)"
  [[ -n "${json}" ]] || return 0
  if command -v python3 >/dev/null 2>&1; then
    REPO_ASSET="${asset}" python3 -c '
import json, os, sys
asset = os.environ["REPO_ASSET"]
try:
    rels = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for r in rels:
    if r.get("draft"):
        continue
    for a in r.get("assets") or []:
        if a.get("name") == asset:
            print(a.get("browser_download_url") or "")
            sys.exit(0)
' <<<"${json}" 2>/dev/null || true
    return 0
  fi
  # Minimal fallback without python: pick first tag that lists the asset name in JSON.
  local tag
  tag="$(printf '%s' "${json}" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v[^"]+"' | head -30 | sed 's/.*"\(v[^"]*\)".*/\1/' || true)"
  local t
  for t in ${tag}; do
    if printf '%s' "${json}" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${asset}\""; then
      # Prefer explicit download URL for this tag+asset if present in blob.
      local guess="https://github.com/${repo}/releases/download/${t}/${asset}"
      if nbvpn_url_ok "${guess}"; then
        echo "${guess}"
        return 0
      fi
    fi
  done
}

# Build ordered candidate download URLs (one per line) for the Linux binary.
nbvpn_binary_candidate_urls() {
  local repo asset base
  repo="$(nbvpn_github_repo)"
  asset="$(nbvpn_linux_asset_name)"
  base="https://github.com/${repo}/releases"

  # Explicit override wins as first candidate only (still listed alone by caller).
  if [[ -n "${NBVPN_DOWNLOAD_URL:-}" ]]; then
    echo "${NBVPN_DOWNLOAD_URL}"
    return 0
  fi
  if [[ -n "${NBVPN_BINARY_URL:-}" ]]; then
    echo "${NBVPN_BINARY_URL}"
    return 0
  fi

  # Pin to a release tag when NBVPN_VERSION looks like a tag (v0.1.11 or 0.1.11).
  local ver="${NBVPN_VERSION:-}"
  if [[ -n "${ver}" && "${ver}" != "1.0.0" ]]; then
    case "${ver}" in
      v*) echo "${base}/download/${ver}/${asset}" ;;
      [0-9]*) echo "${base}/download/v${ver}/${asset}" ;;
    esac
  fi

  echo "${base}/latest/download/${asset}"
  # Alternate names occasionally used in docs / mirrors
  echo "${base}/latest/download/${asset}.tar.gz"

  local api_url
  api_url="$(nbvpn_api_find_asset_url "${repo}" "${asset}" || true)"
  if [[ -n "${api_url}" ]]; then
    echo "${api_url}"
  fi

  # Last-resort known-good tag (v0.1.12+ client-only releases omitted linux binaries).
  echo "${base}/download/v0.1.11/${asset}"
}

# Download URL → dest path. Optional companion .sha256 when published.
nbvpn_download_url_to() {
  local url="$1"
  local dest="$2"
  curl -fsSL --connect-timeout 15 --max-time 300 "${url}" -o "${dest}"
}

nbvpn_verify_sha256_if_present() {
  local bin_path="$1"
  local url="$2"
  local sum_url="${url}.sha256"
  local sum_file
  sum_file="$(mktemp)"
  if ! curl -fsSL --connect-timeout 8 --max-time 30 "${sum_url}" -o "${sum_file}" 2>/dev/null; then
    rm -f "${sum_file}"
    warn "no checksum at ${sum_url} — skipping sha256 verify"
    return 0
  fi
  # Normalize to "HASH  filename" for sha256sum -c from parent dir.
  local hash
  hash="$(awk '{print $1}' "${sum_file}" | head -1)"
  rm -f "${sum_file}"
  if [[ -z "${hash}" || "${#hash}" -lt 64 ]]; then
    warn "checksum file unreadable — skipping sha256 verify"
    return 0
  fi
  local got
  if command -v sha256sum >/dev/null 2>&1; then
    got="$(sha256sum "${bin_path}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    got="$(shasum -a 256 "${bin_path}" | awk '{print $1}')"
  else
    warn "sha256sum/shasum missing — skipping checksum verify"
    return 0
  fi
  if [[ "${got}" != "${hash}" ]]; then
    err "sha256 mismatch for downloaded nbvpn (expected ${hash}, got ${got})"
  fi
  log "sha256 OK (${hash:0:12}…)"
}

nbvpn_file_looks_executable() {
  local path="$1"
  [[ -s "${path}" ]] || return 1
  # Reject HTML error pages / tiny stubs
  local sz
  sz="$(wc -c <"${path}" | tr -d ' ')"
  [[ "${sz}" -gt 1000000 ]] || return 1
  if command -v file >/dev/null 2>&1; then
    file -b "${path}" 2>/dev/null | grep -qiE 'executable|ELF|Mach-O|PE32' && return 0
    # Still accept large opaque blobs (some systems lack file(1) magic)
  fi
  return 0
}

# Resolve + download nbvpn into INSTALL_BIN_DIR/nbvpn. Tries candidates; clear error on total failure.
download_nbvpn_binary() {
  local tmp tried="" url dest
  dest="${INSTALL_BIN_DIR}/nbvpn"
  mkdir -p "${INSTALL_BIN_DIR}"

  # Deduplicate candidates while preserving order.
  local -a urls=()
  local u seen
  while IFS= read -r u; do
    [[ -n "${u}" ]] || continue
    seen=0
    for x in "${urls[@]+"${urls[@]}"}"; do
      [[ "${x}" == "${u}" ]] && { seen=1; break; }
    done
    [[ "${seen}" == "1" ]] && continue
    urls+=("${u}")
  done < <(nbvpn_binary_candidate_urls)

  if [[ "${#urls[@]}" -eq 0 ]]; then
    err "no download URL candidates (set NBVPN_BINARY_URL or NBVPN_DOWNLOAD_URL)"
  fi

  for url in "${urls[@]}"; do
    tried="${tried}  - ${url}"$'\n'
    if ! nbvpn_url_ok "${url}"; then
      warn "skip (HTTP not 200): ${url}"
      continue
    fi
    log "trying download: ${url}"
    tmp="$(mktemp)"
    if nbvpn_download_url_to "${url}" "${tmp}" \
      && nbvpn_file_looks_executable "${tmp}"; then
      nbvpn_verify_sha256_if_present "${tmp}" "${url}"
      install -m 0755 "${tmp}" "${dest}"
      rm -f "${tmp}"
      log "downloaded nbvpn from ${url}"
      return 0
    fi
    rm -f "${tmp}"
    warn "download failed or not a binary: ${url}"
  done

  cat >&2 <<EOF
error: could not download nbvpn binary (all candidates failed).

Tried:
${tried}
Root cause often: GitHub \`releases/latest\` is a client-only tag (APK/exe) without
\`nbvpn-linux-amd64\` / \`nbvpn-linux-arm64\`. Last known good example:
  https://github.com/$(nbvpn_github_repo)/releases/download/v0.1.11/$(nbvpn_linux_asset_name)

Immediate workaround (JP/VPS):
  sudo NBVPN_BINARY_URL='https://github.com/$(nbvpn_github_repo)/releases/download/v0.1.11/$(nbvpn_linux_asset_name)' \\
    bash -c 'curl -fsSL https://raw.githubusercontent.com/$(nbvpn_github_repo)/main/server/install/ubuntu.sh | bash'

Or scp a local build:
  scp server/nbvpn/dist/$(nbvpn_linux_asset_name) root@HOST:/opt/netbridge/nbvpn
  sudo chmod +x /opt/netbridge/nbvpn
  curl -fsSL …/ubuntu.sh | sudo bash

Docs: server/install/LINUX-PREFLIGHT.md
EOF
  exit 1
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
  elif [[ -n "${NBVPN_DOWNLOAD_URL:-}${NBVPN_BINARY_URL:-}" ]] || [[ "${NBVPN_FORCE_DOWNLOAD:-0}" == "1" ]] \
    || ! [[ -d "${NBVPN_SRC}" ]]; then
    # curl|bash / remote install: resolve GitHub Release asset (with fallbacks).
    download_nbvpn_binary
  else
    # Local tree without binary — still try Releases before failing.
    warn "no local nbvpn binary/Go — falling back to GitHub Releases download"
    download_nbvpn_binary
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

nbvpn_listen_port() {
  if [[ -n "${NBVPN_LISTEN_PORT:-}" ]]; then
    echo "${NBVPN_LISTEN_PORT}"
    return 0
  fi
  local bin="${INSTALL_BIN_DIR}/nbvpn"
  if command -v "${bin}" >/dev/null 2>&1; then
    local line
    line="$("${bin}" config 2>/dev/null | grep -i listenPort | head -1 || true)"
    if [[ -n "${line}" ]]; then
      echo "${line##*:}" | tr -d '[:space:]'
      return 0
    fi
  fi
  echo 51820
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

configure_host_firewall() {
  if [[ "${NBVPN_SKIP_FIREWALL:-0}" == "1" ]]; then
    log "NBVPN_SKIP_FIREWALL=1 — skipping host firewall configuration"
    return 0
  fi

  local port
  port="$(nbvpn_listen_port)"
  log "configuring host firewall for UDP ${port} (WireGuard / nbvpn)"

  if command -v ufw >/dev/null 2>&1; then
    if ufw status numbered 2>/dev/null | grep -qE "(^|[[:space:]])${port}/udp"; then
      log "ufw: UDP ${port} rule already present"
    else
      log "ufw: allowing inbound UDP ${port}"
      if ufw allow "${port}/udp" comment 'nbvpn WireGuard' >/dev/null 2>&1; then
        ok_msg="ufw allow ${port}/udp"
      elif ufw allow "${port}/udp" >/dev/null 2>&1; then
        ok_msg="ufw allow ${port}/udp"
      else
        warn "ufw allow ${port}/udp failed — run manually: ufw allow ${port}/udp"
        ok_msg=""
      fi
      [[ -n "${ok_msg}" ]] && log "${ok_msg}"
    fi
    if ufw status 2>/dev/null | grep -qiE 'Status:[[:space:]]*active'; then
      ufw reload >/dev/null 2>&1 || true
      log "ufw: reloaded (active)"
    else
      warn "ufw installed but not active — rule queued; enable with: ufw enable"
    fi
  fi

  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    if firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/udp"; then
      log "firewalld: UDP ${port} already allowed"
    else
      log "firewalld: allowing UDP ${port} permanently"
      if firewall-cmd --permanent --add-port="${port}/udp" >/dev/null 2>&1; then
        firewall-cmd --reload >/dev/null 2>&1 || true
      else
        warn "firewall-cmd --add-port=${port}/udp failed"
      fi
    fi
  fi
}

print_cloud_security_group_hints() {
  local port
  port="$(nbvpn_listen_port)"
  cat <<EOF

  Cloud security group / ACL (manual — install cannot change your cloud panel):
    • Inbound: UDP ${port} from clients (0.0.0.0/0 for public self-hosted, or tighter CIDRs)
    • Attach the rule group to THIS instance / VM (rules alone are not enough)
    • TCP 22/80/443 alone does NOT carry WireGuard — need UDP ${port}
    Docs: server/install/FIREWALL.md §2
EOF
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

  # Host firewall: install script already tried ufw allow UDP <listenPort> / firewalld.
  # Cloud security group: you must allow inbound UDP <listenPort> in the provider panel.
  #   Docs: server/install/FIREWALL.md
  # NAT / forwarding is baked into nbvpn.conf PostUp (ip_forward + MASQUERADE).
  # If VPN icon+traffic but no internet: check sysctl net.ipv4.ip_forward=1
  #   and: sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
  # Then on a client: import URI / scan PNG / import .nbvpn.json
  #   Trial guide: docs/delivery/nbvpn/TRY-CONNECT.md
--------------------------------------------------------------------
EOF
}

nbvpn_install_finish() {
  ensure_install_bin_on_path
  install_nbvpn_binary
  ensure_install_bin_on_path
  run_nbvpn_install
  ensure_ufw_forward
  configure_host_firewall
  if [[ -x "${INSTALL_BIN_DIR}/nbvpn" ]]; then
    log "nbvpn binary OK: ${INSTALL_BIN_DIR}/nbvpn"
  fi
  log "done."
  print_cloud_security_group_hints
  post_install_hints
}
