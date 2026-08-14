#!/usr/bin/env bash
# Build NetBridge client distribution packages into clients/netbridge/dist/
#
# Targets (best-effort on this host):
#   dist/NetBridge-android-arm64.apk   — R8 slim, arm64-v8a, debug-signed sideload
#   dist/NetBridge-windows.exe        — or portable zip (requires Windows host / WINDOWS_ARTIFACT)
#   dist/NetBridge-macOS.dmg          — .app + ad-hoc codesign (NOT App Store / Developer ID)
#   dist/NetBridge-iOS.ipa            — signed if Team+certs; else unsigned stub + README
#
# Env (optional):
#   SKIP_TESTS=1          skip flutter test
#   SKIP_ANDROID=1        skip Android rebuild (reuse existing APK if present)
#   SKIP_MACOS=1
#   SKIP_IOS=1
#   SKIP_WINDOWS=1
#   APPLE_TEAM_ID=XXXX    enable flutter build ipa / development export
#   WINDOWS_ARTIFACT=path copy prebuilt .exe or Release/ folder from a Windows build
#   FLUTTER_BIN=...       default: flutter on PATH or /Users/mac/flutter/bin/flutter
#
# See dist/README.txt and docs/delivery/nbvpn/TRY-CONNECT.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/dist"
IOS_EXPORT_OPTS="${ROOT}/ios/ExportOptions.plist"
VERSION="$(awk '/^version:/ {print $2}' "${ROOT}/pubspec.yaml" | cut -d+ -f1)"
export PATH="${PATH}:/Users/mac/flutter/bin"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
[[ -n "${FLUTTER_BIN}" ]] || { echo "error: flutter not found" >&2; exit 1; }

mkdir -p "${DIST}"
cd "${ROOT}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
sha_one() {
  local f="$1"
  (cd "$(dirname "$f")" && shasum -a 256 "$(basename "$f")" >"$(basename "$f").sha256")
}

STATUS_FILE="${DIST}/PACKAGE-STATUS.txt"
: >"${STATUS_FILE}"
status_line() { printf '%s\n' "$*" | tee -a "${STATUS_FILE}"; }

log "NetBridge package-all v${VERSION}"
log "host=$(uname -s)/$(uname -m) flutter=$(${FLUTTER_BIN} --version 2>/dev/null | head -1)"

# --- signing probe ---
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
IDENTITY_COUNT="$(printf '%s\n' "${IDENTITIES}" | grep -c 'valid identities found' || true)"
VALID_IDS="$(printf '%s\n' "${IDENTITIES}" | grep -E 'Apple Distribution|Apple Development|Developer ID Application' || true)"
if printf '%s\n' "${IDENTITIES}" | grep -q '0 valid identities found'; then
  log "codesign identities: NONE (ad-hoc / unsigned Apple paths only)"
  HAS_APPLE_IDENTITY=0
else
  log "codesign identities:"
  printf '%s\n' "${IDENTITIES}" | sed -n '1,20p'
  HAS_APPLE_IDENTITY=1
fi

log "flutter pub get"
"${FLUTTER_BIN}" pub get
log "flutter gen-l10n"
"${FLUTTER_BIN}" gen-l10n

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  log "flutter test"
  "${FLUTTER_BIN}" test
else
  warn "SKIP_TESTS=1"
fi

# ============================================================================
# Android (arm64 slim, R8 already in build.gradle.kts)
# ============================================================================
if [[ "${SKIP_ANDROID:-0}" == "1" ]]; then
  warn "SKIP_ANDROID=1"
else
  log "flutter build apk --release --split-per-abi (R8 minify)"
  "${FLUTTER_BIN}" build apk --release --split-per-abi
fi

