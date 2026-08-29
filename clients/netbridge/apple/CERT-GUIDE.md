# 苹果证书申请与打包指引（macOS Developer ID + iOS App Store）

目标：
- **iOS** → TestFlight / App Store：`Apple Distribution` 证书 + App Store provisioning profiles
- **macOS** → Developer ID 直发：`Developer ID Application` 证书 + Apple 公证（不需要 provisioning profile）

前置：付费 Apple Developer Program 账号（$99/年）。免费 Personal Team **无法**使用 Network Extension 能力。

---

## 0. 本机登录付费账号（一次性）

1. 打开 Xcode → Settings → Accounts → `+` → 登录付费账号的 Apple ID。
2. 登录后选中该账号，记录右侧显示的 **Team ID**（形如 `ABCDE12345`）。LH2LR8BBJ2
3. 终端确认：`xcodebuild -showBuildSettings` 或 `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`

## 1. 申请两张证书（developer.apple.com）

本仓库已生成 CSR：`clients/netbridge/apple/NetBridge.certSigningRequest`（私钥 `NetBridge-cert.key` 在本机，**勿提交/勿丢失**）。

1. 登录 https://developer.apple.com/account → **Certificates, Identifiers & Profiles**。
2. **Certificates → `+`**，选择类型：
   - **Apple Distribution**（用于 iOS App Store / TestFlight）
   - **Developer ID Application**（用于 macOS 直发）
   - 每种类型各创建一次，上传同一份 `NetBridge.certSigningRequest`。
3. 下载两份 `.cer`，双击安装进钥匙串（登录钥匙串）。
4. 验证：`security find-identity -v -p codesigning` 应出现
   `Apple Distribution: …` 与 `Developer ID Application: …` 各一条。

> 备选：Xcode → Settings → Accounts → 选中付费账号 → Manage Certificates → `+` 也可创建这两类证书（自动进钥匙串，无需 CSR）。

## 2. 注册 Identifiers 与能力

在 **Identifiers → `+` → App IDs** 逐个注册（Bundle ID 选 Explicit）：

| Bundle ID | 用途 | 能力 |
|---|---|---|
| `com.netbridge.netbridge` | 宿主 App | **Network Extensions** + **App Groups** |
| `com.netbridge.netbridge.WGExtension` | Packet Tunnel 扩展 | **Network Extensions** + **App Groups** |

App Groups：先创建 group，再去 App ID 里勾选：

1. **Identifiers → `+` → App Groups**：Description 随意，Identifier 填 `group.com.netbridge.netbridge`，Register。
2. 进入 **App IDs** 列表，点开 `com.netbridge.netbridge` → Capabilities 勾选 **App Groups** → 在出现的列表里勾 `group.com.netbridge.netbridge` → Save。
3. 对 `com.netbridge.netbridge.WGExtension` 重复第 2 步。
   （顺序不能反：先创建 group，App ID 里才看得到它。）

## 3. Provisioning Profiles

**iOS（必须）：** Profiles → `+` → **App Store Connect** 分发类型，为宿主和扩展各建一个 profile（选对应 App ID、对应证书），下载后双击安装。

**macOS：** 带 Network Extension 的 Developer ID 直发需要 profile：Profiles → `+` →
**Distribution → Developer ID** 类型，为两个 macOS App ID 各建一个（先按第 4 节勾选
NE capability）。不带 NE 的普通 Developer ID 直发才不需要 profile。

## 4. macOS Network Extension 能力（政策已更新，无需单独申请表）

**旧政策**：Developer ID 直发的 NE 需向 Apple 提交申请表单审批（旧链接
`/contact/request/network-extension/` 已被 Apple 301 重定向到 hotspot-helper，
**那个是 Wi-Fi 热点 API 的表单，与 VPN 无关，不要填**）。

**现行政策**（Apple 官方文档《Network Extensions Entitlement》原文）：自助启用，
无申请表：

1. CIRP（Certificates, Identifiers & Profiles）里为 macOS 的 App ID 启用
   **Network Extension** capability（宿主 `com.netbridge.netbridge` + 扩展
   `com.netbridge.netbridge.WGExtension` 都要勾）。
2. **生成并下载 Developer ID provisioning profile**（注意：macOS Developer ID
   直发带 NE 需要 profile，与"Developer ID 不需要 profile"的传统认知不同）。
3. Xcode 手动签名：Developer ID Application 证书 + 该 profile。
4. entitlements 显式含 `com.apple.developer.networking.networkextension`。

**已知约束**（TN3134：Network Extension Provider Deployment）：macOS 上 packet
tunnel 以 **app extension** 形态打包历史上标注 "App Store only"；**system
extension** 形态则支持 Developer ID 直发。当前工程 WGExtension 是 app extension
形态，Developer ID 直发的实际可行性以 CIRP 能否为 macOS App ID 勾选 NE 能力 +
生成 Developer ID profile 为准：**能勾选/能生成 profile → 直发可行；灰掉 →
需改 App Store 或改造 system extension**。

**iOS 无此问题**：iOS packet tunnel app extension 本来就按 App Store 分发。

## 5. App Store Connect 建 App（iOS）

1. https://appstoreconnect.apple.com → My Apps → `+` → New App。
2. Bundle ID 选 `com.netbridge.netbridge`，填名称/类别后创建。

## 6. 公证凭据（macOS）

任选其一，在终端执行：

```bash
# 方式 A：App Store Connect API Key（推荐）
xcrun notarytool store-credentials NetBridge \
  --apple-id <AppleID> --team-id <TEAM_ID> --password <App专用密码>

# 方式 B：App Store Connect API Key（IssuerID + KeyID + .p8 文件）
xcrun notarytool store-credentials NetBridge \
  --issuer <IssuerID> --key-id <KeyID> --key <path/to/AuthKey.p8>
```

---

**状态（2026-08-29）：全部完成。**
证书、profiles、Team 切换、iOS IPA（App Store）、macOS system extension 改造 +
Developer ID 签名 + 公证 + DMG 均已产出，见 `dist/`。macOS 公证前重签要点
（去 get-task-allow + --timestamp）与版本同步注意事项见 `apple/README.md`。
