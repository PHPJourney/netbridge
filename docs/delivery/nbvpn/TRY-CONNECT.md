# 试用连接步骤（nbvpn）

> 本机试用：安装客户端 → 从 VPS 取 URI → 粘贴导入 → 连接。  
> **不是** App Store / 正式分发说明。macOS 为 **本机 ad-hoc 签名**；iOS 无 Team 时 IPA 为 **未签名流水线产物**，普通设备无法安装。

## 0. 前置

- VPS 上 nbvpn 已安装并运行（Debian 12 示例主机别名：`netbridge-vps`）
- **云安全组 + 本机防火墙** 已放行 **UDP 51820**（或你配置的 listen 端口）  
  见 `server/install/FIREWALL.md`
- 客户端产物见 `clients/netbridge/dist/`（本机构建：`./scripts/package-all.sh`）

## VPN 能力矩阵（诚实）

| 平台 | 安装包 | 签名 | 真实 WireGuard 隧道 |
|------|--------|------|---------------------|
| **Android** | `NetBridge-android-arm64.apk` | debug-signed（可侧载） | **可用**（系统 VPN 授权） |
| **Windows** | `NetBridge-windows.exe` / portable.zip | 无 Authenticode | **可能可用**；常需 **管理员** 运行 |
| **macOS** | `NetBridge-macOS.dmg` | ad-hoc（不上架） | **受限**：无 Apple Team + NE 时多为 Stub（UI/导入） |
| **iOS** | `NetBridge-iOS.ipa` | 需 Team；否则 UNSIGNED | **受限**：同 macOS；未签名包 **不能**装到普通设备 |

## 1. 安装客户端

### Android（优先，真隧道可用）

1. 将 `clients/netbridge/dist/NetBridge-android-arm64.apk`（或同目录 `NetBridge-android.apk`）拷到手机
2. 允许「未知来源」安装（调试/本机签名包；R8 slim arm64）
3. 打开 **网桥 VPN** → 添加节点 → 粘贴 URI

### Windows

1. 在 **Windows 机器**上构建（macOS 无法交叉编译），见 `clients/netbridge/dist/WINDOWS-BUILD.md`
2. 解压 `NetBridge-windows-portable.zip` 并运行其中的 exe，或直接运行 `NetBridge-windows.exe`（需同目录 DLL）
3. 连接 VPN 时若失败，尝试 **以管理员身份运行**
4. 打开应用 → 添加节点 → 粘贴 URI

### macOS（本机 ad-hoc / 自签，非 App Store）

1. 打开 `clients/netbridge/dist/NetBridge-macOS.dmg`，将 **NetBridge.app** 拖到 Applications（或直接用同目录 `.app` / `.zip`）
2. 若 Gatekeeper 拦截：**右键 → 打开**，或到「系统设置 → 隐私与安全性」允许
3. 校验签名（可选）：
   ```bash
   codesign -dv --verbose=2 clients/netbridge/dist/NetBridge-macOS.app
   # ad-hoc 时 Authority 通常显示 adhoc / signed by -
   ```
4. 打开应用 → 添加节点 → 粘贴 URI

**诚实说明（macOS 隧道）**

- 本包为 **ad-hoc / 本地自签**，**不**具备 App Store / Developer ID 公证能力。
- Network Extension + 真 WireGuard 隧道通常仍需 **Developer Team + NE entitlements**；在仅 ad-hoc 下，应用可能落在 **Stub 隧道**（可测 UI / 导入 / 列表），**不能保证**系统级 VPN 握手。
- **真机联调优先用 Android APK**。

### iOS（需 Apple 凭证才能真机安装）

1. 若 `dist/NetBridge-iOS.ipa` 标注 **UNSIGNED**：仅流水线占位，**无法**装到非开发设备。
2. 真包需要：付费 Developer 账号、`APPLE_TEAM_ID`、证书、描述文件、`ios/ExportOptions.plist`（见 `dist/IOS-IPA-README.txt` 与 `ios/ExportOptions.plist.example`）。
3. 即便签上名，Packet Tunnel 真连仍需挂上 NE Extension（见 `apple/README.md` / `IMPL.md`）。

## 2. 从 VPS 获取 URI

在开发机：

```bash
# 现有默认 peer 的 URI
ssh netbridge-vps 'nbvpn show --uri'

# 或为试用新建 peer（推荐独立 peer，便于撤销）
ssh netbridge-vps 'nbvpn peer add --name try-$(date +%Y%m%d)'
# 再取 URI（或 peer add 输出中的 URI）
ssh netbridge-vps 'nbvpn show --uri'
```

URI 形如：`nbvpn:1?<base64url>…`（只复制 stdout；stderr 可能有提示）。

## 3. 客户端导入并连接

1. 打开客户端 → **添加** → **粘贴 URI**（推荐）或 **扫描二维码**
2. 确认节点信息（endpoint 应为 VPS 公网 IP:51820）
3. 点连接；Android 首次会弹出系统 VPN 授权，需允许
4. 预期：状态变为已连接；可用 `ssh netbridge-vps 'nbvpn status'` 看握手