APK_ARM64="${ROOT}/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [[ -f "${APK_ARM64}" ]]; then
  cp -f "${APK_ARM64}" "${DIST}/NetBridge-android-arm64.apk"
  # Keep legacy name as arm64 alias for TRY-CONNECT / store mocks
  cp -f "${APK_ARM64}" "${DIST}/NetBridge-android.apk"
  sha_one "${DIST}/NetBridge-android-arm64.apk"
  sha_one "${DIST}/NetBridge-android.apk"
  APK_V7A="${ROOT}/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
  if [[ -f "${APK_V7A}" ]]; then
    cp -f "${APK_V7A}" "${DIST}/NetBridge-android-armeabi-v7a.apk"
    sha_one "${DIST}/NetBridge-android-armeabi-v7a.apk"
  fi
  status_line "android: OK NetBridge-android-arm64.apk (debug-signed release, R8 slim, arm64)"
else
  status_line "android: FAIL (no APK at ${APK_ARM64})"
fi

# ============================================================================
# macOS → ad-hoc sign → DMG (+ zip)
# ============================================================================
if [[ "${SKIP_MACOS:-0}" == "1" ]]; then
  warn "SKIP_MACOS=1"
  if [[ -f "${DIST}/NetBridge-macOS.dmg" ]]; then
    status_line "macos: OK NetBridge-macOS.dmg (reused existing; SKIP_MACOS=1)"
  fi
else
  log "flutter build macos --release"
  "${FLUTTER_BIN}" build macos --release

  APP_SRC="${ROOT}/build/macos/Build/Products/Release/netbridge.app"
  if [[ ! -d "${APP_SRC}" ]]; then
    APP_SRC="$(find "${ROOT}/build/macos/Build/Products/Release" -maxdepth 1 -name '*.app' | head -1 || true)"
  fi
  if [[ -d "${APP_SRC}" ]]; then
    rm -rf "${DIST}/NetBridge-macOS.app"
    cp -R "${APP_SRC}" "${DIST}/NetBridge-macOS.app"

    log "ad-hoc codesign (codesign --sign -); AdHoc.entitlements (no NE)"
    codesign --force --deep --sign - "${DIST}/NetBridge-macOS.app" 2>/dev/null \
      || codesign --force --sign - "${DIST}/NetBridge-macOS.app"
    codesign -dv --verbose=2 "${DIST}/NetBridge-macOS.app" 2>"${DIST}/NetBridge-macOS.codesign.txt" || true

    rm -f "${DIST}/NetBridge-macOS.app.zip"
    (
      cd "${DIST}"
      zip -qry NetBridge-macOS.app.zip NetBridge-macOS.app
    )
    sha_one "${DIST}/NetBridge-macOS.app.zip"

    # DMG via hdiutil (UDZO)
    log "create DMG NetBridge-macOS.dmg"
    DMG_STAGING="${DIST}/.dmg-staging"
    rm -rf "${DMG_STAGING}"
    mkdir -p "${DMG_STAGING}"
    cp -R "${DIST}/NetBridge-macOS.app" "${DMG_STAGING}/NetBridge.app"
    ln -sf /Applications "${DMG_STAGING}/Applications"
    rm -f "${DIST}/NetBridge-macOS.dmg"
    hdiutil create \
      -volname "NetBridge" \
      -srcfolder "${DMG_STAGING}" \
      -ov -format UDZO \
      "${DIST}/NetBridge-macOS.dmg"
    rm -rf "${DMG_STAGING}"
    sha_one "${DIST}/NetBridge-macOS.dmg"
    status_line "macos: OK NetBridge-macOS.dmg (ad-hoc sign, NOT App Store / NOT notarized)"
  else
    status_line "macos: FAIL (no .app under Release)"
  fi
fi

