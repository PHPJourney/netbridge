# IMPL — 网桥 VPN Store 落地页

> 对应任务：T05 / 竖切 S04  
> 路径：`apps/store/`  
> 日期：2026-08-14（双语 / 合作伙伴 / 法律页）

## 架构分工（重要）

| 角色 | 是什么 | 不是什么 |
|------|--------|----------|
| **`apps/store/`** | 下载**落地页 UI**（Vite 静态站：Hero、三步指引、客户端/服务端分区、**使用帮助**、责任文案、页脚合作伙伴、用户协议/隐私政策） | **不是**安装包存储 / CDN / 文件后端 |
| **OpenList** | 产物存放与下载：`http://154.37.213.245:5244/store`（站品牌「柚子科技开源」） | 不是落地页前端代码仓 |

`public/releases.json` 存清单元数据（版本、SHA256、下载 URL / 安装命令）以及站点 meta（官方地址、法律页、合作伙伴）。

当前为 **`meta.status: mock_links`**：URL 刻意带 `/store/mock/…`，供落地页展示可点链接与版本/校验和；**不是** OpenList 上已存在的真包。真上传后按 `scripts/fill-releases-after-upload.md` 替换，并把 status 改为正式值。

上传后操作清单：`scripts/fill-releases-after-upload.md`；可选脚本：`scripts/update-releases-urls.sh --print-template`。

## 技术选型

| 项 | 选择 |
|----|------|
| 构建 | Vite 6（静态多页：`index.html` / `terms.html` / `privacy.html`） |
| 运行时 | 原生 HTML + CSS + JS（无 React/Vue） |
| i18n | `src/i18n.js`（zh / en）；偏好键 `localStorage['nbvpn-store-lang']` |
| 字体 | Google Fonts：Syne（展示）+ Manrope（正文） |
| 发布清单 | `public/releases.json`（构建时拷贝到 `dist/releases.json`） |
| 产物存储 | OpenList 基址 `http://154.37.213.245:5244`（浏览 `/store`） |

设计要求「无账号 API、版本可静态注入」——用静态 JSON 即可，无需 SSR。设计 tokens（`--bg-deep` / `--accent` 等）未因双语改动。

## 信息架构实现对照

| 设计 ID | 实现 |
|---------|------|
| W-01 | `index.html` 整页 + `main.js` 拉取清单 |
| W-02 | `#clients` 四端卡片（版本 / SHA256 / 下载） |
| W-03 | `#servers` 四系命令块 + 复制 + 包链接；Rocky/Alma 脚注在 CentOS/RHEL |
| W-04 | `#steps` 固定三步文案 |
| W-05 | `#responsibility` 责任摘要（无折叠） |
| W-06 | `#help` 使用帮助（导航入口；Hero 不堆帮助内容）：产品说明、三步、Linux 安装 + Windows 服务端说明、`nbvpn` 常用命令、客户端导入、UDP 51820/NAT、责任摘要 — **结构未拆散，仅叠加 `data-i18n` / `data-i18n-html`** |
| — | 页脚 **合作伙伴 / Partners**：`meta.partners[]` |
| — | `terms.html` / `privacy.html`（或 `meta.termsUrl` / `meta.privacyUrl`） |

禁止项：无登录、无节点列表、无套餐/官方一键连接。

## 中英文双语

- 顶栏 **English / 中文** 切换（`[data-lang-toggle]`）；写入 `localStorage` 键 **`nbvpn-store-lang`**（`zh` | `en`）。
- 覆盖：导航、Hero、三步、下载区动态文案、使用帮助、责任、页脚、合作伙伴展示名、法律页。
- 切换后重新渲染下载卡片与合作伙伴行；帮助区 DOM 结构保持不变。

## 合作伙伴（页脚）

- 展示名：**TradeMind**；**TM 开放平台** / **TM Open Platform**（来自 `name` / `nameEn`）。
- 数据源：`releases.json` → `meta.partners[]`，每项 `{ name, nameEn?, url }`。
- **无正式官网时 `url` 用 `#` 占位**；拿到官方链接后只改 JSON 即可，不必改前端。
- 若缺省 `partners`，前端回退到内置默认两项（同样 `#`）。

