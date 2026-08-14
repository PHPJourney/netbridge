#!/usr/bin/env bash
# Thin wrapper — full multi-platform packaging lives in package-all.sh
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package-all.sh" "$@"
