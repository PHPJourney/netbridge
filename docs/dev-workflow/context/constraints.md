# Constraints — 约束与禁止

## 合规 / 安全

- 完全去中心化：不提供官方 VPN 节点，不运营用户流量出口
- 隧道协议：WireGuard
- 连接信息须可校验、可轮换策略在规格中明确；私钥不出不应出的边界
- 客户端本地凭据加密存储（系统钥匙串 / Keystore / Keychain 等）
- 安装包提供校验和；目标平台尽量代码签名（Win/macOS/iOS/Android 按平台能力）
- 文档须提示：自建节点的合法使用与出口责任在用户
- 交付标准：客户验收级（目标类型 B），验收以各竖切 `acceptance.md` 为准

## 性能 / 容量

- 服务端面向常见小规格 VPS 可用（具体指标由规格给出）
- 客户端：网络切换与睡眠唤醒后可自动重连；弱网失败原因可见

## 平台 / 兼容

- 目标客户端（同步交付）：Windows、macOS、Android、iOS
- 目标服务端：Debian 11+、Ubuntu 20.04 LTS+、RHEL 8+、CentOS Stream 8+；Rocky/Alma 8+/9 同等支持（见 `01-spec.md` BR-02）；**以及 Windows Server**（`nbvpn.exe` + WireGuard for Windows；见 IN-02b / `server/install/windows/`）
- 服务端交付：即使无桌面环境，`nbvpn` 也须能输出终端二维码（Windows 终端/PowerShell 同要求）
- CLI 命令名：`nbvpn`；URI scheme：`nbvpn:`
- Windows 节点 NAT 与 Linux iptables 对等不强制同一实现路径；须在文档标明 New-NetNat / RRAS / ICS 缺口

## 禁止事项

| ID | 禁止 | 原因 |
|----|------|------|
| FORBID-01 | 客户端内置或默认连接任何官方/第三方节点 | 去中心化产品模型 |
| FORBID-02 | 强制账号才能添加服务器或连接 | 去中心化 |
| FORBID-03 | 仅支持连接信息三形态中的一种 | 用户已要求全部支持 |
| FORBID-04 | 服务端只能在有 GUI 时展示二维码 | 用户要求无桌面也可 |
| FORBID-05 | 以「先砍平台」方式缩小本次客户交付范围 | 用户明确不裁 MVP、全量同步 |

## 其他硬约束

- 下载**落地页**（`apps/store/`）只做说明与下载入口；**安装包文件存放在 OpenList**（`http://154.37.213.245:5244/store`），不做中心化节点发现；不提供离线安装包全集
- `releases.json` 的下载链指向 OpenList；**未上传前保持「上传后更新」空链，禁止假 CDN / 假 SHA**
- 用户操作路径以「傻瓜式」为准：命令少、输出可复制可扫
- 实现技术栈在空仓下由规格/实现阶段选定并回写 `stack.md`；禁止与 scope 冲突

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | 用户（会话） |
| 2026-08-14 | 交付客户级、四端同步、Linux-only 服务端、`nbvpn` | 用户（会话） |
| 2026-08-14 | 服务端发行版明确为 Debian/Ubuntu/CentOS/RHEL | 用户（会话） |
| 2026-08-14 | 明确 Store UI vs OpenList 产物存储 | 用户（会话） |
| 2026-08-14 | 服务端纳入 Windows Server MVP | 用户（会话） |
