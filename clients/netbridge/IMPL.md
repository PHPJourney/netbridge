# 网桥 VPN 客户端 — 实现说明（T04）

> 路径：`clients/netbridge/`  
> 对齐：`docs/delivery/nbvpn/01-spec.md` FR-C、`02-design.md` C-01～C-12、`03-contract.md`  
> 日期：2026-08-15（WGExtension 已嵌入 macOS/iOS；`extensionTargetLinked=true`）

## 概要

Flutter 单仓四端（Android / iOS / Windows / macOS）客户端，产品名 **网桥 VPN**。

- **无**内置服务器、**无**登录墙  
- 导入：`nbvpn:1?<base64url>` URI、`.nbvpn.json`、移动端相机扫码（QR=URI）  
- Profile 解析：`lib/profile/`；连接错误：`lib/services/vpn/vpn_errors.dart`  
- 凭据 / 清单：`ServerStore`；Kill Switch / 语言：`shared_preferences`  
- 文案：`flutter gen-l10n`；桌面托盘与 Windows 单实例见既有说明  

## 本地命令

```bash
export PATH="/Users/mac/flutter/bin:$PATH"
cd clients/netbridge
flutter pub get && flutter gen-l10n
flutter test && flutter analyze
flutter run -d macos
# 验证 Extension 目标（无签名）
xcodebuild -project macos/Runner.xcodeproj -target WGExtension \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
flutter build macos --debug
```

## 目录（Apple 相关）

| 路径 | 作用 |
|------|------|
| `ios/WGExtension/`、`macos/WGExtension/` | Packet Tunnel Provider + Info + entitlements |
| `macos/WGExtension/WGExtension-Debug.entitlements` | Debug/Profile：无 NE（Personal Team 可签名） |
| `macos/WGExtension/WGExtension.entitlements` | Release：packet-tunnel + App Group |
| `macos/Runner/AdHoc.entitlements` | Debug/Profile Host：无 NE |
| `macos/Runner/Release.entitlements` / `DebugProfile.entitlements` | 含 NE + App Group（付费 Team / Release） |
| `apple/PacketTunnelProvider.WireGuardKit.swift.example` | WireGuardKit 完整实现备份 |
| `lib/services/vpn/apple_tunnel_config.dart` | Bundle ID / App Group / `extensionTargetLinked` |

## 平台状态矩阵

| 平台 | 真实隧道 | 备注 |
|------|----------|------|
| **Android** | 可用 | 系统 VPN 授权 |
| **iOS** | **可用** | app extension + WireGuardKit 数据面（App Store 分发） |
| **macOS** | **可用** | system extension + WireGuardKit 数据面（Developer ID 直发 + 公证） |
| **Windows** | 部分 | 常需管理员 |

Dart：`AppleTunnelConfig.extensionTargetLinked = true` → 走 `WireGuardVpnTunnel`。
WireGuardKit（Swift/C/Go）已 vendor 进 `ios|macos/WGExtension/vendor/`，
`libwg-go.a` 预编译（macOS universal + iOS arm64）；重编见 `apple/README.md`。

## 诚实边界（必读）

**「加上扩展」≠「打包就能给别人用」。**

| 门槛 | 现状 |
|------|------|
| Xcode Embed | **已完成**：iOS `WGExtension.appex` 在 `PlugIns/`；macOS `WGExtension.systemextension` 在 `Contents/Library/SystemExtensions/` |
| Bundle 族 / App Group 字符串 | Host `com.netbridge.netbridge`；Extension `…WGExtension`；Group `group.com.netbridge.netbridge` |
| DEVELOPMENT_TEAM | `LH2LR8BBJ2`（付费账号 Hangzhou Chi Xue science and Technology Co., Ltd.） |
| Network Extension | 已配：iOS `packet-tunnel-provider`；macOS `packet-tunnel-provider-systemextension`（Developer ID 只签发 system extension 形态） |
| WireGuardKit | **已接入**（2026-08-29）：源码 vendor（`WireGuardKit` 12 Swift + `WireGuardKitC` C）+ 预编译 `libwg-go.a`（wireguard-go 数据面，Go 1.23 CGO）。重编 Go 库：`apple/vendor-wireguard-apple/Sources/WireGuardKitGo` 的 Makefile（见 `apple/README.md`） |
| 公证 / 分发 | macOS Developer ID 签名 + `notarytool` 公证 + staple 已跑通（重签要点见 `apple/README.md`） |

### Release / 真连已打通

1. 付费 Team；门户两个 App ID 已开 **Network Extensions** + **App Groups**  
2. Release：Runner 用 `Release.entitlements`，Extension 用 `WGExtension.entitlements`  
3. WireGuardKit 已 vendor（无需 SPM），Provider 为完整实现（`apple/PacketTunnelProvider.WireGuardKit.swift.example` 已落位）  
4. 真机/本机测：应出现系统 VPN 权限框并能握手自建节点（macOS 首次连接需在系统设置批准网络扩展）  
5. 外发：iOS `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`；macOS 构建后按 `apple/README.md` 重签 + 公证 + DMG

### 本机调试（付费 Team 已配）

1. Xcode 打开 `macos/Runner.xcworkspace`（或 `ios/Runner.xcworkspace`）  
2. Debug 构建无 NE（AdHoc / Debug entitlements）；真连用 Release 配置  
3. Console.app 过滤 `NESession` / `WGExtension` / `NetworkExtension`  
4. macOS system extension 批准：系统设置 → 隐私与安全性 → 网络扩展

### Release / 真连仍须用户完成

1. 付费 Team；门户为两个 App ID 打开 **Network Extensions** + **App Groups**  
2. Release：Runner 用 `Release.entitlements`，Extension 用 `WGExtension.entitlements`（工程已如此配置）  
3. Xcode 添加 SPM WireGuardKit（可用官方仓库并修好 Package.swift tools-version，或 vendor 源码），用 `apple/PacketTunnelProvider.WireGuardKit.swift.example` 替换脚手架  
4. 真机/本机测：应出现系统 VPN 权限框并能握手自建节点  
5. 外发：Archive → 公证  

## 设置页

「隧道能力」在真隧道路径下会附加 `tunnelAppleLinkedNote`（付费账号 / Personal Team / 公证说明）。关于页平台段落已同步。

## 标识符

| 项 | 值 |
|----|-----|
| Host Bundle ID | `com.netbridge.netbridge` |
| Extension Bundle ID | `com.netbridge.netbridge.WGExtension` |
| App Group | `group.com.netbridge.netbridge` |
| `extensionTargetLinked` | **true** |
| DEVELOPMENT_TEAM | `LH2LR8BBJ2`（付费） |

## 已知限制（摘要）

1. Debug：无 NE（AdHoc / Debug entitlements）；真连请用 Release 配置  
2. macOS 首次连接需用户在系统设置批准网络扩展（system extension 机制）  
3. 分发 / 公证已跑通；版本升级需同步 pbxproj 中 WGExtension 的版本号  
4. 其余产品限制见历史条目（扫码、`.conf` 导入、Kill Switch 等）  

## 品牌 / Android 瘦身

见仓库既有说明（图标、`BrandLinks`、APK split-per-abi）。