## 官方站点与法律 URL（releases.json `meta`）

客户端「官方网站」设置可指向本 store 源站。可配置键：

| 键 | 用途 | 当前 mock 示例 |
|----|------|----------------|
| `meta.officialSite` | 官方站点（相对路径或绝对 URL；本地预览可用 `http://127.0.0.1:4173`） | `http://127.0.0.1:4173` |
| `meta.termsUrl` | 用户协议链接 | `/terms.html` |
| `meta.privacyUrl` | 隐私政策链接 | `/privacy.html` |
| `meta.partners` | 合作伙伴列表 `[{ name, nameEn?, url }]` | TradeMind + TM 开放平台，`url: "#"` |

页脚「用户协议 / 隐私政策」读取 `termsUrl` / `privacyUrl`；缺省回退 `/terms.html`、`/privacy.html`。`officialSite` 写入 `document.documentElement.dataset.officialSite` 供联调/工具读取。

## 本地命令

```bash
cd apps/store
npm install
npm run dev      # http://localhost:5173
npm run build    # 输出 dist/（含 terms.html / privacy.html）
npm run preview  # 默认 http://127.0.0.1:4173（与 meta.officialSite mock 对齐）
```

## 视觉与动效

- 底色 `#0F1C24`，强调色 `#2EC4B6`；全宽 Hero 网格/链路氛围，非紫白风。
- 动效 3 处：Hero CTA 入场、三步滚动淡入、下载/发行版卡片 hover。
- `prefers-reduced-motion: reduce` 下关闭动画。
- 页脚合作伙伴为一行轻量链接，非法务卡片堆叠。

## 发版约定

1. 将真实安装包上传到 **OpenList**（路径由运营选定，例如 `/store/...`）。
2. 按 `scripts/fill-releases-after-upload.md` 把直链、版本、SHA256、`installCommand` 写入 `public/releases.json`（或用 `scripts/update-releases-urls.sh`）。
3. 填入正式 `meta.partners[].url`、`meta.officialSite`、法律页 URL（若不用内置 `terms.html` / `privacy.html`）。
4. `npm run build` 后部署落地页 `dist/`（仅 UI；包仍从 OpenList 下载）。

**禁止**：声称 OpenList 上已有未上传文件；把 mock URL 当生产直链；把 root 密码写入仓库。

真上传前可用 mock 路径做 UI 联调；上传后必须替换 `url` / `sha256` / `installCommand` 并改 `status`。

## 验收映射（S04）

| AC | 覆盖方式 |
|----|----------|
| AC-01 分区 | `#clients` / `#servers` 分节 |
| AC-02 四端 | Win / macOS / Android / iOS 卡片 |
| AC-03 服务端 | Debian / Ubuntu / CentOS / RHEL + 校验和 |
| AC-04 无账号 | 全站无登录入口 |
| AC-05 无节点列表 | 导航仅步骤/客户端/服务端/使用帮助/责任 |
| AC-06 ≤3 步 | W-04 固定三步 |
| AC-07 使用帮助 | `#help` 去中心化说明、安装、命令、导入、端口/NAT、责任；导航可达且不污染 Hero；双语不破坏结构 |

## 已知占位 / 后续

- 当前 **mock_links**：UI 可点，OpenList 路径未真上传（DEF-01）。
- 合作伙伴 URL、法律正文为占位；正式文案可替换 `terms.html` / `privacy.html` 或改 `meta.termsUrl` / `meta.privacyUrl` 外链。
- 服务端条目 sha256 对齐本仓库 `server/nbvpn/dist/nbvpn-linux-amd64` 交叉编译结果；客户端 sha 为 mock 图案。
- 直链常见形态：`{openlistBase}/d/<路径>`（以实际上传路径为准）。
- Context：`stack.md` / `constraints.md` 已区分落地页 UI 与 OpenList 存储。
