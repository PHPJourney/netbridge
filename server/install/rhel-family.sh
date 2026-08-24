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

# ELRepo kmod-wireguard on EL8 typically needs kernel >= 4.18.0-553.*
# Returns 0 if running kernel release number is below that floor.
el8_running_kernel_below_wireguard_min() {
  local rel
  rel="$(uname -r 2>/dev/null || true)"
  case "${rel}" in
    4.18.0-*)
      local num
      num="$(printf '%s' "${rel}" | sed -n 's/^4\.18\.0-\([0-9][0-9]*\).*/\1/p')"
      [[ -n "${num}" && "${num}" -lt 553 ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# True if a URL looks like a stale cloud / public CentOS mirror (not vault).
_is_stale_centos_mirror_url() {
  local u="$1"
  case "${u}" in
    *vault.centos.org*|*dl.rockylinux.org/vault/centos*)
      return 1
      ;;
  esac
  case "${u}" in
    *aliyun*|*aliyuncs*|*tencent*|*huaweicloud*|*huawei*|*qcloud*|*myhuaweicloud*)
      return 0
      ;;
    *mirrors.*centos*|*mirror.centos.org*|*mirror.stream.centos.org*|*mirrors.centos.org*)
      return 0
      ;;
    *mirrors.ustc.edu.cn/centos*|*mirrors.tuna.tsinghua.edu.cn/centos*|*mirrors.bfsu.edu.cn/centos*)
      return 0
      ;;
    *://mirrors.*/centos*|*://mirror.*/centos*)
      return 0
      ;;
  esac
  return 1
}

# Collect CentOS / Stream / cloud-vendor centos repo files that must be rewritten.
# Prints absolute paths (one per line).
list_centos_repo_files() {
  local f
  shopt -s nullglob
  for f in \
    /etc/yum.repos.d/CentOS-*.repo \
    /etc/yum.repos.d/CentOS-Stream-*.repo \
    /etc/yum.repos.d/centos*.repo \
    /etc/yum.repos.d/*aliyun*.repo \
    /etc/yum.repos.d/*aliyuncs*.repo \
    /etc/yum.repos.d/*tencent*.repo \
    /etc/yum.repos.d/*huawei*.repo \
    /etc/yum.repos.d/*qcloud*.repo \
    /etc/yum.repos.d/*mirrors*.repo \
    /etc/yum.repos.d/*centos*.repo; do
    [[ -f "${f}" ]] || continue
    # Only touch files that look CentOS-related (avoid unrelated *mirrors* repos).
    if [[ "$(basename "${f}")" == [Cc]ent[Oo][Ss]* ]] || \
       grep -qiE 'centos|aliyun.*/centos|mirrors\..*/centos|stream\.centos' "${f}" 2>/dev/null; then
      printf '%s\n' "${f}"
    fi
  done
  shopt -u nullglob
}

