#!/usr/bin/env bash
# Thin wrapper → rhel-family.sh (CentOS / Rocky / Alma).
# One-liner (mock CDN example):
#   curl -fsSL …/servers/centos/centos.sh | sudo bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/rhel-family.sh" "$@"
