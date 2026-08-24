#!/usr/bin/env bash
# NetBridge VPN — RHEL / CentOS / Rocky / Alma family installer (dnf/yum + WireGuard).
#
# Usage (as root):
#   sudo ./server/install/rhel-family.sh
#   sudo ./server/install/centos.sh
#   sudo ./server/install/rhel.sh
#
# Env: NBVPN_VERSION, NBVPN_BINARY_URL, INSTALL_BIN_DIR, NBVPN_SKIP_INSTALL, NBVPN_DATA_DIR
#      NBVPN_SKIP_PREFLIGHT_REPOS, NBVPN_SKIP_KERNEL_UPDATE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "${SCRIPT_DIR}/_common.sh"

NBVPN_REPO_BACKUP=""

_pkg_mgr() {
  if command -v dnf >/dev/null 2>&1; then
    echo dnf
  else
    echo yum
  fi
}

_pkg() {
  local mgr
  mgr="$(_pkg_mgr)"
  if [[ "${mgr}" == "dnf" ]]; then
    dnf "$@"
  else
    yum "$@"
  fi
}

# Backup /etc/yum.repos.d before any rewrite (restore path printed on failure).
backup_yum_repos() {
  if [[ -n "${NBVPN_REPO_BACKUP}" && -d "${NBVPN_REPO_BACKUP}" ]]; then
    return 0
  fi
  local stamp
  stamp="$(date +%Y%m%d%H%M%S)"
  NBVPN_REPO_BACKUP="/etc/yum.repos.d.nbvpn-backup.${stamp}"
  cp -a /etc/yum.repos.d "${NBVPN_REPO_BACKUP}"
  log "backed up yum/dnf repos → ${NBVPN_REPO_BACKUP}"
}

# Quick check: can the package manager reach metadata?
rhel_repos_reachable() {
  local mgr
  mgr="$(_pkg_mgr)"
  if [[ "${mgr}" == "dnf" ]]; then
    dnf -q makecache --timer >/dev/null 2>&1 || dnf -q check-update >/dev/null 2>&1 || return 1
  else
    yum -q makecache >/dev/null 2>&1 || return 1
  fi
  return 0
}

# Rewrite CentOS (Stream or Linux) repos to vault.centos.org. Custom third-party
# .repo files are left untouched; only CentOS/Stream files are edited.
switch_centos_vault_repos() {
  if [[ "${NBVPN_SKIP_PREFLIGHT_REPOS:-0}" == "1" ]]; then
    log "NBVPN_SKIP_PREFLIGHT_REPOS=1 — skipping vault mirror switch"
    return 0
  fi
  case "${OS_ID}" in
    centos) ;;
    *)
      warn "vault switch is only applied for CentOS / CentOS Stream (OS_ID=${OS_ID})"
      return 0
      ;;
  esac

  backup_yum_repos
  log "switching CentOS repos toward vault.centos.org (EOL remediation)"

  local f
  shopt -s nullglob
  for f in /etc/yum.repos.d/CentOS-*.repo /etc/yum.repos.d/centos*.repo \
           /etc/yum.repos.d/CentOS-Stream-*.repo; do
    [[ -f "${f}" ]] || continue
    # Disable metalink / mirrorlist so stale CDN trees are not used.
    sed -i \
      -e 's/^metalink=/#metalink=/g' \
      -e 's/^mirrorlist=/#mirrorlist=/g' \
      "${f}"

    if [[ "${IS_CENTOS_STREAM}" == "1" ]]; then
      # Stream 8 vault layout: https://vault.centos.org/centos/8-stream/...
      sed -i \
        -e 's|^#*baseurl=https\?://mirror\.stream\.centos\.org/\$stream-stream/|baseurl=https://vault.centos.org/centos/8-stream/|g' \
        -e 's|^#*baseurl=https\?://mirror\.centos\.org/\$contentdir/\$releasever/|baseurl=https://vault.centos.org/centos/8-stream/|g' \
        -e 's|^#*baseurl=https\?://mirror\.centos\.org/centos/\$releasever/|baseurl=https://vault.centos.org/centos/8-stream/|g' \
        "${f}"
      # If still no active baseurl lines, inject common Stream vault URLs for known sections.
      if ! grep -qE '^baseurl=' "${f}"; then
        if grep -q '\[baseos\]' "${f}" 2>/dev/null; then
          sed -i '/\[baseos\]/a baseurl=https://vault.centos.org/centos/8-stream/BaseOS/$basearch/os/' "${f}"
        fi
        if grep -q '\[appstream\]' "${f}" 2>/dev/null; then
          sed -i '/\[appstream\]/a baseurl=https://vault.centos.org/centos/8-stream/AppStream/$basearch/os/' "${f}"
        fi
        if grep -q '\[extras\]' "${f}" 2>/dev/null; then
          sed -i '/\[extras\]/a baseurl=https://vault.centos.org/centos/8-stream/extras/$basearch/os/' "${f}"
        fi
      fi
    else
      # CentOS Linux 8 classic vault rewrite
      sed -i \
        -e 's|^#*baseurl=http://mirror\.centos\.org|baseurl=http://vault.centos.org|g' \
        -e 's|^#*baseurl=https://mirror\.centos\.org|baseurl=https://vault.centos.org|g' \
        "${f}"
    fi
  done
  shopt -u nullglob

  _pkg clean all >/dev/null 2>&1 || true
  if rhel_repos_reachable; then
    log "vault / repo metadata OK after rewrite"
  else
    warn "repos still unreachable after vault rewrite — restore from ${NBVPN_REPO_BACKUP} if needed"
  fi
}