# ============================================================================
# iOS → IPA (signed if possible; else unsigned Payload zip + README)
# ============================================================================
write_ios_readme() {
  cat >"${DIST}/IOS-IPA-README.txt" <<'EOF'
NetBridge iOS IPA — signing requirements
========================================

This machine currently has NO Apple Development / Distribution identities
(security find-identity -v -p codesigning → 0 valid).

What you must provide for a REAL installable IPA (non–App Store OK):
  1. Paid Apple Developer Program membership
  2. APPLE_TEAM_ID (10-char Team ID)
  3. Apple Development or Apple Distribution certificate in login keychain
  4. Provisioning profile(s) for:
       - com.netbridge.netbridge
       - com.netbridge.netbridge.WGExtension  (if NE linked)
  5. ios/ExportOptions.plist (see ios/ExportOptions.plist.example)
       method: ad-hoc | development | enterprise (NOT app-store if sideloading)

Then:
  export APPLE_TEAM_ID=XXXXXXXXXX
  # optionally copy ExportOptions.plist.example → ExportOptions.plist and edit teamID
  ./scripts/package-all.sh

Or manually:
  flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

Unsigned / --no-codesign IPA (if present as NetBridge-iOS.ipa):
  - Useful as a pipeline artifact only
  - CANNOT install on normal devices (no matching provisioning)
  - Dev devices still need a signed build with your Team UUID registered

Network Extension / real WireGuard tunnel additionally needs NE entitlements
on both host + extension — see apple/README.md and IMPL.md.
EOF
}

if [[ "${SKIP_IOS:-0}" == "1" ]]; then
  warn "SKIP_IOS=1"
  write_ios_readme
else
  write_ios_readme
  IPA_OUT=""
  if [[ -n "${APPLE_TEAM_ID:-}" && -f "${IOS_EXPORT_OPTS}" && "${HAS_APPLE_IDENTITY}" == "1" ]]; then
    log "flutter build ipa (APPLE_TEAM_ID=${APPLE_TEAM_ID})"
    if "${FLUTTER_BIN}" build ipa --release \
      --export-options-plist="${IOS_EXPORT_OPTS}"; then
      IPA_CAND="$(find "${ROOT}/build/ios/ipa" -name '*.ipa' 2>/dev/null | head -1 || true)"
      if [[ -n "${IPA_CAND}" ]]; then
        cp -f "${IPA_CAND}" "${DIST}/NetBridge-iOS.ipa"
        IPA_OUT="${DIST}/NetBridge-iOS.ipa"
        status_line "ios: OK NetBridge-iOS.ipa (signed via Team ${APPLE_TEAM_ID})"
      fi
    else
      warn "flutter build ipa failed; falling back to unsigned payload"
    fi
  else
    log "no APPLE_TEAM_ID+ExportOptions+identity → try unsigned ios --no-codesign"
  fi

  if [[ -z "${IPA_OUT}" ]]; then
    # Still attempt flutter build ipa in case local Xcode has automatic signing
    if [[ "${HAS_APPLE_IDENTITY}" == "1" ]]; then
      log "attempt flutter build ipa (automatic / existing certs)"
      if "${FLUTTER_BIN}" build ipa --release 2>"${DIST}/ios-build-ipa.err"; then
        IPA_CAND="$(find "${ROOT}/build/ios/ipa" -name '*.ipa' 2>/dev/null | head -1 || true)"
        if [[ -n "${IPA_CAND}" ]]; then
          cp -f "${IPA_CAND}" "${DIST}/NetBridge-iOS.ipa"
          IPA_OUT="${DIST}/NetBridge-iOS.ipa"
          status_line "ios: OK NetBridge-iOS.ipa (local certs)"
        fi
      else
        warn "flutter build ipa failed (see dist/ios-build-ipa.err)"
      fi
    fi
  fi

  if [[ -z "${IPA_OUT}" ]]; then
    log "flutter build ios --release --no-codesign → unsigned IPA stub"
    if "${FLUTTER_BIN}" build ios --release --no-codesign; then
      APP_IOS="$(find "${ROOT}/build/ios/iphoneos" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
      if [[ -z "${APP_IOS}" ]]; then
        APP_IOS="$(find "${ROOT}/build/ios" -name 'Runner.app' 2>/dev/null | head -1 || true)"
      fi
      if [[ -d "${APP_IOS}" ]]; then
        IPA_STAGE="${DIST}/.ipa-staging"
        rm -rf "${IPA_STAGE}"
        mkdir -p "${IPA_STAGE}/Payload"
        cp -R "${APP_IOS}" "${IPA_STAGE}/Payload/"
        (
          cd "${IPA_STAGE}"
          zip -qry "${DIST}/NetBridge-iOS.ipa" Payload
        )
        rm -rf "${IPA_STAGE}"
        status_line "ios: STUB NetBridge-iOS.ipa (UNSIGNED — cannot install on non-dev devices; need APPLE_TEAM_ID)"
      else
        status_line "ios: FAIL (no Runner.app after --no-codesign)"
      fi
    else
      status_line "ios: FAIL (flutter build ios --no-codesign)"
    fi
  fi

  if [[ -f "${DIST}/NetBridge-iOS.ipa" ]]; then
    sha_one "${DIST}/NetBridge-iOS.ipa"
  fi
