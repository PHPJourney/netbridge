#!/usr/bin/env bash
# 构建 macOS 安装包（pkg）：NetBridge.app + obfs2 客户端桥。
#
# 安装内容：
#   /Applications/NetBridge.app        （含内嵌 nbvpn，app 可自发现）
#   /usr/local/bin/nbvpn                （obfs2 client 桥，CLI 也可用）
#
# 产物：clients/netbridge/dist/NetBridge-macOS-<version>-<build>.pkg
#       （Developer ID 签名 + notarytool 公证 + staple）
#
# 依赖（见 apple/README.md）：
#   - Developer ID Application 证书（钥匙串）
#   - notarytool keychain-profile "NetBridge"
#   - server/nbvpn/dist/nbvpn-darwin-{amd64,arm64}
#     （缺失 arm64 时仅用 amd64；两者都有则 lipo 成 universal）
#
# 用法：./scripts/package-macos-pkg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # clients/netbridge
REPO="$(cd "$ROOT/../.." && pwd)"                          # NetBridge 仓库根
DIST="$ROOT/dist"
STAGE="$DIST/.pkg-staging"
IDENT="Developer ID Application: Hangzhou Chi Xue science and Technology Co., Ltd. (LH2LR8BBJ2)"
NBVPN_VERSION="1.0.0"

VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
BUILD="$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f2)"
PKG_NAME="NetBridge-macOS-${VERSION}-${BUILD}.pkg"

echo "==> 1/8 flutter build macos --release"
(cd "$ROOT" && flutter build macos --release)
APP="$ROOT/build/macos/Build/Products/Release/netbridge.app"
[ -d "$APP" ] || { echo "build produced no app at $APP" >&2; exit 1; }

echo "==> 2/8 prepare universal nbvpn (obfs2 client)"
rm -rf "$STAGE" && mkdir -p "$STAGE"
NBVPN_BIN="$STAGE/nbvpn"
AM="$REPO/server/nbvpn/dist/nbvpn-darwin-amd64"
AR="$REPO/server/nbvpn/dist/nbvpn-darwin-arm64"
if [[ -f "$AM" && -f "$AR" ]]; then
  lipo -create "$AM" "$AR" -output "$NBVPN_BIN"
  echo "    universal (amd64+arm64)"
elif [[ -f "$AM" ]]; then
  cp "$AM" "$NBVPN_BIN"
  echo "    amd64 only"
else
  echo "missing $AM — build it first:" >&2
  echo "  cd server/nbvpn && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w -X main.version=${NBVPN_VERSION}' -o dist/nbvpn-darwin-amd64 ." >&2
  exit 1
fi
chmod +x "$NBVPN_BIN"
# Notarization requires every executable inside the pkg payload to be
# signed — sign the bridge before it lands in the app bundle or /usr/local/bin.
codesign --force --options runtime --timestamp --sign "$IDENT" "$NBVPN_BIN"

echo "==> 3/8 embed nbvpn into app bundle and sign it"
cp "$NBVPN_BIN" "$APP/Contents/MacOS/nbvpn"
codesign --force --options runtime --timestamp --sign "$IDENT" "$APP/Contents/MacOS/nbvpn"

echo "==> 4/8 re-sign app (strip get-task-allow, extension first)"
EXT="$APP/Contents/Library/SystemExtensions/com.netbridge.netbridge.WGExtension.systemextension"
codesign -d --entitlements - --xml "$EXT" 2>/dev/null > "$STAGE/ext.plist"
codesign -d --entitlements - --xml "$APP" 2>/dev/null > "$STAGE/app.plist"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$STAGE/ext.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$STAGE/app.plist" 2>/dev/null || true
codesign --force --options runtime --timestamp --sign "$IDENT" --entitlements "$STAGE/ext.plist" "$EXT"
codesign --force --options runtime --timestamp --sign "$IDENT" --entitlements "$STAGE/app.plist" "$APP"
codesign --verify --deep --strict "$APP" && echo "    sign OK"

echo "==> 5/8 notarize + staple the app"
ditto -c -k --keepParent "$APP" "$STAGE/netbridge-notary.zip"
xcrun notarytool submit "$STAGE/netbridge-notary.zip" --keychain-profile NetBridge --wait >/dev/null
xcrun stapler staple "$APP"

echo "==> 6/8 pkgbuild components"
APP_ROOT="$STAGE/app"
mkdir -p "$APP_ROOT/Applications"
ditto "$APP" "$APP_ROOT/Applications/NetBridge.app"
pkgbuild --root "$APP_ROOT" \
  --identifier com.netbridge.netbridge \
  --version "${VERSION}.${BUILD}" \
  --install-location / \
  "$STAGE/netbridge-app.pkg"

BIN_ROOT="$STAGE/bin"
mkdir -p "$BIN_ROOT/usr/local/bin"
cp "$NBVPN_BIN" "$BIN_ROOT/usr/local/bin/nbvpn"
chmod 755 "$BIN_ROOT/usr/local/bin/nbvpn"
pkgbuild --root "$BIN_ROOT" \
  --identifier com.netbridge.netbridge.obfs2client \
  --version "$NBVPN_VERSION" \
  --install-location / \
  "$STAGE/netbridge-obfs2.pkg"

echo "==> 7/8 productbuild + productsign"
mkdir -p "$DIST"
rm -f "$DIST/$PKG_NAME"
productbuild \
  --package "$STAGE/netbridge-app.pkg" \
  --package "$STAGE/netbridge-obfs2.pkg" \
  --identifier com.netbridge.netbridge \
  --version "${VERSION}.${BUILD}" \
  "$STAGE/${PKG_NAME}.unsigned"

# 公证要求 pkg 用 Developer ID Installer 证书签名（不是 Application）。
INSTALLER_ID="Developer ID Installer: Hangzhou Chi Xue science and Technology Co., Ltd. (LH2LR8BBJ2)"
if ! security find-identity -v -p basic 2>/dev/null | grep -q "Developer ID Installer"; then
  echo "ERROR: no 'Developer ID Installer' certificate in keychain." >&2
  echo "Create one at developer.apple.com > Certificates (reuse apple/NetBridge.certSigningRequest), install it, then re-run." >&2
  exit 1
fi
productsign --sign "$INSTALLER_ID" "$STAGE/${PKG_NAME}.unsigned" "$DIST/$PKG_NAME"

echo "==> 8/8 notarize + staple the pkg"
xcrun notarytool submit "$DIST/$PKG_NAME" --keychain-profile NetBridge --wait >/dev/null
xcrun stapler staple "$DIST/$PKG_NAME"
spctl -a -vvv "$DIST/$PKG_NAME" 2>&1 | head -2

echo
echo "OK: $DIST/$PKG_NAME"