# Attempt kernel package update. Sets KERNEL_UPDATE_HAD_PACKAGES=0|1
try_update_kernel_packages() {
  KERNEL_UPDATE_HAD_PACKAGES=0
  if [[ "${NBVPN_SKIP_KERNEL_UPDATE:-0}" == "1" ]]; then
    log "NBVPN_SKIP_KERNEL_UPDATE=1 — skipping kernel update"
    return 0
  fi

  local before after out rc
  before="$(rpm -q kernel kernel-core 2>/dev/null | sort -V | tr '\n' ' ' || true)"
  log "attempting kernel package update (running=$(uname -r))"
  set +e
  out="$(_pkg update -y kernel kernel-core kernel-modules 2>&1)"
  rc=$?
  set -e
  printf '%s\n' "${out}" | tail -n 40
  after="$(rpm -q kernel kernel-core 2>/dev/null | sort -V | tr '\n' ' ' || true)"

  if [[ "${before}" != "${after}" ]]; then
    KERNEL_UPDATE_HAD_PACKAGES=1
    log "kernel packages changed"
  elif echo "${out}" | grep -qiE 'Nothing to do|No packages marked for update|already installed|无需任何处理'; then
    log "no kernel updates available from current repos (Nothing to do)"
  elif [[ "${rc}" -ne 0 ]]; then
    warn "kernel update command exited ${rc}"
  else
    log "kernel update finished with no package set change"
  fi
}

ensure_elrepo_kmod() {
  local major=""
  major="${OS_VERSION%%.*}"
  case "${OS_ID}" in
    centos|rhel|rocky|almalinux)
      if [[ "${major}" == "8" || "${major}" == "7" ]]; then
        log "EL${major}: ensuring epel / elrepo / kmod-wireguard (match running kernel)"
        _pkg install -y epel-release || true
        _pkg install -y elrepo-release || \
          _pkg install -y "https://www.elrepo.org/elrepo-release-${major}.el${major}.elrepo.noarch.rpm" || true

        local out rc
        set +e
        out="$(_pkg install -y kmod-wireguard 2>&1)"
        rc=$?
        if [[ "${rc}" -ne 0 ]]; then
          out="${out}"$'\n'"$(_pkg install -y --enablerepo=elrepo kmod-wireguard 2>&1)"
          rc=$?
        fi
        set -e
        printf '%s\n' "${out}" | tail -n 30

        if [[ "${rc}" -ne 0 ]]; then
          if echo "${out}" | grep -qiE 'conflict|requires|nothing provides|protected package|problem with installed package'; then
            warn "kmod-wireguard install conflict/requirement failure (often needs newer kernel + reboot)"
          else
            warn "kmod-wireguard install failed (rc=${rc})"
          fi
          return 1
        fi
      fi
      ;;
  esac
  return 0
}

