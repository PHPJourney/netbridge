# 网桥 VPN 客户端 — 实现说明（T04）

> 路径：`clients/netbridge/`  
> 对齐：`docs/delivery/nbvpn/01-spec.md` FR-C、`02-design.md` C-01～C-12、`03-contract.md`  
> 日期：2026-08-14（续：设置 About/法务链接、中英 l10n、语言切换；无 Android 真连）

## 概要

Flutter 单仓四端（Android / iOS / Windows / macOS）客户端，产品名 **网桥 VPN**。

- **无**内置服务器、**无**登录墙  
- 导入：`nbvpn:1?<base64url>` URI、`.nbvpn.json`、移动端相机扫码（QR=URI）  
- Profile 解析：`lib/profile/`（与服务端 Go 契约对齐）；`sanitizeUriInput` + `parseFlexibleImport`  
- 连接错误：`lib/services/vpn/vpn_errors.dart`（`humanizeVpnError`，支持 zh/en）  
- 凭据：`flutter_secure_storage`；Kill Switch / 语言偏好：`shared_preferences`（Kill Switch 默认开）  
- 品牌链接：`lib/config/brand_links.dart`（官方站 / 用户协议 / 隐私政策；默认对齐 store `meta` OpenList，**生产须替换为正式 URL**）  
- 文案：`flutter gen-l10n`（`lib/l10n/app_zh.arb` + `app_en.arb`）；设置内「跟随系统 / 中文 / English」
- **Windows / 桌面托盘**：`lib/desktop/desktop_tray.dart` — 关窗隐藏到托盘（VPN 保持）；右键：显示主窗口、切换已保存节点、连接/断开、退出

## 本地命令

```bash
export PATH="/Users/mac/flutter/bin:$PATH"
cd clients/netbridge
flutter pub get
flutter gen-l10n
flutter test
flutter analyze
# 运行（按平台）
flutter run -d macos
flutter run -d windows
flutter run -d <android-device-id>
flutter run -d <ios-device-id>
```

## 目录

| 路径 | 作用 |
|------|------|
| `lib/config/brand_links.dart` | 官方站 / Terms / Privacy 常量（对齐 store meta 占位） |
| `lib/l10n/` | ARB + 生成 `AppLocalizations`（zh / en） |
| `lib/profile/` | NbVpnProfile 解析、URI 编解码、错误码中英文案 |
| `lib/services/vpn/` | `VpnTunnel` + `WireGuardVpnTunnel` + `StubVpnTunnel` + `apple_tunnel_config.dart` |
| `lib/state/app_controller.dart` | 列表、连接状态机、仅单隧道；Apple 启动失败回退 Stub；语言偏好 |
| `ios/WGExtension/` | Packet Tunnel **脚手架**（源码/entitlements/Info） |
| `macos/WGExtension/` | 同上（macOS） |
| `apple/` | App Group 说明 + WireGuardKit 完整 Provider 示例 |
| `lib/screens/` | C-01～C-11 流程界面（含设置 About / 法务外链） |
| `test/profile/` | URI roundtrip / 错误码单测 |

## 设置页条目（About / 法务）

| 条目 | 行为 |
|------|------|
| Kill Switch | 偏好开关（逻辑未改） |
| 隧道能力 / 连不上节点 | 说明文案 |
| 语言 | 跟随系统 / 中文 / English（写入 prefs；system 时跟设备 locale，非 en 则回退 zh） |
| 版本 | `BrandLinks.appVersion` + 责任一句话（去中心化、无官方节点） |
| 官方网站 | `url_launcher` → `BrandLinks.officialSite` |
| 用户协议 / Terms | → `BrandLinks.termsUrl` |
| 隐私政策 / Privacy | → `BrandLinks.privacyUrl` |
| 合作方 | 可选文案 TradeMind / TM Open Platform |
| 关于与责任说明 | 对话框长文 |

## 平台状态矩阵

| 平台 | UI / 导入 / 存储 | 真实 WireGuard 隧道 | Kill Switch | 备注 |
|------|------------------|---------------------|-------------|------|
| **Android** | 完整（含扫码） | **可用**（`wireguard_flutter`，需系统 VPN 授权） | 偏好已存；依赖 VPN 服务路由，完整阻断视 OEM | 推荐优先联调 |
| **iOS** | 完整（含扫码） | **脚手架就绪，未链接** | UI + 偏好；无系统级 KS | 见下方 Xcode 步骤；`extensionTargetLinked=false` → Stub |
| **Windows** | 完整（文件/URI；无相机扫码） | **部分**（插件支持，需**管理员**运行） | UI + 偏好；无防火墙 KS | 提权与安装包签名待 release |
| **macOS** | 完整（文件/URI） | **脚手架就绪，未链接** | UI + 偏好 | 同 iOS |

