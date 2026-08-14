# Implementation notes — nbvpn

> T03 Backend · T04 Clients · T05 Store  
> 契约：`03-contract.md`（已冻结）  
> 日期：2026-08-14（续：per-distro install + 客户端 dist 试用包）

## Backend（T03 / S02）

- **路径**：`server/nbvpn/`（模块 `github.com/netbridge/nbvpn`）
- **安装（per-distro）**：
  - 入口：`server/install/install.sh`（检测发行版 → 分发）
  - deb 系：`deb-family.sh`、`debian.sh`、`ubuntu.sh`
  - rhel 系：`rhel-family.sh`、`centos.sh`、`rhel.sh`（Rocky/Alma 同系）
  - **Windows Server MVP**：`server/install/windows/install.ps1` + `WINDOWS.md`；依赖 WireGuard for Windows
  - 公共：`_common.sh`（二进制查找 / `nbvpn install` / 提示）
- **联调**：`smoke-verify.sh`；`VPS-SMOKE.md`；`FIREWALL.md`；试用：`TRY-CONNECT.md`
- **Release**：`scripts/build-release.sh` → linux amd64/arm64 + **windows amd64**
  - linux-amd64 SHA256 `1045f580ae4a17f4ef14a283d2e139779d02f9a5fc165e61193054e92ae52715`
  - windows-amd64.exe SHA256 `5c0a3a463c6446a7a69a8b4680466382d32d9f750ed9951c95d7d85a2a294b99`
- **VPS**：`/opt/netbridge/server/install/` + `dist/nbvpn-linux-amd64` + `/opt/netbridge/nbvpn` 已同步（Linux 未因 Windows 改动破坏）
- **详述**：`server/nbvpn/IMPL.md`；Windows 缺口见 `WINDOWS.md`

## Frontend — 客户端（T04 / S03）

- **路径**：`clients/netbridge/`
- **试用产物**（`clients/netbridge/dist/`，`scripts/package-dist.sh`）：
  - **Android**：`NetBridge-android.apk`（release + debug 签名，侧载；**真隧道优先**）SHA256 `1caeea6614cb7700b83ade088ffd77e21479e1afb9f6d5e01c51a4accf021a0e`
  - **macOS**：**暂不分发**（CI 不挂 DMG/app.zip）。本机：`flutter run -d macos`；真隧道 = 官方 WireGuard + `nbvpn show --conf`。可选本机 ad-hoc `.app`（不上架）
  - **诚实说明**：无 Team + NE 时 Flutter 内为 **Stub**；业务过网用官方 WireGuard `.conf`
  - 部署目标 macOS 12.0（`wireguard_flutter` 要求）
- **测试**：`flutter test` 全绿；`go test ./...` 全绿
- **详述**：`clients/netbridge/IMPL.md`

## Frontend — Store 落地页（T05 / S04）

- **路径**：`apps/store/` — **未改 CSS**
- **清单**：`releases.json` mock；`installCommand` 指向 `debian.sh` / `ubuntu.sh` / `centos.sh` / `rhel.sh` / **Windows `install.ps1`**；客户端 sha 对齐本机 dist
- **详述**：`apps/store/IMPL.md`

## 已知限制

1. Store 下载链仍为 **MOCK**（DEF-01）。  
2. macOS ad-hoc 包 **不能**声称真 VPN；NE 需 Team（DEF-02）。Android 侧载可试真连。  
3. 云安全组需放行 **UDP 51820**。  
4. 无正式签名/公证（DEF-04）。  
5. **Windows Server NAT**：`New-NetNat` 可能失败 → 需 RRAS/ICS（见 `WINDOWS.md`）；非 Linux iptables 对等。  

## 修订记录

| 日期 | 变更 |
|------|------|
| 2026-08-14 | 合并 T03/T04/T05 实现说明 |
| 2026-08-14 | 终端 QR + PNG；Store vs OpenList；Packet Tunnel 脚手架 |
| 2026-08-14 | VPS Debian 真 wg 冒烟；Store mock 链接；URI 粘贴清洗；ufw 51820；Sync 修复 |
| 2026-08-14 | build-release amd64+arm64；FIREWALL.md；peer/URI UX；客户端导入+错误文案；VPS 热更 |
| 2026-08-14 | per-distro install；Android APK + macOS ad-hoc；TRY-CONNECT；VPS sync |
| 2026-08-14 | macOS 暂不分发：CI skip；Store 标「源码本机」；`nbvpn show --conf`；TRY-CONNECT 本机业务 |
| 2026-08-14 | Windows Server MVP：exe + install.ps1；scope IN-02b；releases.windows |
