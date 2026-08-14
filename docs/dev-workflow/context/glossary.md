# Glossary — 领域名词

> 实现与文档中的术语必须与本表一致。未列出的词：先补本表再使用，禁止临场发明同义说法。

| 名词 | 定义 | 非含义 / 易混 |
|------|------|----------------|
| 网桥 VPN / NetBridge | 本产品名称：自建节点 + 多端客户端的 VPN 工具集 | 不是托管型公共 VPN 服务商 |
| 节点 / 服务器 | 用户自有机器上运行的 WireGuard 服务端实例 | 不是官方中心服务器 |
| 连接信息 | 可导入客户端的节点凭据与参数，须支持配置文件、URI、二维码三种等价形态 | 不是「仅展示 IP」 |
| `nbvpn` | 官方服务端 CLI 命令名 | 不是客户端进程的必用名（客户端可为各平台 App 名） |
| `nbvpn:` URI | 形式为 `nbvpn:1?<base64url(JSON)>`，见 `03-contract.md` | 不是网页下载 URL |
| 配置文件 | 主格式 `.nbvpn.json`（NbVpnProfile）；可附带生成 `.conf` | 不是安装包本身 |
| 二维码 | 编码同一连接信息的 QR；服务端无桌面时在终端由 `nbvpn` 绘制 | 不是仅官网展示的静态图 |
| 下载站落地页 | 提供客户端与服务端安装包下载的页面；分发走专门 store | 不是节点列表、账号后台，也不是离线全集 ISO/zip 介质 |
| 本地服务器名称 | 客户端侧用户自定义的显示名 | 可与服务端默认名不同 |
| 去中心化 | 无官方默认节点、无强制账号、节点责任在用户 | 不是无官网/无下载站 |
| 全量同步 | 不裁 MVP；契约冻结后四端客户端、Linux 服务端、落地页并行开发并统一交付验收 | 不是无依赖、无规格直接乱序编码 |
| Windows Server 节点 | 在 Windows Server（或实验室用 Win10/11）上运行的 `nbvpn` 节点；依赖 WireGuard for Windows / Wintun | 不是 Windows **客户端** App；客户端见 IN-05 |
| WireGuard for Windows | 官方 Windows 安装包，提供 `wireguard.exe`、`wg.exe`、Wintun 驱动 | 不是 Linux `wg-quick` / systemd |
| NbVpnProfile | 连接信息规范载荷（JSON，`v=1`），三形态同源；详见 `docs/delivery/nbvpn/03-contract.md` | 不是 wg 服务端私钥文件 |
| store | 专门的在线分发下载站/商店页，承载客户端与服务端包 | 不是 VPN 节点目录 |

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | 用户（会话） |
| 2026-08-14 | 固化 `nbvpn` / `nbvpn:` 与全量同步定义 | 用户（会话） |
| 2026-08-14 | 补充 NbVpnProfile、store；对齐规格 | T01 spec |
| 2026-08-14 | Windows Server 节点 / WireGuard for Windows | 用户确认纳入服务端 |