初始化或（Apple）`startVpn` 失败时，自动回退 **StubVpnTunnel**，保证 UI 可验收；设置页展示能力说明。

## 隧道集成细节

### Android（已接线）

1. `WireGuardVpnTunnel` 调用 `WireGuardFlutter.initialize` / `startVpn`  
2. 配置由 `ProfileCodec.toWireGuardConf` 生成 wg-quick 文本  
3. 用户首次连接会看到系统 VPN 授权对话框（C-10 语义）

### iOS / macOS — 标识符（无门户密钥）

| 项 | 值 |
|----|-----|
| Host Bundle ID | `com.netbridge.netbridge` |
| Extension Bundle ID | `com.netbridge.netbridge.WGExtension` |
| App Group | `group.com.netbridge.netbridge` |
| Dart 开关 | `AppleTunnelConfig.extensionTargetLinked`（默认 **false**） |

仓库已含：

- `ios/Runner/Runner.entitlements`（NE + App Group 模板；已挂到 Xcode `CODE_SIGN_ENTITLEMENTS`）
- `macos/Runner/DebugProfile.entitlements` / `Release.entitlements`（同上）
- `ios/WGExtension/*`、`macos/WGExtension/*`（Provider 壳 + entitlements + Info.plist）
- `apple/PacketTunnelProvider.WireGuardKit.swift.example`（可扫进目标的完整 WireGuardKit 实现，来自 wireguard_flutter example / MIT）

**未提交**：Apple Team ID、Provisioning Profile、证书、App Store Connect 密钥。

### iOS / macOS — 剩余 Xcode 步骤（精确）

> 需要：**付费** Apple Developer Program、本机 Xcode、用户提供的 **Team ID**。

#### A. Developer Portal（网页）

1. Identifiers → 注册/编辑 App ID `com.netbridge.netbridge`  
   - Capabilities：**App Groups**、**Network Extensions**（Packet Tunnel）  
2. 新建 App ID `com.netbridge.netbridge.WGExtension`（App Extension）  
   - 同样启用 App Groups + Network Extensions  
3. App Groups → 创建 `group.com.netbridge.netbridge`，挂到上述两个 App ID  
4. Profiles：为 Host + Extension 各生成 Development（真机）/ Distribution（发版）描述文件  

#### B. Xcode — 创建并嵌入 Extension 目标

对 **iOS**（`ios/Runner.xcworkspace` 或 `Runner.xcodeproj`）与 **macOS** 各做一遍：

1. File → New → Target → **Network Extension** → **Packet Tunnel Provider**  
2. Product Name: `WGExtension`  
3. Bundle Identifier: **`com.netbridge.netbridge.WGExtension`**（必须与 Dart `providerBundleIdentifier` 一致）  
4. Language: Swift；取消勾选多余模板文件，改用仓库已有源码：  
   - 将 Target 的源文件指到 `ios/WGExtension/PacketTunnelProvider.swift`（macOS 用 `macos/WGExtension/`）  
   - `Info.plist` → 仓库 `WGExtension/Info.plist`  
   - Signing & Capabilities → entitlements 选 `WGExtension.entitlements`  
5. Runner target → **Signing & Capabilities**  
   - Team: 选择你的 Team（填入 Team ID）  
   - 确认 entitlements 为 `Runner/Runner.entitlements`（iOS）或现有 macOS entitlements  
   - App Groups 勾选 `group.com.netbridge.netbridge`  
6. WGExtension target → 同一 Team；同一 App Group  
7. Runner → Build Phases → **Embed Foundation Extensions** 必须包含 `WGExtension.appex`  
8. Deployment：iOS **15.0+**、macOS **12.0+**（与 `wireguard_flutter` 一致）

#### C. 接入真实 WireGuard（生产隧道）

脚手架 `PacketTunnelProvider.swift` 在收到 `wgQuickConfig` 后会返回 `wireGuardKitNotLinked`（有意）。

1. File → Add Package Dependencies → 添加官方 **WireGuardKit**（wireguard-apple / 与 wireguard_flutter example 相同来源）  
2. 将 WireGuardKit **只**链到 **WGExtension** target（Host 一般不需要）  
3. 用 `apple/PacketTunnelProvider.WireGuardKit.swift.example` **替换**脚手架 `PacketTunnelProvider.swift`（或合并 `WireGuardAdapter` 逻辑）  
4. 确认 `providerConfiguration["wgQuickConfig"]` 解析路径与 example 一致（`wireguard_flutter` 插件写入同名字段）

