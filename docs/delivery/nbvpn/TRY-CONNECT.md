# 试用连接步骤（nbvpn）

> 本机试用：安装客户端 → 从 VPS 取 URI → 粘贴导入 → 连接。  
> **不是** App Store / 正式分发说明。  
> **macOS 暂不分发**（无 DMG / app.zip 上架 Releases / OpenList / Pages）：以 **源码本机业务** 为主，见下方「本机 macOS 业务」。  
> iOS 无 Team 时 IPA 为 **未签名流水线产物**，普通设备无法安装。

## 0. 前置

- VPS 上 nbvpn 已安装并运行（Debian 12 示例主机别名：`netbridge-vps`）
- **云安全组 + 本机防火墙** 已放行 **UDP 51820**（或你配置的 listen 端口）  
  见 `server/install/FIREWALL.md`
- 客户端产物见 `clients/netbridge/dist/`（本机构建：`./scripts/package-all.sh`）

## VPN 能力矩阵（诚实）

| 平台 | 安装包 | 签名 | 真实 WireGuard 隧道 |
|------|--------|------|---------------------|
| **Android** | `NetBridge-android-arm64.apk` | debug-signed（可侧载） | **可用**（系统 VPN 授权） |
| **Windows** | **`NetBridge-windows-setup.exe`**（推荐）/ portable.zip | 无 Authenticode | **可能可用**；常需 **管理员** 运行 |
| **macOS** | **暂不分发**（源码 / 可选本机 ad-hoc `.app`） | 无 NE 签名 | Flutter UI：**Stub**；**真隧道**用官方 WireGuard + `nbvpn show --conf` |
| **iOS** | `NetBridge-iOS.ipa` | 需 Team；否则 UNSIGNED | **受限**：同 macOS；未签名包 **不能**装到普通设备 |

## 1. 安装客户端

### Android（优先，真隧道可用）

1. 将 `clients/netbridge/dist/NetBridge-android-arm64.apk`（或同目录 `NetBridge-android.apk`）拷到手机
2. 允许「未知来源」安装（调试/本机签名包；R8 slim arm64）
3. 打开 **网桥 VPN** → 添加节点 → 粘贴 URI

### Windows

1. 从 GitHub Releases / 商店页下载 **`NetBridge-windows-setup.exe`**，以管理员运行安装（开始菜单 / 可选桌面快捷方式）
2. 备用：解压 `NetBridge-windows-portable.zip` 并运行其中的 `netbridge.exe`
3. 连接 VPN 时若失败，尝试 **以管理员身份运行**
4. 打开应用 → 添加节点 → 粘贴 URI（或扫描服务端 `.png` 二维码）
5. 构建说明见 `clients/netbridge/dist/WINDOWS-BUILD.md` / `clients/netbridge/installer/windows/`

### 本机 macOS 业务（推荐路径 · 暂不分发）

> CI / Releases / OpenList / Pages **不**提供 macOS DMG 或 `.app.zip` 下载。  
> 目标：本机业务使用（UI 联调 + 真 WireGuard 隧道），不是面向用户分发。

#### A. Flutter 客户端（UI / 导入 · Stub 隧道）

```bash
cd clients/netbridge
flutter pub get
flutter gen-l10n
flutter run -d macos
```

- 无 Apple Team + Network Extension 时，应用内 VPN 多为 **Stub**（可测列表、粘贴 URI、扫码），**不能保证**系统级隧道。
- 可选本机 ad-hoc `.app`（仅本机，不上架）：`./scripts/package-all.sh`（或 `SKIP_MACOS=0` 默认路径产出 `dist/NetBridge-macOS.app` / `.dmg`）。**不要**把该包放进 OpenList / Pages 下载区。

#### B. 真 VPN 隧道（无 NE 签名）：官方 WireGuard + `nbvpn show --conf`