### 3.1 扫码说明（终端 QR 较密）

`nbvpn show` 终端二维码 = 完整 `nbvpn:1?<base64url>`，载荷长、矩阵密，手机摄像头偶发难扫属正常。

| 做法 | 说明 |
|------|------|
| 拉近 / 开闪光灯 | 扫码页支持手电筒；对准取景框中央大窗 |
| **从相册选图** | 扫码页可选手动拍的照片，或 VPS 上 `peers/<id>.png` 拷到手机 |
| **粘贴 URI** | 同页可粘贴；或 `ssh … 'nbvpn show --uri'` 干净单行 |
| 重复导入 | 同一 endpoint+密钥已在列表 → Snackbar **「已添加」**（非静默） |
| 删除后再扫 | 删除会写回安全存储；同一 URI/QR 应可再次进入确认添加 |

## 4. 服务端一键安装（新机器）

```bash
# 自动识别发行版
curl -fsSL <CDN>/install.sh | sudo bash

# 或按发行版
curl -fsSL <CDN>/debian.sh | sudo bash    # Debian
curl -fsSL <CDN>/ubuntu.sh | sudo bash    # Ubuntu
curl -fsSL <CDN>/centos.sh | sudo bash    # CentOS / Rocky / Alma
curl -fsSL <CDN>/rhel.sh | sudo bash      # RHEL 同系

# 仓库内：
sudo ./server/install/install.sh
# 或 sudo ./server/install/deb-family.sh | rhel-family.sh
```

二进制：设置 `NBVPN_BINARY_URL=…/nbvpn-linux-amd64`，或把 `server/nbvpn/dist/` 放到机器上。

## 5. 常见失败

| 现象 | 检查 |
|------|------|
| 一直连不上 | 云安全组 / ufw 是否放行 **UDP 51820** |
| **有 VPN 钥匙图标 + 流量在跳，但 App 没网** | **服务端缺 IP 转发 / NAT（最常见）** — 见下方 §5.1 |
| Android 无授权框 | OEM 权限；重装 APK |
| 状态栏完全没有 VPN 图标 | 隧道可能未真正 up；与「有图标没网」不同，先看系统 VPN 授权 |
| macOS 能导入不能真连 | 预期可能（ad-hoc 无 NE）；改用 Android |
| URI 无效 | 去掉引号/换行；用 `nbvpn show --uri` 干净输出 |
| 扫码无反应 / 第二次扫不动 | 更新 APK：扫码页会 pause/resume；重复配置应提示「已添加」；失败可「重试」或相册/粘贴 |
| 删除后再扫仍无效 | 先确认列表已空；改用粘贴 URI 或 `peers/*.png` 相册识别（多为密 QR 识别失败，非删不干净） |

### 5.1 VPN 已连接但没网（服务端 NAT）

症状：Android 状态栏有钥匙/VPN 图标，通知栏流量计数在动，但浏览器/App 打不开网页。

根因：全隧道 `AllowedIPs=0.0.0.0/0` 把流量送进隧道，但 VPS **未开启转发或未做 MASQUERADE**，包到了节点却出不去 / 回不来。

在 VPS 上检查：

```bash
# 应有 recent handshake；transfer 两侧都应增长（仅 received、sent≈0 多为无 NAT）
sudo wg show

sysctl net.ipv4.ip_forward          # 必须为 1
sudo iptables -t nat -L POSTROUTING -n -v | grep -i MASQUERADE
# ufw 默认 FORWARD=DROP 时还需：
grep DEFAULT_FORWARD_POLICY /etc/default/ufw   # 期望 ACCEPT
```

临时修复（新版 `nbvpn install` / `wg-quick@nbvpn` 的 PostUp 会持久化）：

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-nbvpn-forward.conf
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw reload
# 然后重写并重启隧道（部署含 PostUp 的 nbvpn 后）:
sudo nbvpn install    # 或更新二进制后再 install / restart
sudo systemctl restart wg-quick@nbvpn
```

重测：手机断开再连 → 能打开网页；`wg show` 中 **sent** 与 **received** 都在增加。

## 产物路径速查

| 产物 | 路径 |
|------|------|
| 服务端 amd64 | `server/nbvpn/dist/nbvpn-linux-amd64` (+ `.sha256`) |
| 安装入口 | `server/install/install.sh` |
| deb 系 | `server/install/deb-family.sh`、`debian.sh`、`ubuntu.sh` |
| rhel 系 | `server/install/rhel-family.sh`、`centos.sh`、`rhel.sh` |
| 客户端打包 | `clients/netbridge/scripts/package-all.sh` |
| Android APK | `clients/netbridge/dist/NetBridge-android-arm64.apk` |
| Windows exe | `clients/netbridge/dist/NetBridge-windows.exe`（需 Windows 构建） |
| macOS DMG | `clients/netbridge/dist/NetBridge-macOS.dmg` |
| iOS IPA | `clients/netbridge/dist/NetBridge-iOS.ipa`（无 Team 则为未签名 stub） |