print_wireguard_kernel_fail_help() {
  local kver
  kver="$(uname -r 2>/dev/null || echo unknown)"
  local backup_hint=""
  [[ -n "${NBVPN_REPO_BACKUP}" ]] && backup_hint="  Repo backup: ${NBVPN_REPO_BACKUP}"
  cat >&2 <<EOF
error: kernel cannot create WireGuard interfaces (Unknown device type / Protocol not supported).

  Running kernel: ${kver}
  (modprobe wireguard failed — module not in /lib/modules/${kver})
  OS: ${OS_ID} ${OS_VERSION}$([[ "${IS_CENTOS_STREAM}" == "1" ]] && echo ' (CentOS Stream)')
${backup_hint}

  Diagnosis:
    uname -r
    lsmod | grep wireguard
    sudo modprobe wireguard
    sudo ip link add nbvpn type wireguard   # fails → missing kmod

  Why yum/dnf update kernel may show "Nothing to do":
    CentOS Stream 8 / CentOS Linux 8 are EOL — default mirrors often have
    no newer kernel. ELRepo kmod-wireguard typically needs:
      kernel >= 4.18.0-553.el8_10
    Older kernels (e.g. 4.18.0-408.el8) cannot load current kmod-wireguard.
    Do NOT use --skip-broken.

  Fix options:
    1) Reboot if a newer kernel was installed, then re-run this script
    2) Manually point repos at vault.centos.org, update kernel, reboot, install kmod
       (see server/install/LINUX-PREFLIGHT.md)
    3) Migrate to Rocky Linux 8/9 or AlmaLinux 8/9, then re-run the installer

  Docs: server/install/LINUX-PREFLIGHT.md  |  FIREWALL.md §7
EOF
}

# Full remediation: repos → kernel update → elrepo kmod → verify.
remediate_wireguard_rhel() {
  if wireguard_kernel_ok; then
    log "WireGuard kernel support already OK"
    return 0
  fi

  log "WireGuard kernel module missing — starting environment remediation"

  # 1) If mirrors look dead / CentOS EOL, try vault first so kernel update can work.
  local major="${OS_VERSION%%.*}"
  if [[ "${OS_ID}" == "centos" && "${major}" == "8" ]]; then
    if ! rhel_repos_reachable; then
      warn "package repos unreachable — attempting vault switch"
      switch_centos_vault_repos
    fi
  fi

  # 2) Kernel update from current repos
  try_update_kernel_packages

  # 3) If no kernel packages arrived on CentOS 8, switch vault and retry once
  if [[ "${KERNEL_UPDATE_HAD_PACKAGES}" != "1" && "${OS_ID}" == "centos" && "${major}" == "8" ]]; then
    log "no kernel updates from current repos — trying CentOS vault mirrors"
    switch_centos_vault_repos
    try_update_kernel_packages
  fi

  # 4) Newer kernel installed but not running → must reboot before kmod can match
  if kernel_reboot_pending; then
    print_reboot_required_bilingual
    exit 1
  fi

  # 5) Install elrepo kmod for the running kernel
  ensure_elrepo_kmod || true

  if wireguard_kernel_ok; then
    log "WireGuard kernel support OK after remediation"
    return 0
  fi

  # 6) Still failing — if packages claim a newer kernel exists, insist on reboot
  if kernel_reboot_pending; then
    print_reboot_required_bilingual
    exit 1
  fi

  print_wireguard_kernel_fail_help
  err "WireGuard kernel module missing after remediation — refusing to pretend install succeeded"
}

install_wireguard_rhel() {
  log "installing WireGuard tools (dnf/yum) — environment adaptation"
  _pkg install -y epel-release || true
  _pkg install -y curl ca-certificates iproute || true
  _pkg install -y wireguard-tools curl ca-certificates iproute || \
    _pkg install -y wireguard-tools curl ca-certificates iproute || true

  if ! command -v wg-quick >/dev/null 2>&1; then
    err "wireguard-tools not available from repos; fix mirrors or install manually then re-run"
  fi

  remediate_wireguard_rhel
  ensure_wireguard_kernel
}

main() {
  preflight_linux
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
  case "${PKG_FAMILY}" in
    dnf|yum) ;;
    *)
      warn "expected dnf/yum but PKG_FAMILY=${PKG_FAMILY}"
      ;;
  esac
  install_wireguard_rhel
  require_cmd wg
  require_cmd wg-quick
  log "wg=$(command -v wg)  wg-quick=$(command -v wg-quick)"
  nbvpn_install_finish
  verify_nbvpn_on_path
}

main "$@"
