#!/usr/bin/env bash
# Cross-compile nbvpn release binaries + SHA256 sidecars into dist/.
#
# Usage (from anywhere):
#   ./server/nbvpn/scripts/build-release.sh
#   ./server/nbvpn/scripts/build-release.sh amd64        # linux/amd64 only
#   ./server/nbvpn/scripts/build-release.sh amd64 arm64  # default if no args
#   ./server/nbvpn/scripts/build-release.sh windows      # windows/amd64 .exe (host Go — Win10+)
#   ./server/nbvpn/scripts/build-release.sh windows-2012 # needs Go 1.20 (prefer Docker script)
#   ./server/nbvpn/scripts/build-release.sh amd64 arm64 windows
#
# For reproducible Windows builds pinned by Go version, prefer:
#   ./server/nbvpn/scripts/build-windows-docker.sh [win2012|win10|all]
#
# Env:
#   VERSION   embedded via -ldflags (default 1.0.0; informational)
#   GOTOOLCHAIN  for windows-2012 default go1.20.14 if unset
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/dist"
VERSION="${VERSION:-1.0.0}"
TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(amd64 arm64)
fi

sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${f}"
  else
    shasum -a 256 "${f}"
  fi
}

mkdir -p "${DIST}"
cd "${ROOT}"

echo "==> go test ./..."
go test ./...

for target in "${TARGETS[@]}"; do
  case "${target}" in
    amd64|arm64|linux-amd64|linux-arm64)
      arch="${target#linux-}"
      out="nbvpn-linux-${arch}"
      echo "==> build linux/${arch} → dist/${out}"
      CGO_ENABLED=0 GOOS=linux GOARCH="${arch}" go build \
        -trimpath \
        -ldflags="-s -w -X main.version=${VERSION}" \
        -o "${DIST}/${out}" \
        .
      (
        cd "${DIST}"
        sha256_file "${out}" > "${out}.sha256"
      )
      echo "    $(cat "${DIST}/${out}.sha256")"
      ;;
    windows|windows-amd64|win64|win10)
      out="nbvpn-windows-amd64.exe"
      echo "==> build windows/amd64 (host Go; Win10+/Server 2016+) → dist/${out}"
      CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build \
        -trimpath \
        -ldflags="-s -w -X main.version=${VERSION}" \
        -o "${DIST}/${out}" \
        .
      (
        cd "${DIST}"
        sha256_file "${out}" > "${out}.sha256"
      )
      echo "    $(cat "${DIST}/${out}.sha256")"
      ;;
    windows-2012|win2012|server2012)
      # Go 1.21+ dropped Server 2012/R2. Build with Go 1.20.x only.
      # Prefer: ./scripts/build-windows-docker.sh win2012
      out="nbvpn-windows-amd64-win2012.exe"
      tc="${GOTOOLCHAIN:-go1.20.14}"
      echo "==> build windows/amd64 for Server 2012 (GOTOOLCHAIN=${tc}) → dist/${out}"
      echo "    note: host go.mod may say go 1.22; temporarily pin go 1.20 for this build"
      tmpmod="$(mktemp)"
      trap 'mv -f "${tmpmod}" "${ROOT}/go.mod" 2>/dev/null || true' EXIT
      cp "${ROOT}/go.mod" "${tmpmod}"
      # shellcheck disable=SC2016
      sed 's/^go .*/go 1.20/' "${ROOT}/go.mod" > "${ROOT}/go.mod.tmp"
      grep -v '^toolchain ' "${ROOT}/go.mod.tmp" > "${ROOT}/go.mod" || mv "${ROOT}/go.mod.tmp" "${ROOT}/go.mod"
      rm -f "${ROOT}/go.mod.tmp"
      GOTOOLCHAIN="${tc}" CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build \
        -trimpath \
        -ldflags="-s -w -X main.version=${VERSION}" \
        -o "${DIST}/${out}" \
        .
      mv -f "${tmpmod}" "${ROOT}/go.mod"
      trap - EXIT
      (
        cd "${DIST}"
        sha256_file "${out}" > "${out}.sha256"
      )
      echo "    $(cat "${DIST}/${out}.sha256")"
      ;;
    *)
      echo "error: unsupported target ${target} (want amd64|arm64|windows|windows-2012)" >&2
      exit 1
      ;;
  esac
done

echo "==> done. Artifacts in ${DIST}:"
ls -la "${DIST}"