fi

# ============================================================================
# Windows — only on Windows, or via WINDOWS_ARTIFACT from another machine
# ============================================================================
package_windows_from_release_dir() {
  local rel="$1"
  local exe
  exe="$(find "${rel}" -maxdepth 1 -iname '*.exe' | head -1 || true)"
  [[ -n "${exe}" ]] || return 1
  cp -f "${exe}" "${DIST}/NetBridge-windows.exe"
  sha_one "${DIST}/NetBridge-windows.exe"
  rm -f "${DIST}/NetBridge-windows-portable.zip"
  (
    cd "${rel}"
    zip -qry "${DIST}/NetBridge-windows-portable.zip" .
  )
  sha_one "${DIST}/NetBridge-windows-portable.zip"
  return 0
}

cat >"${DIST}/WINDOWS-BUILD.md" <<'EOF'
# Windows package (build on a Windows machine)

Flutter cannot cross-compile Windows from macOS. This Mac build therefore has
**no** `NetBridge-windows.exe` unless you pass `WINDOWS_ARTIFACT`.

## Icon assets (already updated on Mac)

Launcher icons were generated with `dart run flutter_launcher_icons` from
`assets/branding/netbridge_icon_1024.png` (same bytes as
`assets/branding/icon-privacy-store-try.png`). Windows runner icon:

- `windows/runner/resources/app_icon.ico`

Rebuild on Windows will pick up that `.ico` automatically.

## Build on Windows (VS 2022 + Flutter desktop)

```bat
cd clients\netbridge
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter build windows --release
```

Then either:

```bat
bash scripts/package-all.sh
```

or copy the Release folder / exe to any host and set:

```bash
# Directory containing the runner .exe + DLLs:
export WINDOWS_ARTIFACT=/path/to/build/windows/x64/runner/Release
# Or a single .exe file:
# export WINDOWS_ARTIFACT=/path/to/NetBridge.exe
./scripts/package-all.sh
```

Outputs when Windows artifact is available:
- `dist/NetBridge-windows.exe` — main runner exe
- `dist/NetBridge-windows-portable.zip` — full Flutter Windows Release folder (required DLLs)

VPN: WireGuard tunnel may require **Run as administrator**. No Authenticode
signing is applied by this script.
EOF

if [[ "${SKIP_WINDOWS:-0}" == "1" ]]; then
  warn "SKIP_WINDOWS=1"
  if [[ -f "${DIST}/NetBridge-windows.exe" ]]; then
    status_line "windows: OK NetBridge-windows.exe (reused existing; SKIP_WINDOWS=1)"
  else
    status_line "windows: SKIPPED — see dist/WINDOWS-BUILD.md"
  fi
elif [[ -n "${WINDOWS_ARTIFACT:-}" ]]; then
  if [[ -f "${WINDOWS_ARTIFACT}" && "${WINDOWS_ARTIFACT}" == *.exe ]]; then
    cp -f "${WINDOWS_ARTIFACT}" "${DIST}/NetBridge-windows.exe"
    sha_one "${DIST}/NetBridge-windows.exe"
    status_line "windows: OK NetBridge-windows.exe (from WINDOWS_ARTIFACT file)"
  elif [[ -d "${WINDOWS_ARTIFACT}" ]]; then
    if package_windows_from_release_dir "${WINDOWS_ARTIFACT}"; then
      status_line "windows: OK NetBridge-windows.exe + portable.zip (from WINDOWS_ARTIFACT dir)"
    else
      status_line "windows: FAIL (WINDOWS_ARTIFACT dir has no .exe)"
    fi
  else
    status_line "windows: FAIL (WINDOWS_ARTIFACT not found: ${WINDOWS_ARTIFACT})"
  fi
