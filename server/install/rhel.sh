#!/usr/bin/env bash
# Thin wrapper → rhel-family.sh (RHEL / Rocky / Alma). Preflight + epel/elrepo/kmod remediation.
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/PHPJourney/netbridge/main/server/install/rhel.sh | sudo bash
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

nbvpn_bootstrap_ensure_dir rhel
exec bash "${NBVPN_INSTALL_DIR}/rhel-family.sh" "$@"
