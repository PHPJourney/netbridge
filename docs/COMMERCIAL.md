# NetBridge 商业版说明

## 仓库

| | 公开版 | 商业版 |
|--|--------|--------|
| 仓库 | https://github.com/PHPJourney/netbridge | https://github.com/PHPJourney/netbridge-commercial |
| 可见性 | Public | **Private** |
| 许可 | MIT（根目录 `LICENSE`） | 商业许可（见 `LICENSE-COMMERCIAL.md`；商业仓默认 `LICENSE` 为商业条款） |
| 用途 | 社区开源、自建、按 MIT 使用 | 付费交付、可选白牌、合同约定范围 |

商业仓是**独立私有仓库**（不是公开仓的 GitHub Fork——公开仓无法再改为 private fork）。

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