#### D. 打开 Dart 真隧道开关

1. 确认真机/模拟器上 Extension 已嵌入且签名成功  
2. 编辑 `lib/services/vpn/apple_tunnel_config.dart`：  
   `static const bool extensionTargetLinked = true;`  
3. `flutter run` → 连接时应走 `WireGuardVpnTunnel`；失败仍会回退 Stub  

#### E. 验证清单

- [ ] Host + Extension 同 Team、同 App Group  
- [ ] `providerBundleIdentifier` == Extension Bundle ID  
- [ ] 系统 VPN 权限对话框出现（C-10）  
- [ ] 能连自建节点（需 Linux VPS）  
- [ ] 设置页「隧道能力」不再显示 Stub 文案  

### Windows — 下一步

1. 以管理员身份运行或安装时声明 requireAdministrator  
2. 验证 `wireguard_flutter` 创建隧道  
3. Kill Switch：在隧道断开时用 Windows Filtering Platform / 防火墙规则阻断非隧道流量（当前未实现）

## Kill Switch

- 设置页开关，**默认开启**（FR-C09）  
- 偏好持久化；真实「断隧道即阻断」仅在平台原生能力具备时生效  
- 诚实文案见设置页与本文件矩阵

## 错误码中文（设计 C-03 / C-12）

| 码 | 文案 |
|----|------|
| E_URI_SCHEME | 不是有效的 nbvpn 链接，请确认以 nbvpn: 开头。 |
| E_URI_VERSION | URI 版本不受支持，请使用 nbvpn:1? 形式或升级客户端。 |
| E_URI_DECODE | 无法解析配置内容（Base64 或 JSON 无效）。 |
| E_PROFILE_INVALID | 配置字段无效：… |
| E_PROFILE_UNSUPPORTED | 配置版本过高，请升级客户端后再导入。 |

（英文见 `ProfileException.messageEn` / `messageForLanguage`。）

## 已知限制

1. 桌面端未做系统托盘快捷连接（设计 should）  
2. 扫码：相机 + **从相册选图** + 同页粘贴 URI；终端密 QR 仍建议 `--uri` / `peers/*.png`  
3. `.conf` 导入为 should，当前仅 `.nbvpn.json`  
4. 日志侧已避免打印私钥；调试时请勿手动 dump profile  
5. 自动重连：依赖 `wireguard_flutter` 的 `reconnect` / `wait_connection` 阶段映射；Stub 可模拟重连  
6. iOS/macOS：**无 Team ID 时无法完成签名与真隧道**；脚手架 + Stub 不关闭 DEF-02  
7. 自建联调：`ssh netbridge-vps` → `nbvpn show --uri`（警告在 stderr）/ 拷贝 `peers/*.png`；粘贴可含 WARNING 行或 JSON。本环境无 Android 设备时无法完成本轮真握手  
8. **不要声称** iOS/macOS Extension 生产就绪：默认 `extensionTargetLinked=false` → Stub  
9. 重复导入：同 endpoint+公私钥已存在时 Snackbar「已添加」，删除后安全存储写 `[]`，同一 URI 可再导入  
10. `BrandLinks` 的 Terms/Privacy 为 store meta 风格 **占位 URL**，上架前必须换成正式法务页  

## 品牌

- 名称：网桥 VPN / NetBridge VPN（EN）  
- 色：深青灰 `#0F1C24`、强调青 `#2EC4B6`  
- 字体：系统默认（可读性优先）  
- **应用图标**：源图 `assets/branding/netbridge_icon_1024.png`（桥/双节点连线主题）；经 `flutter_launcher_icons` 写入 Android `mipmap-*` / adaptive、iOS/macOS `AppIcon.appiconset`、Windows `app_icon.ico`。重生成：`dart run flutter_launcher_icons`  
- **链接常量**：`lib/config/brand_links.dart`（`officialSite` 默认 = store `openlistBrowse`）

## Android 发布瘦身

- `android/app/build.gradle.kts` release：`minifyEnabled` / `shrinkResources` + `proguard-android-optimize.txt` + `proguard-rules.pro`（WireGuard / flutter_secure_storage / Play Core dontwarn）
- 产物：`flutter build apk --release --split-per-abi` → `dist/NetBridge-android-arm64.apk`（及 armeabi-v7a）；仍为 debug 签名便于侧载试用
