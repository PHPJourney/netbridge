# Apple Packet Tunnel — notes

| Item | Value |
|------|--------|
| Host | `com.netbridge.netbridge` |
| Extension | `com.netbridge.netbridge.WGExtension` |
| App Group | `group.com.netbridge.netbridge` |
| Dart | `AppleTunnelConfig.extensionTargetLinked = true` |
| Team | `LH2LR8BBJ2`（Hangzhou Chi Xue science and Technology Co., Ltd.，付费账号） |

**iOS：** `WGExtension` 保持 app extension 形态（`packet-tunnel-provider`），
App Store Connect 分发。profiles：`NetBridge Host Profile` / `NetBridge WGExtension Profile`。
构建：`flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`
（ExportOptions：app-store-connect，手动签名 + 两个 profile 映射）。

**macOS：** `WGExtension` 已改造为 **system extension** 形态
（`com.apple.product-type.system-extension` + `packet-tunnel-provider-systemextension`），
Developer ID 直发（Apple 政策：macOS Developer ID 只签发 system extension 形态的 NE）。
嵌入位置 `Contents/Library/SystemExtensions/`；宿主 AppDelegate 通过
`OSSystemExtensionRequest` 激活（首次连接弹系统批准）。
profiles：`NetBridge macOS Host` / `NetBridge WGExenion macOS Host`（Developer ID 类型）。

**签名与公证（macOS）：**
- 证书：`Developer ID Application: Hangzhou Chi Xue science and Technology Co., Ltd. (LH2LR8BBJ2)`
- 安装包证书：`Developer ID Installer`（同一公司主体，见 `apple/developerID_installer.cer` +
  `NetBridge-installer.key`；pkg 公证强制要求 Installer 类型证书签名）
- 私钥：`apple/NetBridge-cert.key`（CSR 私钥，已导入钥匙串）
- 注意：Xcode 手动签名会注入 `get-task-allow` 且缺 `--timestamp`，**公证前必须重签**：
  提取 `codesign -d --entitlements` → 删 `com.apple.security.get-task-allow` →
  `codesign --force --options runtime --timestamp`（先扩展后宿主）
- 公证凭据：`notarytool` keychain-profile `NetBridge`（App Store Connect API Key
  `TPXK82VT64`，Issuer `69a6de90-…`，`.p8` 在 `apple/AuthKey_TPXK82VT64.p8`）
- 版本一致性：WGExtension 的 `CURRENT_PROJECT_VERSION` / `MARKETING_VERSION`
  需与 pubspec 同步（当前 0.1.19 / 20，改 pubspec 后要同步 pbxproj）
- **macOS 安装包**：`scripts/package-macos-pkg.sh` 产出签名+公证的 pkg
  （NetBridge.app → /Applications，obfs2 桥 nbvpn → /usr/local/bin 且内嵌进 app bundle）

**WireGuardKit 数据面已接入（2026-08-29）：**
- 源码 vendor：`ios|macos/WGExtension/vendor/WireGuardKit/`（12 个 Swift 文件）
  + `WireGuardKitC/`（key.c、x25519.c）+ `wireguard.h`
- 预编译 Go 数据面：`ios|macos/WGExtension/vendor/libwg-go.a`
  （wireguard-go，CGO；macOS universal x86_64+arm64，iOS arm64）
- bridging header：`vendor/WGExtension-Bridging-Header.h`（暴露 C API 给 Swift）
- Provider 为完整实现：解析 wgQuickConfig → `WireGuardAdapter` 建隧道
- **重编 Go 库**（升级 wireguard-go 时）：
  ```bash
  cd apple/vendor-wireguard-apple   # git pull 更新
  # macOS：
  make -C Sources/WireGuardKitGo build ARCHS="arm64 x86_64" PLATFORM_NAME=macosx \
    CONFIGURATION_BUILD_DIR=$PWD/../vendor/libwg-go-macos CONFIGURATION_TEMP_DIR=/tmp/wg-macos
  # iOS 真机：
  make -C Sources/WireGuardKitGo build ARCHS="arm64" PLATFORM_NAME=iphoneos \
    CONFIGURATION_BUILD_DIR=$PWD/../vendor/libwg-go-ios CONFIGURATION_TEMP_DIR=/tmp/wg-ios
  # 把产物 libwg-go.a 拷回 macos|ios/WGExtension/vendor/
  ```
- 构建要求：本机 Go ≥1.20（GOROOT 需可写，Makefile 会打 runtime patch）

申请流程详见 `apple/CERT-GUIDE.md`；诚实边界见 `IMPL.md`。
