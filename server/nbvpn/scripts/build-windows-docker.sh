#!/usr/bin/env bash
# Build Windows nbvpn binaries via pinned golang Docker images (reproducible on Mac).
#
# Targets:
#   win2012  → dist/nbvpn-windows-amd64-win2012.exe  (Go 1.20 — Server 2012 R2)
#   win10    → dist/nbvpn-windows-amd64.exe          (Go 1.22+ — Win10 / Server 2016+)
#   all      → both (default)
#
# Usage:
#   ./server/nbvpn/scripts/build-windows-docker.sh
#   ./server/nbvpn/scripts/build-windows-docker.sh win2012
#   ./server/nbvpn/scripts/build-windows-docker.sh win10
#   ./server/nbvpn/scripts/build-windows-docker.sh all
#
# Env:
#   GO_WIN2012_IMAGE  default golang:1.20.14
#   GO_WIN10_IMAGE    default golang:1.22.10
#   VERSION           ldflags version (default 1.0.0)
#   SKIP_PULL=1       skip docker pull
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "${ROOT}/../.." && pwd)"
DIST="${ROOT}/dist"
VERSION="${VERSION:-1.0.0}"
GO_WIN2012_IMAGE="${GO_WIN2012_IMAGE:-golang:1.20.14}"
GO_WIN10_IMAGE="${GO_WIN10_IMAGE:-golang:1.22.10}"

TARGET="${1:-all}"

sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${f}"
  else
    shasum -a 256 "${f}"
  fi
}

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker not found" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "error: docker daemon not running (start Docker Desktop)" >&2
    exit 1
  fi
}

host_gomodcache() {
  if command -v go >/dev/null 2>&1; then
    go env GOMODCACHE
  else
    echo "${HOME}/go/pkg/mod"
  fi
}

host_gocache() {
  if command -v go >/dev/null 2>&1; then
    go env GOCACHE
  else
    echo "${HOME}/Library/Caches/go-build"
  fi
}

pull_image() {
  local img="$1"
  if [[ "${SKIP_PULL:-0}" == "1" ]]; then
    return 0
  fi
  echo "==> docker pull ${img}"
  docker pull "${img}"
}

# Run go build in image. For Go 1.20, rewrite go.mod directive inside the
# container only (host go.mod stays at 1.22+ for normal development).
docker_go_build() {
  local image="$1"
  local out_name="$2"
  local go_mod_line="$3" # e.g. "1.20" or "1.22"

  echo "==> docker ${image} → dist/${out_name}"
  mkdir -p "${DIST}"

  local modcache gocache
  modcache="$(host_gomodcache)"
  gocache="$(host_gocache)"
  mkdir -p "${modcache}" "${gocache}"

  # Mount host module/build caches so the container need not hit proxy.golang.org
  # (common timeout on some networks). GOPROXY can still be overridden via env.
  docker run --rm \
    -v "${REPO}:/src" \
    -v "${modcache}:/go/pkg/mod" \
    -v "${gocache}:/root/.cache/go-build" \
    -w /src/server/nbvpn \
    -e "CGO_ENABLED=0" \
    -e "GOOS=windows" \
    -e "GOARCH=amd64" \
    -e "GOPROXY=${GOPROXY:-https://proxy.golang.org,direct}" \
    -e "GOSUMDB=${GOSUMDB:-sum.golang.org}" \
    "${image}" \
    bash -c "
      set -euo pipefail
      # Pin go directive for this toolchain without dirtying the bind-mounted tree permanently:
      # work on a copy in /tmp then write only the output binary back to dist/.
      rm -rf /tmp/nbvpn-build
      mkdir -p /tmp/nbvpn-build
      # Copy module sources (exclude dist to avoid huge copies of prior artifacts)
      tar -C /src/server/nbvpn --exclude=dist --exclude=.git -cf - . | tar -C /tmp/nbvpn-build -xf -
      cd /tmp/nbvpn-build
      if grep -q '^go ' go.mod; then
        sed -i 's/^go .*/go ${go_mod_line}/' go.mod
      else
        echo 'go ${go_mod_line}' >> go.mod
      fi
      # Drop toolchain directive if present (Go 1.20 cannot parse it)
      sed -i '/^toolchain /d' go.mod || true
      # Prefer already-cached modules; avoid network if possible
      export GOFLAGS='-mod=readonly'
      if ! go build -trimpath -ldflags='-s -w -X main.version=${VERSION}' -o '/src/server/nbvpn/dist/${out_name}' .; then
        echo '    note: -mod=readonly failed; retrying with module download' >&2
        export GOFLAGS='-mod=mod'
        go build -trimpath -ldflags='-s -w -X main.version=${VERSION}' -o '/src/server/nbvpn/dist/${out_name}' .
      fi
    "

  (
    cd "${DIST}"
    sha256_file "${out_name}" > "${out_name}.sha256"
  )
  echo "    $(cat "${DIST}/${out_name}.sha256")"
  if command -v file >/dev/null 2>&1; then
    file "${DIST}/${out_name}" || true
  fi
}

need_docker
mkdir -p "${DIST}"

case "${TARGET}" in
  win2012|2012|server2012)
    pull_image "${GO_WIN2012_IMAGE}"
    docker_go_build "${GO_WIN2012_IMAGE}" "nbvpn-windows-amd64-win2012.exe" "1.20"
    ;;
  win10|win|windows|modern)
    pull_image "${GO_WIN10_IMAGE}"
    docker_go_build "${GO_WIN10_IMAGE}" "nbvpn-windows-amd64.exe" "1.22"
    ;;
  all)
    pull_image "${GO_WIN2012_IMAGE}"
    pull_image "${GO_WIN10_IMAGE}"
    docker_go_build "${GO_WIN2012_IMAGE}" "nbvpn-windows-amd64-win2012.exe" "1.20"
    docker_go_build "${GO_WIN10_IMAGE}" "nbvpn-windows-amd64.exe" "1.22"
    ;;
  *)
    echo "usage: $0 [win2012|win10|all]" >&2
    exit 1
    ;;
esac

echo "==> done. Artifacts in ${DIST}:"
ls -la "${DIST}"/nbvpn-windows-amd64*.exe* 2>/dev/null || ls -la "${DIST}"
