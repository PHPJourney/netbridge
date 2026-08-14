#!/usr/bin/env bash
# Thin wrapper → deb-family.sh (Debian).
# One-liner (mock CDN example):
#   curl -fsSL …/servers/debian/debian.sh | sudo bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/deb-family.sh" "$@"
