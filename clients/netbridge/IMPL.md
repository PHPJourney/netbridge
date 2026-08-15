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
| **iOS** | Extension **已嵌入** | 同 macOS：付费 Team + NE + WireGuardKit 后才有数据面 |
| **macOS** | Extension **已嵌入** | Debug 可编过；Release 需 NE 能力 |
| **Windows** | 部分 | 常需管理员 |

Dart：`AppleTunnelConfig.extensionTargetLinked = true` → 走 `WireGuardVpnTunnel`（不再 Stub）。  
连接时会调插件；**Debug/Personal Team 构建无 NE entitlement**，系统通常无法真正拉起 Packet Tunnel。

## 诚实边界（必读）

**「加上扩展」≠「打包就能给别人用」。**

| 门槛 | 现状 |
|------|------|
| Xcode Embed | **已完成**：`WGExtension.appex` 在 `Contents/PlugIns/` |
| Bundle 族 / App Group 字符串 | Host `com.netbridge.netbridge`；Extension `…WGExtension`；Group `group.com.netbridge.netbridge` |
| DEVELOPMENT_TEAM | 工程沿用 **`846K6R4WU8`**（本机 Xcode Personal Team）。换账号：Xcode → Signing 选 Team，**勿伪造无效 Team** |
| Network Extension | **付费** Apple Developer 才稳定；Personal Team 描述文件**不含** NE → Debug 故意用 AdHoc / Debug entitlements |
| WireGuardKit | **尚未链接**：`passepartoutvpn/wireguard-apple` 已 404；官方 `WireGuard/wireguard-apple` 需 tools-version≥5.5 + Go 编 `WireGuardKitGo`。当前 Provider 为嵌入脚手架，校验 `wgQuickConfig` 后返回 `wireGuardKitNotLinked` |
| 公证 / 分发 | 给别人用的 macOS 包通常要 Developer ID + **公证**；仅本地 Debug 签名不够 |

### 本机 Personal Team 如何看错误

1. Xcode 打开 `macos/Runner.xcworkspace` → Runner / WGExtension → Signing & Capabilities  
2. 若把 Debug 改回 `DebugProfile.entitlements`（含 NE），常见报错：`Provisioning profile … doesn't include the Network Extensions capability`  
3. Console.app 过滤 `NESession` / `WGExtension` / `NetworkExtension`  
4. 无付费账号时：继续用官方 WireGuard App + `nbvpn` 导出的 `.conf`

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
| DEVELOPMENT_TEAM | `846K6R4WU8`（Personal；可改） |

## 已知限制（摘要）

1. Debug macOS：**无 NE** 以便 Personal Team 编过；真连请用付费 Team + Release entitlements  
2. WireGuardKit 未接入 → Extension 无法建立真实 UDP 隧道数据面  
3. 分发 / 公证未做  
4. 其余产品限制见历史条目（扫码、`.conf` 导入、Kill Switch 等）  

## 品牌 / Android 瘦身

见仓库既有说明（图标、`BrandLinks`、APK split-per-abi）。