1. 安装 [官方 WireGuard for macOS](https://www.wireguard.com/install/)（App Store / wireguard.com）。
2. 在 **已安装 nbvpn 的节点**上导出客户端配置：
   ```bash
   # 打印 .conf 路径（含私钥；勿公开）
   ssh your-vps 'sudo nbvpn show --conf'
   # 或 show --all / --file：同目录会写出 <peer-id>.conf
   scp your-vps:/var/lib/nbvpn/peers/<peer-id>.conf ~/Downloads/
   ```
3. 打开官方 WireGuard → **Import tunnel(s) from file…** → 选该 `.conf` → 激活隧道。
4. 用 `ssh your-vps 'nbvpn status'` / `sudo wg show` 确认 handshake。

**诚实说明**

- 分发通道：**Android + Windows 客户端**；macOS **源码本机**；iOS **仍跳过签名**。
- 真机联调若只想「一键 App 内隧道」，优先 **Android APK**；Mac 上要过网请用路径 B。

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

**吊销 vs 删除：** `peer revoke <id|name>` 立即失效 URI/QR，但 `peer list` 仍显示为 revoked（留审计）；`peer delete <id|name> [--yes]` 永久删除记录与全部导出文件。两者都不会回收该 peer 的 VPN IP。

URI 形如：`nbvpn:1?<base64url>…`（只复制 stdout；stderr 可能有提示）。

## 3. 客户端导入并连接

1. 打开客户端 → **添加** → **粘贴 URI**（推荐）或 **扫描二维码**
2. 确认节点信息（endpoint 应为 VPS 公网 IP:51820；若服务端启用了 IPv6，可看到 endpointV6 与「IPv6 已启用/未启用」）
3. 点连接；Android 首次会弹出系统 VPN 授权，需允许
4. 预期：状态先显示「正在验证握手…」，通过后变为已连接；若约 25 秒内握手/出口探测失败，会断开并提示「握手失败，可能被机房封禁 UDP 或 NAT 未配置」
5. 服务端可用 `ssh netbridge-vps 'nbvpn status'` / `sudo wg show` 看握手

### 3.0 启用 IPv6（可选）

服务器有 IPv6 公网地址时：

```bash
ssh netbridge-vps 'sudo nbvpn config set endpoint-v6 YOUR_IPV6'
# 或显式端口 / 开关：
# sudo nbvpn config set endpoint-v6 '[2001:db8::1]:51820'
# sudo nbvpn config set ipv6 on|off
ssh netbridge-vps 'nbvpn show --uri'   # 重新导出；URI 含 endpointV6 + ipv6Enabled
```

同时确认云安全组与主机防火墙放行 **UDP 51820（IPv6）**。客户端编辑服务器页可查看/切换「使用 IPv6 endpoint」。WireGuard **同时只连一个 Endpoint**（启用 IPv6 时用 V6，否则用主 endpoint）。

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
| **App 提示握手失败** | 客户端在隧道接口 up 后会做 HTTP 出口探测（约 25s）。无握手 / UDP 被封 / NAT 未配时会断开并提示；VPS 上查 `wg show` 是否无 recent handshake、`MASQUERADE` 是否为 0 |
| **有 VPN 钥匙图标 + 流量在跳，但 App 没网** | **服务端缺 IP 转发 / NAT（最常见）** — 见 §5.1、§5.4；**不是**分流导致 |
| Android 无授权框 | OEM 权限；重装 APK |
| 状态栏完全没有 VPN 图标 | 隧道可能未真正 up；与「有图标没网」不同，先看系统 VPN 授权 |
| macOS Flutter 能导入不能真连 | 预期（无 NE）；改用「本机 macOS 业务」路径 B（官方 WireGuard + `.conf`）或 Android |
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

### 5.2 VPN 与车机 / 局域网冲突

默认 peer / 客户端配置里 **`AllowedIPs = 0.0.0.0/0, ::/0`** 表示 **全隧道（full tunnel）**：除极少数例外，**所有** IPv4/IPv6 流量都会经 VPN 出去，不再走本机直连的局域网路由。

因此，VPN **已连接** 时常见现象：

| 场景 | 可能表现 |
|------|----------|
| 连 **车机热点** / 车内 Wi‑Fi | 手机与车机在同一局域网，但流量被送进隧道，车机 App、投屏、OTA 等异常 |
| **蓝牙 PAN** / 手机互联（CarPlay、HiCar 等） | 依赖本地链路的镜像、通知、控车指令被 VPN 路由干扰 |
| **遥控解锁 / 本地控车 App** | 需访问厂商局域网或近场服务时失败或极慢 |
| 普通 **家庭 / 办公 Wi‑Fi** 下的局域网设备 | 打印机、NAS、智能家居等同理（非车机也会中招） |

**当前产品内置可选「自动分流（排除私网）」**（设置 → **默认关闭**，全隧道）：开启后，连接时若配置含 `0.0.0.0/0` / `::/0`，客户端会改写 AllowedIPs，私网 / 车机 / 蓝牙不走隧道，**公网仍经 VPN**。修改开关后需 **断开再连** 生效。

仍可选做法：

1. **用车前断开 VPN**（最简单、最稳）。
2. **设置 → 开启「自动分流（排除私网）」**（推荐有车机/局域网需求时）。
3. **macOS / iOS 官方 WireGuard**：导入 `.conf` 后勾选 **Exclude private networks**（若客户端提供），私网流量不走隧道。
4. **在本应用缩小 Allowed IPs（仅 VPN 网段）**：打开节点 → **编辑服务器** → **Allowed IPs** 字段，例如改为仅 VPN 内网 `10.8.0.0/24`（及你的节点网段），**不要**保留 `0.0.0.0/0`。保存后断开再连生效。  
   - 效果：只有访问该网段走 VPN，公网也不经 VPN。  
   - 代价：其余公网流量不再经 VPN（需自行权衡）。
5. **关闭自动分流**：设置 → 关闭「自动分流（排除私网）」→ 断开再连，恢复全隧道（默认即如此）。

**服务端安装可选分流**（新机器）：`NBVPN_SPLIT_TUNNEL=1 sudo ./server/install/install.sh` 或 `nbvpn install --split-tunnel`，新 peer 的 profile 中 `allowedIPs` 仅为 VPN 网段（如 `10.8.0.0/24`），公网不经 VPN。与客户端「自动分流」不同：服务端分流在 profile 层缩小路由，客户端分流在连接时改写全隧道 CIDR。

若你刚排查完 §5.1「有 VPN 图标但没网」，请先确认服务端 NAT；本节解决的是 **隧道已通，但本地 / 车机侧功能不可用** 的另一类问题。

### 5.3 三种「没网」如何区分

| 类型 | 症状 | 根因 | 与分流的关系 |
|------|------|------|--------------|
| **A. 全隧道 + 服务端 NAT 故障** | VPN 图标在、流量计数动，**公网网页/App 全打不开** | VPS 未转发 / 无 MASQUERADE / ufw FORWARD=DROP | **无关**。分流开或关，公网仍走 VPN；NAT 坏了就没公网 |
| **B. 全隧道 + 本地/车机** | 公网可能正常，**车机/蓝牙/局域网设备异常** | `0.0.0.0/0` 劫持私网路由 | **有关**。开启 §5.2 自动分流或缩小 AllowedIPs |
| **C. 分流已开但仍无公网** | 私网可能正常，**公网仍打不开** | 仍是 §5.1 NAT/出口问题 | **不是分流导致**；按 §5.4 查服务端出口 |

**你现在的「连上 nbvpn 完全没网」**：若 VPN 图标在且流量在跳，**优先按 A/C 查服务端 NAT 与出口**（§5.1、§5.4），不要先关分流。分流只解决私网/车机冲突，不会让公网 magically 恢复。

### 5.4 服务端出口 / NAT 诊断（在 VPS 上执行）

在 **已 SSH 登录的 VPS** 上运行以下命令，确认节点自身能上网、且 VPN 客户端流量能被 NAT 出去。

```bash
# --- 1) 节点自身能否访问公网（不经 VPN 客户端）---
curl -4 -sS --max-time 5 ifconfig.me && echo
curl -4 -sS --max-time 5 icanhazip.com && echo
# 若这里就失败：VPS 本身无公网出口 / DNS / 上游防火墙问题，先修主机联网

# --- 2) 路由与转发 ---
ip route
sysctl net.ipv4.ip_forward          # 必须为 1

# --- 3) WireGuard 接口 ---
sudo wg show
ip addr show nbvpn 2>/dev/null || ip addr show wg0 2>/dev/null

# --- 4) NAT / MASQUERADE（全隧道客户端上网的关键）---
sudo iptables -t nat -L POSTROUTING -n -v | grep -i MASQUERADE
# 若系统用 nftables：
sudo nft list ruleset 2>/dev/null | grep -i masquerade

# --- 5) ufw / firewalld ---
sudo ufw status verbose 2>/dev/null || true
grep DEFAULT_FORWARD_POLICY /etc/default/ufw 2>/dev/null   # 期望 ACCEPT（全隧道时）
sudo firewall-cmd --list-all 2>/dev/null || true

# --- 6) nbvpn 配置摘要 ---
nbvpn config
nbvpn status
```

**解读要点**

- `curl ifconfig.me` 在 VPS 上成功 → 节点有公网出口；客户端仍无网 → 多半是 **NAT/转发未对 wg 子网生效**（§5.1 修复）。
- `wg show` 有 **recent handshake**，但 **transfer 只有 received、sent≈0** → 客户端发包到了节点，节点未把回程/NAT 做好。
- `MASQUERADE` 规则缺失 → 执行 §5.1 临时修复后 `sudo systemctl restart wg-quick@nbvpn`，手机 **断开再连** 重测。

**客户端侧（手机已连 VPN 时）**

- 手机不便跑 curl；看 **VPN 图标 + 流量计数** 是否在动。
- 图标在、计数动、网页仍打不开 → **先 VPS 上跑上面命令**，不要先改分流。
- 公网正常但车机/打印机不行 → 开 **设置 → 自动分流（排除私网）** 或 §5.2 缩小 AllowedIPs。

## 6. 分流 / 全隧道配置速查

| 层级 | 做法 | 效果 |
|------|------|------|
| **客户端（推荐）** | 设置 → **自动分流（排除私网）** 开关 | 默认关（全隧道）；开启后私网直连、公网仍走 VPN |
| **客户端** | 编辑节点 → Allowed IPs 改为 `10.8.0.0/24` | 仅 VPN 网段走隧道，公网不经 VPN |
| **服务端（新装）** | `NBVPN_SPLIT_TUNNEL=1` 或 `nbvpn install --split-tunnel` | 新 peer profile 仅含 VPN 网段 |
| **服务端（已装）** | 编辑 `server.json` 的 `allowedIPs`，再 `nbvpn install` 修复配置 | 影响新导出 profile；已有 URI 需重新 `show` 导入 |

修改任一侧后，客户端需 **断开再连**（或重新导入 URI）生效。

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
