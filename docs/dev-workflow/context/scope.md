# Scope — 做 / 不做

> **冲突裁决**：以本文件最新内容 + 用户确认记录为准。不确定项不得猜，写入 `open-questions.md`。

## 做

| ID | 项 | 备注 / 验收指向 |
|----|-----|-----------------|
| IN-01 | WireGuard 协议（唯一隧道协议） | 用户已确认 |
| IN-02 | Linux 服务端安装包：Debian、Ubuntu、CentOS、RHEL | 常见发行版全覆盖；一键/命令行 |
| IN-02b | Windows Server 服务端：`nbvpn.exe` + PowerShell 安装（WireGuard for Windows / Wintun） | MVP：交叉编译、install.ps1、URI/QR/文件；NAT 见 WINDOWS.md 诚实缺口 |
| IN-03 | 服务端 CLI `nbvpn`：快速使用、查看已装配置、管理服务 | 无桌面也须终端二维码 |
| IN-04 | 连接信息三形态：配置文件 + `nbvpn:` URI + 二维码 | 内容等价，可互转 |
| IN-05 | 客户端四端同步开发交付：Windows、macOS、Android、iOS | iOS 与 Windows 业务同步，非裁剪分批 |
| IN-06 | 客户端：默认无服务器；粘贴/导入/扫码添加；本地自定义名称 | |
| IN-07 | 下载站落地页（走专门 store 分发）：客户端与服务端安装包分区下载 | 无中心节点列表；非离线全集包 |
| IN-08 | 完全去中心化：无官方节点、无强制账号 | |
| IN-09 | 客户交付级验收：全量功能按 acceptance 验收，不裁 MVP | 目标类型 B |

## 不做

| ID | 项 | 原因 |
|----|-----|------|
| OUT-01 | 官方运营的公共 VPN 节点 / 节点目录 | 去中心化 |
| OUT-02 | 强制注册/账号体系作为连接前提 | 去中心化 |
| OUT-03 | 多协议（OpenVPN/IPSec 等）并列 | WireGuard only |
| OUT-04 | 依赖桌面 GUI 才能展示服务端二维码 | 无桌面也须可扫 |
| OUT-05 | ~~Windows Server 服务端安装包~~ | **已移入做**：见 IN-02b（2026-08-14 用户确认「增加 windows 服务端」）；本行保留 ID 以免文档断链 |
| OUT-06 | 裁剪版 MVP / 先砍平台再补 | 用户明确全量同步 |
| OUT-07 | 离线安装包全集（一次性打包全端+全发行版介质） | 用户确认仅下载站/store 分发 |

## 假设（默认成立，除非被推翻）

| ID | 假设 | 若推翻则影响 |
|----|------|--------------|
| ASSUME-01 | Debian 11+ / Ubuntu 20.04+ / RHEL 8+ / CentOS Stream 8+；Rocky Linux 与 AlmaLinux 8+/9 同等支持（见 `01-spec.md` BR-02） | 再扩其他发行版（如 openSUSE/Arch）需改 scope |
| ASSUME-05 | Windows Server 节点依赖官方 WireGuard for Windows（Wintun）；客户端出网 NAT 优先 New-NetNat，失败则 RRAS/ICS | 完整与 Linux iptables 对等需额外运维步骤（见 `server/install/windows/WINDOWS.md`） |
| ASSUME-02 | URI scheme 与 CLI 同名：`nbvpn:` | 规格冻结时改名需改全端 |
| ASSUME-03 | 终端二维码用 ASCII/Unicode 块字符渲染 | 极简终端兼容 |
| ASSUME-04 | 「全量同步」= 契约冻结后服务端 / 四端客户端 / 落地页并行实现，统一验收交付 | 资源不足时需用户改排期 |

## 已确认变更

| 日期 | 原范围 | 新范围 | 确认方式 |
|------|--------|--------|----------|
| 2026-08-14 | 分析草案 | WG、去中心化、三形态、CLI 二维码、落地页 | 用户会话 |
| 2026-08-14 | 待定目标/MVP/平台节奏 | 交付客户；不裁 MVP 全量同步；iOS∥Windows 客户端业务同步；CLI=`nbvpn`；开 intake | 用户会话 |
| 2026-08-14 | Linux 假设偏 Debian/Ubuntu | 明确含 Debian、Ubuntu、CentOS、RHEL | 用户会话 |
| 2026-08-14 | 交付介质未定 | 仅下载站/store；不做离线全集 | 用户会话 |
| 2026-08-14 | OUT-05 Windows Server 不做 | **纳入** IN-02b Windows Server MVP | 用户会话「增加 windows 服务端」 |

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | 用户（会话） |
| 2026-08-14 | 关闭引导项并固化全量范围 | 用户（会话） |
| 2026-08-14 | IN-02 固化四类常见 Linux | 用户（会话） |
| 2026-08-14 | OUT-07 不做离线全集；分发走 store | 用户（会话） |
| 2026-08-14 | OUT-05→IN-02b：Windows Server 服务端 MVP | 用户（会话） |
