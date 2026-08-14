#!/usr/bin/env bash
# After artifacts exist on OpenList, fill apps/store/public/releases.json.
# Does NOT upload. Does NOT invent URLs — you pass real paths.
#
# Usage examples:
#   ./scripts/update-releases-urls.sh --print-template
#   ./scripts/update-releases-urls.sh \
#     --linux-amd64-url 'http://154.37.213.245:5244/d/store/VPN/nbvpn/nbvpn-linux-amd64' \
#     --linux-amd64-sha '...' \
#     --install-sh-url 'http://154.37.213.245:5244/d/store/VPN/nbvpn/install.sh'
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASES="${ROOT}/apps/store/public/releases.json"
OPENLIST_BASE="${OPENLIST_BASE:-http://154.37.213.245:5244}"

LINUX_AMD64_URL=""
LINUX_AMD64_SHA=""
INSTALL_SH_URL=""
VERSION=""
PRINT_TEMPLATE=0

usage() {
  sed -n '1,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-template) PRINT_TEMPLATE=1; shift ;;
    --linux-amd64-url) LINUX_AMD64_URL="$2"; shift 2 ;;
    --linux-amd64-sha) LINUX_AMD64_SHA="$2"; shift 2 ;;
    --install-sh-url) INSTALL_SH_URL="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown arg: $1" >&2; usage 1 ;;
  esac
done

if [[ "${PRINT_TEMPLATE}" -eq 1 ]]; then
  cat <<EOF
# Fill after OpenList upload (base: ${OPENLIST_BASE})
# 1. Upload binaries / install.sh / client packages to OpenList under /store/...
# 2. Copy real direct links (often ${OPENLIST_BASE}/d/<path>)
# 3. Run this script with those URLs, or edit releases.json by hand
#    using scripts/fill-releases-after-upload.md

export OPENLIST_BASE='${OPENLIST_BASE}'
./scripts/update-releases-urls.sh \\
  --version '0.1.0' \\
  --linux-amd64-url '${OPENLIST_BASE}/d/store/VPN/nbvpn/nbvpn-linux-amd64' \\
  --linux-amd64-sha '<sha256>' \\
  --install-sh-url '${OPENLIST_BASE}/d/store/VPN/nbvpn/install.sh'
EOF
  exit 0
fi

if [[ ! -f "${RELEASES}" ]]; then
  echo "missing ${RELEASES}" >&2
  exit 1
fi

if [[ -z "${LINUX_AMD64_URL}${INSTALL_SH_URL}" ]]; then
  echo "No URLs provided. Use --print-template or pass --linux-amd64-url / --install-sh-url." >&2
  echo "See scripts/fill-releases-after-upload.md" >&2
  exit 1
fi

python3 - <<'PY' "${RELEASES}" "${OPENLIST_BASE}" "${LINUX_AMD64_URL}" "${LINUX_AMD64_SHA}" "${INSTALL_SH_URL}" "${VERSION}"
import json, sys, datetime
path, base, linux_url, linux_sha, install_url, version = sys.argv[1:7]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
now = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
data.setdefault("meta", {})
data["meta"]["openlistBase"] = base
data["meta"]["openlistBrowse"] = base.rstrip("/") + "/store"
data["updatedAt"] = now
ver = version or data.get("servers", {}).get("debian", {}).get("version") or "上传后更新"

def mark_ready(item, url, sha=""):
    if not url:
        return
    item["url"] = url
    if sha:
        item["sha256"] = sha
    if version:
        item["version"] = version
    item["status"] = "ready"
    item["note"] = item.get("note", "").replace("上传后更新", "已填直链").strip() or "OpenList 直链"

servers = data.setdefault("servers", {})
for key in ("debian", "ubuntu", "centos", "rhel"):
    item = servers.setdefault(key, {"label": key})
    if linux_url:
        mark_ready(item, linux_url, linux_sha)
    if install_url:
        item["installCommand"] = f"curl -fsSL {install_url} | sudo bash"
        item["status"] = "ready"
        if version:
            item["version"] = version

# Windows Server binary (optional env)
win_url = os.environ.get("OPENLIST_SERVER_WINDOWS_URL", "").strip()
win_sha = os.environ.get("OPENLIST_SERVER_WINDOWS_SHA256", "").strip()
win_ps1 = os.environ.get("OPENLIST_WINDOWS_INSTALL_PS1_URL", "").strip()
if win_url or win_sha:
    witem = servers.setdefault("windows", {"label": "Windows Server"})
    if win_url:
        mark_ready(witem, win_url, win_sha)
    if win_ps1:
        witem["installCommand"] = (
            f'powershell -ExecutionPolicy Bypass -Command '
            f'"irm {win_ps1} | iex"'
        )
    witem.setdefault(
        "installCommand",
        r"powershell -ExecutionPolicy Bypass -File .\install.ps1",
    )
    if version:
        witem["version"] = version

any_ready = any(
    (data.get("clients") or {}).get(k, {}).get("status") == "ready"
    for k in ("windows", "macos", "android", "ios")
) or any(
    (data.get("servers") or {}).get(k, {}).get("status") == "ready"
    for k in ("debian", "ubuntu", "centos", "rhel", "windows")
)
data["meta"]["status"] = "partial" if any_ready else "links_deferred"
data["meta"]["note"] = (
    "部分条目已填 OpenList 直链；其余仍待上传后更新。"
    if data["meta"]["status"] == "partial"
    else "具体下载链接待产物上传到 OpenList 后再填入。"
)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"updated {path}")
print("Client entries still pending unless you edit them manually.")
print("Checklist: scripts/fill-releases-after-upload.md")
PY
