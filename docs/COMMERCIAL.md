# NetBridge 商业版说明

## 仓库

| | 公开版 | 商业版 |
|--|--------|--------|
| 仓库 | https://github.com/PHPJourney/netbridge | https://github.com/PHPJourney/netbridge-commercial |
| 可见性 | Public | **Private** |
| 许可 | MIT（根目录 `LICENSE`） | 商业许可（见 `LICENSE-COMMERCIAL.md`；商业仓默认 `LICENSE` 为商业条款） |
| 用途 | 社区开源、自建、按 MIT 使用 | 付费交付、可选白牌、合同约定范围 |

商业仓是**独立私有仓库**（不是公开仓的 GitHub Fork——公开仓无法再改为 private fork）。

## v0.1.16 商业版更新（自动分流）

自 **v0.1.16** 起，客户端提供 **可选** 的 **自动分流（排除私网）**（设置 → 默认关闭，全隧道）：

- 开启后：连接时若 profile 含 `0.0.0.0/0, ::/0`，会改写为与官方 WireGuard Android「Exclude private networks」一致的公网 CIDR 列表
- **公网**仍走 VPN；**10.x / 192.168.x / 链路本地**等私网直连，车机热点、蓝牙互联、本地控车不再被全隧道劫持
- **设置 → 自动分流（排除私网）** 可开关；修改后需 **断开再连**
- **服务端无需重装**；`nbvpn show` 仍导出全隧道 URI（除非安装时 `NBVPN_SPLIT_TUNNEL=1`），客户端分流在连接时生效

### IPv6 / 双公网

服务端与客户端支持可选 **IPv6 endpoint** 与 **启用状态**：

- 服务端：`nbvpn config set endpoint-v6 …`、`nbvpn config set ipv6 on|off`；`nbvpn config` 显示状态
- Profile 可选字段 `endpointV6` / `ipv6Enabled`（向后兼容）；连接时 **单一** WireGuard Endpoint（启用则用 V6）
- 第二 IPv4：用 `config set endpoint` 切换主地址（详见 `server/install/FIREWALL.md`）

商业交付构建（可选品牌标识 + 车机友好默认分流）：

```bash
cd clients/netbridge
flutter build apk --release \
  --dart-define=COMMERCIAL_BUILD=true \
  --dart-define=DEFAULT_EXCLUDE_PRIVATE_NETWORKS=true
```

公开 MIT 仓与商业仓功能一致；`COMMERCIAL_BUILD` 用于白牌 / 交付标识。分流默认关闭，可按需用 `DEFAULT_EXCLUDE_PRIVATE_NETWORKS=true` 开启。

### 明确未包含（截至 v0.1.16）

- **域名 / App 白名单**（按域名或按应用绕过 VPN）：未实现。当前可用替代：手动缩小 Allowed IPs、或开启「自动分流（排除私网）」。若需真正白名单，需另开规格（客户端路由例外 + 可选 DNS 分流）。

## 交付范围（默认）

一次性交付约定版本的源码 / 构建产物与说明文档，通常包括：

- 服务端 `nbvpn` 与安装脚本
- Flutter 客户端 `clients/netbridge`
- Store / 文档中与交付相关的部分

**默认不含**：持续维护、安全更新 SLA、工单支持、定制开发。需要维护或支持须另签协议。

## 白牌

若采购包含白牌：

- 可替换应用名、图标、关于页链接等品牌元素
- **不得**冒充官方 NetBridge / 网桥商标或官方商店
- 对外应以被许可方自有品牌呈现

## 商标与合规

- 不得声称自己是「官方 NetBridge / 网桥」
- VPN / 出口流量与当地法规合规由被许可方自行负责
- 连接配置（URI / 二维码 / 含私钥的导出）等同密钥，不得公开传播

## 与公开 MIT 的关系

- 公开仓继续使用 **MIT**，欢迎社区贡献与按 MIT 使用
- 商业仓增加商业条款与可选商业功能交付；**不会**用商业许可覆盖公开仓的 `LICENSE`
- 工作区中保留 `LICENSE-COMMERCIAL.md` 与本文档，便于说明「商业版另仓」

详细条款草稿见仓库根目录 [`LICENSE-COMMERCIAL.md`](../LICENSE-COMMERCIAL.md)。

## 本地开发：推送到商业仓

```bash
git remote add commercial git@github.com:PHPJourney/netbridge-commercial.git   # 若尚未添加

# 推荐：在专用分支将 LICENSE 换为商业许可后再推送
git checkout -b commercial/v0.1
cp LICENSE-COMMERCIAL.md LICENSE
# 可选：保留上游 MIT 说明
git show main:LICENSE > LICENSE-MIT.NOTICE
git add LICENSE LICENSE-MIT.NOTICE
git commit -m "chore(license): use commercial LICENSE on commercial branch"
git push -u commercial HEAD:main
git checkout main   # 工作区回到公开 MIT
```

切回 `main` 后，公开仓根目录 `LICENSE` 仍为 MIT。
