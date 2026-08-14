#!/usr/bin/env bash
# One-command post-install smoke checks for nbvpn (S02 acceptance-oriented).
# Run on the Linux VPS AFTER install.sh (root recommended for service ops).
#
# Usage:
#   sudo ./server/install/smoke-verify.sh
#   NBVPN_DATA_DIR=/custom ./smoke-verify.sh
#
# Exit 0 = all must-checks passed (or dry-run noted). Non-zero = failure.
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

ok()   { printf '[PASS] %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '[FAIL] %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
skip() { printf '[SKIP] %s\n' "$*"; SKIP=$((SKIP + 1)); }
info() { printf '[INFO] %s\n' "$*"; }

need_nbvpn() {
  if command -v nbvpn >/dev/null 2>&1; then
    NBVPN_BIN="$(command -v nbvpn)"
  elif [[ -x /usr/local/bin/nbvpn ]]; then
    NBVPN_BIN=/usr/local/bin/nbvpn
  else
    bad "nbvpn not on PATH"
    return 1
  fi
  ok "nbvpn binary: ${NBVPN_BIN}"
}

check_help() {
  if "${NBVPN_BIN}" help >/dev/null 2>&1; then
    ok "nbvpn help"
  else
    bad "nbvpn help failed"
  fi
}

check_config() {
  local out
  if ! out="$("${NBVPN_BIN}" config 2>&1)"; then
    bad "nbvpn config failed: ${out}"
    return
  fi
  if echo "${out}" | grep -qiE 'private[_ ]?key|PrivateKey'; then
    # allow "private key is not shown"
    if echo "${out}" | grep -qi 'not shown'; then
      ok "config summary (no server private key leak)"
    else
      bad "config output may leak private key material"
    fi
  else
    ok "config summary (no private key field)"
  fi
  if echo "${out}" | grep -qiE 'publicKey|public key|PublicKey'; then
    ok "config shows public identity"
  else
    bad "config missing public key / identity"
  fi
}

check_status() {
  local out
  if ! out="$("${NBVPN_BIN}" status 2>&1)"; then
    bad "nbvpn status failed: ${out}"
    return
  fi
  if echo "${out}" | grep -qi 'dry-run'; then
    skip "status reports dry-run (wg-quick missing or non-Linux) — SV-05 blocked until real wg"
  else
    ok "nbvpn status ran"
  fi
  info "status excerpt: $(echo "${out}" | head -n 3 | tr '\n' ' ')"
}

check_show_artifacts() {
  local out data_dir peer_json peer_png
  data_dir="${NBVPN_DATA_DIR:-/var/lib/nbvpn}"
  if [[ ! -d "${data_dir}" ]]; then
    # fallback used by CLI when /var/lib not writable
    if [[ -d /usr/local/var/lib/nbvpn ]]; then
      data_dir=/usr/local/var/lib/nbvpn
    fi
  fi

  if ! out="$("${NBVPN_BIN}" show --all 2>&1)"; then
    # some builds use default --all without flag; try bare show
    if ! out="$("${NBVPN_BIN}" show 2>&1)"; then
      bad "nbvpn show failed"
      return
    fi
  fi

  if echo "${out}" | grep -qE '^nbvpn:1\?'; then
    ok "show prints nbvpn:1? URI"
  elif echo "${out}" | grep -q 'nbvpn:1?'; then
    ok "show contains nbvpn:1? URI"
  else
    bad "show missing nbvpn URI"
  fi

  peer_json="$(find "${data_dir}/peers" -name '*.nbvpn.json' 2>/dev/null | head -n 1 || true)"
  if [[ -n "${peer_json}" && -f "${peer_json}" ]]; then
    ok "profile file exists: ${peer_json}"
  else
    bad "no peers/*.nbvpn.json under ${data_dir}"
  fi

  peer_png="$(find "${data_dir}/peers" -name '*.png' 2>/dev/null | head -n 1 || true)"
  if [[ -n "${peer_png}" && -f "${peer_png}" ]]; then
    local magic
    magic="$(head -c 8 "${peer_png}" | od -An -tx1 | tr -d ' \n')"
    if [[ "${magic}" == *89504e470d0a1a0a* ]] \
      || { command -v file >/dev/null 2>&1 && file "${peer_png}" | grep -qi PNG; }; then
      ok "QR PNG exists (scan this if terminal QR wraps): ${peer_png}"
    else
      bad "PNG path exists but file does not look like PNG: ${peer_png}"
    fi
    local mode
    mode="$(stat -c '%a' "${peer_png}" 2>/dev/null || stat -f '%OLp' "${peer_png}" 2>/dev/null || echo '?')"
    info "PNG mode=${mode} (expect 600)"
  else
    bad "no peers/*.png under ${data_dir} — terminal QR fallback may be required"
  fi

  if echo "${out}" | grep -qE '█|▀|▄'; then
    ok "terminal QR block characters present"
  else
    skip "terminal QR glyphs not detected in capture (SSH/encoding?) — use PNG"
  fi

  if echo "${out}" | grep -qi 'file\|PNG\|wrap\|--uri'; then
    ok "show includes file/PNG/fallback guidance"
  else
    info "show output may omit fallback hint in this mode"
  fi
}

check_tools() {
  if command -v wg-quick >/dev/null 2>&1; then
    ok "wg-quick present"
  else
    skip "wg-quick missing — install wireguard-tools (real tunnel blocked)"
  fi
  if command -v wg >/dev/null 2>&1; then
    ok "wg present"
  else
    skip "wg missing"
  fi
}

check_nat_forward() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    skip "NAT/forward checks are Linux-only"
    return
  fi
  local fwd
  fwd="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)"
  if [[ "${fwd}" == "1" ]]; then
    ok "net.ipv4.ip_forward=1"
  else
    bad "net.ipv4.ip_forward=${fwd} (clients will connect but have no internet)"
  fi
  if [[ -f /etc/wireguard/nbvpn.conf ]] && grep -q 'MASQUERADE' /etc/wireguard/nbvpn.conf; then
    ok "nbvpn.conf includes MASQUERADE PostUp"
  else
    bad "nbvpn.conf missing MASQUERADE PostUp — redeploy nbvpn and re-run install/sync"
  fi
  if command -v iptables >/dev/null 2>&1; then
    if iptables -t nat -S POSTROUTING 2>/dev/null | grep -qi MASQUERADE; then
      ok "iptables NAT POSTROUTING has MASQUERADE"
    else
      bad "no live MASQUERADE rule — restart wg-quick@nbvpn after fixing conf"
    fi
  else
    skip "iptables not found"
  fi
}

main() {
  echo "=== nbvpn smoke-verify ($(date -u +%Y-%m-%dT%H:%MZ)) ==="
  need_nbvpn || { echo "FAIL=${FAIL}"; exit 1; }
  check_tools
  check_help
  check_config
  check_status
  check_show_artifacts
  check_nat_forward

  echo
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if [[ "${FAIL}" -gt 0 ]]; then
    echo "RESULT: FAIL — fix failures before claiming S02 AC-01/AC-03"
    exit 1
  fi
  if [[ "${SKIP}" -gt 0 ]]; then
    echo "RESULT: PASS with skips — real wg / terminal QR may still need VPS follow-up (VPS-SMOKE.md)"
    exit 0
  fi
  echo "RESULT: PASS"
  exit 0
}

main "$@"