elif [[ "$(uname -s)" == "MINGW"* || "$(uname -s)" == "MSYS"* || "$(uname -s)" == "CYGWIN"* || -n "${WINDIR:-}" ]]; then
  log "flutter build windows --release"
  "${FLUTTER_BIN}" build windows --release
  REL="${ROOT}/build/windows/x64/runner/Release"
  if package_windows_from_release_dir "${REL}"; then
    status_line "windows: OK NetBridge-windows.exe + portable.zip"
  else
    status_line "windows: FAIL (no Release exe)"
  fi
else
  status_line "windows: SKIPPED on $(uname -s) — see dist/WINDOWS-BUILD.md (need Windows host or WINDOWS_ARTIFACT)"
fi

# ============================================================================
# dist/README.txt
# ============================================================================
cat >"${DIST}/README.txt" <<EOF
NetBridge client distribution packages (local build)
Version: ${VERSION}
Generated: $(date -u +%Y-%m-%dT%H:%MZ)
Icon: assets/branding/netbridge_icon_1024.png (= icon-privacy-store-try.png)
      applied via flutter_launcher_icons → Android/iOS/macOS/Windows assets

Artifacts (canonical names)
---------------------------
  NetBridge-android-arm64.apk   Android arm64-v8a, R8 minify, debug-signed sideload
  NetBridge-windows.exe         Windows runner (or portable zip) — build on Windows / WINDOWS_ARTIFACT
  NetBridge-macOS.dmg           macOS app + Applications link; ad-hoc codesign
  NetBridge-iOS.ipa             iOS IPA (signed only with Apple Team; else UNSIGNED stub)

Also produced when applicable:
  NetBridge-android.apk         alias of arm64 slim APK
  NetBridge-android-armeabi-v7a.apk  optional 32-bit ARM APK
  NetBridge-macOS.app / .zip    same app as in the DMG
  NetBridge-windows-portable.zip  full Flutter Windows Release folder
  *.sha256                      checksums
  PACKAGE-STATUS.txt            per-platform OK / STUB / SKIPPED
  IOS-IPA-README.txt            what is required for a real IPA
  WINDOWS-BUILD.md              how to produce the Windows exe (WINDOWS_ARTIFACT)

Signing notes
-------------
  Android  debug keystore (sideload OK; not Play Store)
  macOS    ad-hoc (codesign --sign -); NOT Developer ID / NOT notarized; Gatekeeper: right-click Open
  iOS      unsigned stub unless APPLE_TEAM_ID + certs; see IOS-IPA-README.txt
  Windows  no Authenticode from this Mac; icon .ico already updated in-repo

Install (short)
---------------
  Android: allow unknown sources → install APK → paste URI from VPS
  Windows: unzip portable.zip OR run .exe (VPN may need Administrator)
  macOS:   open DMG → drag NetBridge.app to Applications → right-click Open (Gatekeeper)
  iOS:     unsigned IPA will NOT install; need Team ID + profiles (see IOS-IPA-README.txt)

VPN capability matrix
---------------------
  Android  REAL WireGuard via wireguard_flutter (system VPN prompt)
  Windows  Plugin may work; often needs Administrator; no Authenticode here
  macOS    Ad-hoc / self-sign: UI+import OK; system Packet Tunnel needs Apple Team + NE
  iOS      Same as macOS; without Team ID this IPA is pipeline-only

URI:
  ssh netbridge-vps 'nbvpn show --uri'

See docs/delivery/nbvpn/TRY-CONNECT.md
EOF

log "done. Artifacts:"
ls -lah "${DIST}" | tee -a "${STATUS_FILE}"
log "PACKAGE-STATUS:"
cat "${STATUS_FILE}"