# Rewrite one .repo file toward vault (Stream 8 or CentOS Linux 8).
_rewrite_one_repo_to_vault() {
  local f="$1"
  local tmp stream_flag=0
  tmp="$(mktemp)"
  [[ "${IS_CENTOS_STREAM}" == "1" ]] && stream_flag=1

  awk -v stream="${stream_flag}" '
  function vault_stream_prefix() { return "https://vault.centos.org/centos/8-stream/" }
  function is_already_vault(u) {
    return (u ~ /vault\.centos\.org/ || u ~ /dl\.rockylinux\.org\/vault\/centos/)
  }
  function rewrite_stream_url(u,   rest, p) {
    # .../(centos-stream|centos)/($stream-stream|$contentdir/$stream-stream|8-stream)/REST
    if (match(u, /\/centos-stream\/\$stream-stream\//) ||
        match(u, /\/centos\/\$stream-stream\//) ||
        match(u, /\/centos\/\$contentdir\/\$stream-stream\//) ||
        match(u, /\/centos-stream\/8-stream\//) ||
        match(u, /\/centos\/8-stream\//)) {
      rest = substr(u, RSTART + RLENGTH)
      return vault_stream_prefix() rest
    }
    if (match(u, /\/\$stream-stream\//)) {
      rest = substr(u, RSTART + RLENGTH)
      return vault_stream_prefix() rest
    }
    # Last resort: keep path from BaseOS/AppStream/... onward
    p = index(u, "/BaseOS/")
    if (p == 0) p = index(u, "/AppStream/")
    if (p == 0) p = index(u, "/extras/")
    if (p == 0) p = index(u, "/PowerTools/")
    if (p == 0) p = index(u, "/powertools/")
    if (p > 0) {
      rest = substr(u, p + 1)
      return vault_stream_prefix() rest
    }
    return ""
  }
  function rewrite_linux8_url(u,   rest, p) {
    if (is_already_vault(u)) return u
    if (match(u, /^https?:\/\/mirror\.centos\.org/)) {
      sub(/^https?:\/\/mirror\.centos\.org/, "https://vault.centos.org", u)
      return u
    }
    if (match(u, /\/centos\/\$releasever\//) || match(u, /\/centos\/\$contentdir\/\$releasever\//)) {
      rest = substr(u, RSTART + 1)  # centos/$releasever/...
      return "https://vault.centos.org/" rest
    }
    p = index(u, "/BaseOS/")
    if (p == 0) p = index(u, "/AppStream/")
    if (p == 0) p = index(u, "/extras/")
    if (p > 0) {
      rest = substr(u, p + 1)
      return "https://vault.centos.org/centos/$releasever/" rest
    }
    return u
  }
  /^metalink=/ { print "#" $0; next }
  /^mirrorlist=/ { print "#" $0; next }
  /^#?baseurl=/ {
    line = $0
    sub(/^#/, "", line)
    url = line
    sub(/^baseurl=/, "", url)
    if (is_already_vault(url)) {
      print "baseurl=" url
      next
    }
    if (stream == 1) {
      n = rewrite_stream_url(url)
      if (n != "") { print "baseurl=" n; next }
      print "#" line
      next
    }
    print "baseurl=" rewrite_linux8_url(url)
    next
  }
  { print }
  ' "${f}" >"${tmp}"
  mv -f "${tmp}" "${f}"

  # If still no active baseurl, inject known Stream / Linux vault section URLs.
  if ! grep -qE '^baseurl=' "${f}"; then
    local inj_tmp
    inj_tmp="$(mktemp)"
    if [[ "${IS_CENTOS_STREAM}" == "1" ]]; then
      awk '
        BEGIN{b=0; a=0; e=0}
        {
          print
          low=tolower($0)
          if (low ~ /^\[.*baseos/ && !b) {
            print "baseurl=https://vault.centos.org/centos/8-stream/BaseOS/$basearch/os/"
            b=1
          } else if (low ~ /^\[.*appstream/ && !a) {
            print "baseurl=https://vault.centos.org/centos/8-stream/AppStream/$basearch/os/"
            a=1
          } else if (low ~ /^\[.*extras/ && !e) {
            print "baseurl=https://vault.centos.org/centos/8-stream/extras/$basearch/os/"
            e=1
          }
        }
      ' "${f}" >"${inj_tmp}"
    else
      awk '
        BEGIN{b=0; a=0}
        {
          print
          low=tolower($0)
          if (low ~ /^\[.*baseos/ && !b) {
            print "baseurl=https://vault.centos.org/centos/$releasever/BaseOS/$basearch/os/"
            b=1
          } else if (low ~ /^\[.*appstream/ && !a) {
            print "baseurl=https://vault.centos.org/centos/$releasever/AppStream/$basearch/os/"
            a=1
          }
        }
      ' "${f}" >"${inj_tmp}"
    fi
    mv -f "${inj_tmp}" "${f}"
  fi
}

# Disable sections whose baseurl still points at stale cloud centos mirrors
# after rewrite (duplicate vendor overlays that would otherwise win in dnf).
_disable_stale_centos_sections() {
  local f="$1"
  local tmp line section="" stale=0 has_en=0 touched=0
  tmp="$(mktemp)"
  _flush_section() {
    if [[ -z "${section}" ]]; then
      return 0
    fi
    if [[ "${stale}" -eq 1 ]]; then
      touched=1
      if [[ "${has_en}" -eq 1 ]]; then
        printf '%s\n' "${section}" | sed -E 's/^enabled=1$/enabled=0/' >>"${tmp}"
      else
        printf '%s\nenabled=0\n' "${section}" >>"${tmp}"
      fi
    else
      printf '%s\n' "${section}" >>"${tmp}"
    fi
    section=""
    stale=0
    has_en=0
  }
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == \[* ]]; then
      _flush_section
      section="${line}"
      continue
    fi
    if [[ -z "${section}" ]]; then
      printf '%s\n' "${line}" >>"${tmp}"
      continue
    fi
    section="${section}"$'\n'"${line}"
    [[ "${line}" == enabled=* ]] && has_en=1
    if [[ "${line}" == baseurl=* ]] && _is_stale_centos_mirror_url "${line#baseurl=}"; then
      stale=1
    fi
  done <"${f}"
  _flush_section
  if [[ "${touched}" -eq 1 ]]; then
    warn "disabled stale mirror section(s) in $(basename "${f}") (still pointed at cloud/CDN centos)"
  fi
  mv -f "${tmp}" "${f}"
}

# Print baseurls dnf/yum will use for BaseOS / AppStream (best-effort).
print_kernel_repo_baseurls() {
  log "effective repo sources for kernel / BaseOS / AppStream:"
  local mgr out
  mgr="$(_pkg_mgr)"
  set +e
  if [[ "${mgr}" == "dnf" ]]; then
    out="$(dnf -q repolist -v 2>/dev/null | grep -E 'Repo-id|Repo-baseurl|Repo-name|Repo-status' || true)"
  else
    out="$(yum repolist -v 2>/dev/null | grep -E 'Repo-id|Repo-baseurl|Repo-name|Repo-status' || true)"
  fi
  set -e
  if [[ -n "${out}" ]]; then
    printf '%s\n' "${out}" | head -n 80
  else
    # Fallback: scrape enabled baseurl lines from .repo files we touched.
    local f
    while IFS= read -r f; do
      [[ -f "${f}" ]] || continue
      awk '
        /^\[/ { sec=$0; en=1; next }
        /^enabled[[:space:]]*=[[:space:]]*0/ { en=0 }
        /^enabled[[:space:]]*=[[:space:]]*1/ { en=1 }
        /^baseurl=/ && en { print FILENAME ": " sec " " $0 }
      ' "${f}" 2>/dev/null || true
    done < <(list_centos_repo_files) | head -n 40
  fi
}

# Return 0 if enabled BaseOS/AppStream-like baseurls look like vault (not aliyun/CDN).
verify_vault_repos_not_stale() {
  local bad=0 line url
  # Prefer live dnf view when available.
  local mgr urls=""
  mgr="$(_pkg_mgr)"
  set +e
  if [[ "${mgr}" == "dnf" ]]; then
    urls="$(dnf -q repoinfo 2>/dev/null | awk '
      BEGIN{id="";}
      /^Repo-id[[:space:]]*:/ {id=$3}
      /^Repo-baseurl[[:space:]]*:/ {
        u=$0; sub(/^Repo-baseurl[[:space:]]*:[[:space:]]*/,"",u);
        if (id ~ /(baseos|appstream|BaseOS|AppStream|extras)/) print u;
      }
    ' || true)"
  fi
  set -e
  if [[ -z "${urls}" ]]; then
    local f
    while IFS= read -r f; do
      [[ -f "${f}" ]] || continue
      while IFS= read -r line; do
        urls="${urls}"$'\n'"${line}"
      done < <(awk '
        /^\[/ { en=1 }
        /^enabled[[:space:]]*=[[:space:]]*0/ { en=0 }
        /^enabled[[:space:]]*=[[:space:]]*1/ { en=1 }
        /^baseurl=/ && en { sub(/^baseurl=/,"",$0); print }
      ' "${f}" 2>/dev/null || true)
    done < <(list_centos_repo_files)
  fi
  while IFS= read -r url; do
    [[ -z "${url}" ]] && continue
    if _is_stale_centos_mirror_url "${url}"; then
      warn "stale CentOS mirror still enabled: ${url}"
      bad=1
    fi
  done <<<"${urls}"
  if [[ "${bad}" -eq 1 ]]; then
    return 1
  fi
  return 0
}

print_centos8_migrate_help() {
  local kver backup_hint=""
  kver="$(uname -r 2>/dev/null || echo unknown)"
  [[ -n "${NBVPN_REPO_BACKUP}" ]] && backup_hint="  Repo backup: ${NBVPN_REPO_BACKUP}"
  cat >&2 <<EOF
error: 当前镜像无可用内核升级，nbvpn 无法在此内核启用 WireGuard。

  Running kernel: ${kver}
  OS: ${OS_ID} ${OS_VERSION}$([[ "${IS_CENTOS_STREAM}" == "1" ]] && echo ' (CentOS Stream)')
  ELRepo kmod-wireguard typically needs: kernel >= 4.18.0-553.el8_10
${backup_hint}

  原因：CentOS Stream 8 / CentOS Linux 8 已 EOL。云厂商（阿里云等）镜像常冻结在旧内核
  （如 4.18.0-408），即便脚本已切 vault，若元数据仍无 ≥553 内核，无法自愈。
  Do NOT use --skip-broken。

  推荐：迁移到 Rocky Linux 8（最短路径）后重跑安装：

    # 1) 确认已可访问 vault（本脚本会备份并改写 repos；若需手动）：
    #    BaseOS:  https://vault.centos.org/centos/8-stream/BaseOS/\$basearch/os/
    #    或 Rocky 镜像: https://dl.rockylinux.org/vault/centos/8-stream/BaseOS/\$basearch/os/

    # 2) migrate2rocky
    curl -fLO https://raw.githubusercontent.com/rocky-linux/rocky-tools/main/migrate2rocky/migrate2rocky.sh
    chmod +x migrate2rocky.sh
    sudo ./migrate2rocky.sh -r

    # 3) reboot，再装 nbvpn
    sudo reboot
    curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/install.sh | sudo bash

  备选：AlmaLinux 8/9（almalinux-deploy）同样可用。
  Docs: server/install/LINUX-PREFLIGHT.md  |  FIREWALL.md §7
EOF
}

# Rewrite CentOS (Stream or Linux) repos to vault.centos.org, including common
# cloud-vendor overlays (*aliyun*, *mirrors*, …). Verify effective baseurls.
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
  if [[ "${IS_CENTOS_STREAM}" == "1" ]]; then
    log "switching CentOS Stream repos toward vault.centos.org/centos/8-stream/ (EOL remediation)"
  else
    log "switching CentOS Linux repos toward vault.centos.org (EOL remediation)"
  fi

  local f count=0
  while IFS= read -r f; do
    [[ -f "${f}" ]] || continue
    log "rewriting repo file: ${f}"
    _rewrite_one_repo_to_vault "${f}"
    _disable_stale_centos_sections "${f}"
    count=$((count + 1))
  done < <(list_centos_repo_files | sort -u)

  if [[ "${count}" -eq 0 ]]; then
    warn "no CentOS/cloud centos .repo files found under /etc/yum.repos.d"
  else
    log "rewrote ${count} repo file(s)"
  fi

  _pkg clean all >/dev/null 2>&1 || true
  if rhel_repos_reachable; then
    log "vault / repo metadata OK after rewrite"
  else
    warn "repos still unreachable after vault rewrite — restore from ${NBVPN_REPO_BACKUP} if needed"
  fi

  print_kernel_repo_baseurls
  if ! verify_vault_repos_not_stale; then
    warn "enabled BaseOS/AppStream still reference cloud/CDN centos mirrors — vault switch incomplete"
    warn "dnf may keep serving frozen kernels (e.g. from mirrors.aliyun.com). Prefer Rocky/Alma migrate."
    return 1
  fi
  log "verified: no stale cloud/CDN centos baseurls for enabled BaseOS/AppStream-like repos"
  return 0
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
    CentOS Stream 8 / CentOS Linux 8 are EOL. Cloud mirrors (Aliyun etc.) often
    freeze old kernels. ELRepo kmod-wireguard typically needs:
      kernel >= 4.18.0-553.el8_10
    Older kernels (e.g. 4.18.0-408.el8) cannot load current kmod-wireguard.
    Do NOT use --skip-broken.
    Historical ELRepo kmods for arbitrary old Stream kernels are unreliable
    (kABI) — nbvpn will not force them.

  Fix options:
    1) Reboot if a newer kernel was installed, then re-run this script
    2) Ensure repos use vault.centos.org (not mirrors.aliyun.com), update kernel, reboot
       (see server/install/LINUX-PREFLIGHT.md)
    3) Migrate to Rocky Linux 8/9 or AlmaLinux 8/9, then re-run the installer
       (recommended when vault/cloud mirrors have no ≥553 kernel)

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

  local major="${OS_VERSION%%.*}"
  local vault_switched=0
  local vault_ok=1

  # 1) CentOS 8 / Stream EOL: switch vault first (incl. cloud vendor overlays),
  #    so kernel update does not keep reading frozen Aliyun/CDN trees.
  if [[ "${OS_ID}" == "centos" && "${major}" == "8" ]]; then
    log "CentOS 8 / Stream EOL — switching repos to vault before kernel update"
    if switch_centos_vault_repos; then
      vault_switched=1
      vault_ok=1
    else
      vault_switched=1
      vault_ok=0
      warn "vault switch did not fully displace cloud/CDN centos mirrors"
    fi
  fi

  # 2) Kernel update from (hopefully) vault repos
  try_update_kernel_packages

  # 3) If still no packages and we have not switched yet, try once; if already
  #    switched and still Nothing to do on old kernel → fast fail (no empty yum loop).
  if [[ "${KERNEL_UPDATE_HAD_PACKAGES}" != "1" && "${OS_ID}" == "centos" && "${major}" == "8" ]]; then
    if [[ "${vault_switched}" != "1" ]]; then
      log "no kernel updates from current repos — trying CentOS vault mirrors"
      switch_centos_vault_repos || vault_ok=0
      vault_switched=1
      try_update_kernel_packages
    fi
    if [[ "${KERNEL_UPDATE_HAD_PACKAGES}" != "1" ]] && el8_running_kernel_below_wireguard_min; then
      if [[ "${vault_ok}" != "1" ]]; then
        err "vault 换源未能覆盖云厂商镜像，且内核仍无升级（running=$(uname -r) < 553）— 无法自愈，请迁 Rocky/Alma"
      fi
      print_centos8_migrate_help
      err "当前镜像无可用内核升级，nbvpn 无法在此内核启用 WireGuard（running=$(uname -r)）"
    fi
  fi

  # 4) Newer kernel installed but not running → must reboot before kmod can match
  if kernel_reboot_pending; then
    print_reboot_required_bilingual
    exit 1
  fi

  # 5) Install elrepo kmod for the running kernel (current ELRepo only; no
  #    historical Stream kABI guesswork — prefer honest failure + migrate).
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

  # 7) CentOS 8 old kernel + no update path → migrate guidance (not fake success)
  if [[ "${OS_ID}" == "centos" && "${major}" == "8" ]] && el8_running_kernel_below_wireguard_min; then
    print_centos8_migrate_help
    err "当前镜像无可用内核升级，nbvpn 无法在此内核启用 WireGuard（running=$(uname -r)）"
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
