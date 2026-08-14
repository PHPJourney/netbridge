# Spec: 网桥 VPN（NetBridge / nbvpn）

> 对齐 Context：`docs/dev-workflow/context/`  
> 本刀 acceptance：`docs/dev-workflow/slices/S01-spec-contract/acceptance.md`  
> 契约附件：`docs/delivery/nbvpn/03-contract.md`  
> 日期：2026-08-14

## 背景与目标

向客户交付完全去中心化的自建节点 VPN 工具集：用户在自有 Linux 服务器上通过 `nbvpn` 安装与管理 WireGuard 节点，经 **配置文件 / `nbvpn:` URI / 二维码** 将连接信息导入 Windows、macOS、Android、iOS 客户端。产品**不提供**官方节点、**不强制**账号；安装包经专门 **store** 在线分发。

**成功标准（可验证）**

1. 无桌面环境下，仅用 store + `nbvpn` 即可安装并得到可扫二维码、可复制 URI、可导出配置文件。
2. 同一连接信息可在四端客户端导入并稳定连接，断线可自动重连。
3. 无默认服务器、无强制账号；文档含用户责任声明；可按验收表完成客户交付验收。

## 用户与场景

| 角色 | 场景 |
|------|------|
| 自建用户 | 从 store 下服务端包 → 在 Debian/Ubuntu/CentOS/RHEL 上安装 → `nbvpn show` 拿三形态信息 |
| 终端用户 | 安装四端之一 → 粘贴 URI / 导入文件 / 扫码 → 自定义本地名称 → 连接 |
| 下载访客 | 打开 store 落地页，分区下载客户端与对应发行版服务端包，无需登录 |
| 交付客户 | 按本规格与竖切 acceptance 验收全量产物 |

**主路径（傻瓜式）**

1. store 下载服务端安装方式与客户端  
2. 服务器执行一键安装（见 FR-S）→ 自动完成节点初始化  
3. `nbvpn show` 同时给出 URI、配置文件路径、终端二维码  
4. 手机/电脑扫码或粘贴 → 改名（可选）→ 连接  

## 功能需求（可编号 FR-xx）

### FR-S 服务端（Linux + `nbvpn`）

| ID | 需求 | 优先级 |
|----|------|--------|
| FR-S01 | 提供面向 **Debian、Ubuntu、CentOS、RHEL** 的安装入口（文档/脚本按系区分；CentOS 家族含 Rocky Linux、AlmaLinux 同等支持，见业务规则 BR-S02） | must |
| FR-S02 | 一键安装：安装依赖、配置 WireGuard、生成节点密钥与首个客户端 peer、启用服务、开机自启 | must |
| FR-S03 | 安装成功后默认打印「下一步」：如何 `nbvpn show` / 如何下载客户端 | must |
| FR-S04 | CLI 命令名固定为 `nbvpn`；`nbvpn --help` / `nbvpn help` 可用 | must |
| FR-S05 | `nbvpn show`：输出**等价**的 URI、配置文件（路径或内容）、终端二维码（默认三种都给；可用 flag 只出一种） | must |
| FR-S06 | 无图形界面时，二维码须在终端以字符块渲染，可供手机摄像头扫描 | must |
| FR-S07 | `nbvpn config`（或 `nbvpn info`）：查看已安装节点摘要（监听端口、公钥、endpoint 提示、peer 数量等）；**不得**在常规输出中打印服务端私钥 | must |
| FR-S08 | `nbvpn status`：服务是否运行、最近握手/传输摘要（能力范围内） | must |
| FR-S09 | `nbvpn start` / `stop` / `restart`：管理 VPN 服务 | must |
| FR-S10 | 支持为额外设备添加 peer（如 `nbvpn peer add`），并为新 peer 单独 `show` 三形态信息；支持吊销 peer | must |
| FR-S11 | `nbvpn uninstall`：停止服务并清理本产品安装文件（行为与是否保留配置须在帮助中说明并二次确认） | should |
| FR-S12 | 安装/运行失败时给出可行动错误（缺权限、端口占用、内核模块不可用等），非空栈吓用户 | must |

**`nbvpn` 子命令面（冻结清单）**

| 命令 | 作用 |
|------|------|
| `nbvpn install` | 本机安装/修复安装（若由外部 bootstrap 调用，行为须一致） |
| `nbvpn show [--uri\|--qr\|--file\|--all]` | 展示连接信息；默认 `--all` |
| `nbvpn config` | 查看已装配置摘要（无服务端私钥） |
| `nbvpn status` | 服务与隧道状态 |
| `nbvpn start` / `stop` / `restart` | 服务管理 |
| `nbvpn peer add [name]` | 新增客户端 peer 并输出该 peer 的三形态信息 |
| `nbvpn peer list` | 列出 peer |
| `nbvpn peer revoke <id\|name>` | 吊销 peer |
| `nbvpn uninstall` | 卸载 |
| `nbvpn help` | 帮助 |

> 允许增加只读别名（如 `info`→`config`），不得删减上表 must 能力。

### FR-P 连接信息（三形态）

| ID | 需求 | 优先级 |
|----|------|--------|
| FR-P01 | 存在唯一规范载荷 **NbVpnProfile v1**（见 `03-contract.md`），三形态均编码同一逻辑内容 | must |
| FR-P02 | **配置文件**：UTF-8 的 `.nbvpn.json`（规范载荷）；另可同时导出兼容 `wg-quick` 的 `.conf`（由同一载荷生成，便于高级用户） | must |
| FR-P03 | **URI**：scheme 为 `nbvpn:`，可整段复制；须可被四端客户端解析 | must |
| FR-P04 | **二维码**：编码内容为完整 URI 字符串（非另套二进制格式） | must |
| FR-P05 | 任一形态导入成功后，客户端得到的连通参数与另外两种一致（允许本地显示名被用户改写） | must |
| FR-P06 | 载荷含 `v`（版本）；客户端遇更高主版本须提示升级，不得静默错误配置 | must |
| FR-P07 | 傻瓜式默认：服务端为客户端生成密钥对，profile 内含**客户端私钥**；须提示「二维码/URI/文件等同于密钥，勿公开传播」；支持 `peer revoke` 失效 | must |

### FR-C 客户端（Windows / macOS / Android / iOS）

| ID | 需求 | 优先级 |
|----|------|--------|
| FR-C01 | 四端同步交付；产品名对外可为「网桥 VPN」，与 `nbvpn` CLI 区分 | must |
| FR-C02 | 新装默认服务器列表为空，不自动连接，无内置节点 | must |
| FR-C03 | 添加服务器：粘贴 URI、导入 `.nbvpn.json`（及规格允许的 `.conf` 映射）、扫描二维码 | must |
| FR-C04 | 每条服务器有**本地显示名**，可编辑；默认可用 profile 内 `name` | must |
| FR-C05 | 列表支持：连接、断开、编辑名称、删除；删除须确认 | must |
| FR-C06 | 连接成功后流量按 profile 的 `allowedIPs` 走隧道；DNS 使用 profile 所给 DNS（防泄漏策略见 NFR） | must |
| FR-C07 | 网络切换 / 短暂断网后自动重连；失败展示可读原因（可复制） | must |
| FR-C08 | 凭据存系统安全存储（Keychain / Credential Manager / Keystore 等），日志不得打印私钥 | must |
| FR-C09 | Kill Switch（隧道断开时阻断泄漏）四端均提供，默认开启或首次明确引导开启（实现按平台能力，须在帮助中说明） | must |
| FR-C10 | 无账号、无登录墙即可使用全部本地功能 | must |
| FR-C11 | 支持同时保存多个服务器；同时仅一条隧道连接（切换时先断后连） | must |

### FR-W 下载站 / store 落地页

| ID | 需求 | 优先级 |
|----|------|--------|
| FR-W01 | 在专门 store 提供落地页：分区「客户端」「服务端」 | must |
| FR-W02 | 客户端区：Windows、macOS、Android、iOS 下载入口齐全 | must |
| FR-W03 | 服务端区：Debian / Ubuntu / CentOS / RHEL（及文档中的 Rocky/Alma 说明）安装包或安装命令入口 | must |
| FR-W04 | 展示版本号与校验和（如 SHA256）；链接指向可下载产物 | must |
| FR-W05 | 首页 ≤3 步傻瓜指引：下载服务端 → 安装并 `nbvpn show` → 客户端添加 | must |
| FR-W06 | 不要求注册/登录即可下载；不出现官方节点列表或「一键连官方」 | must |
| FR-W07 | 展示去中心化与用户责任摘要（出口与合法使用责任在用户） | must |
| FR-W08 | 不做离线安装包全集介质（OUT-07） | must |

## 业务规则

| ID | 规则 |
|----|------|
| BR-01 | 隧道协议唯一：WireGuard |
| BR-02 | 服务端目标发行版：**Debian 11+、Ubuntu 20.04 LTS+、RHEL 8+、CentOS Stream 8+/9**；**Rocky Linux 8+/9、AlmaLinux 8+/9** 视为 CentOS/RHEL 家族同等支持 |
| BR-03 | 默认监听 UDP **51820**（安装时可改；写入 profile 的 endpoint 端口） |
| BR-04 | 默认 `allowedIPs` 为全量隧道 `0.0.0.0/0, ::/0`（若双栈）；若环境无 IPv6，可降为仅 IPv4，须在 `show` 中一致 |
| BR-05 | 默认 DNS：`1.1.1.1` 与 `1.0.0.1`（可在服务端配置中修改并体现在新签发的 profile） |
| BR-06 | Endpoint 主机：安装时自动探测公网 IP；失败则提示用户手动设置（`nbvpn` 须提供设置入口，规格命令可用 `nbvpn config set endpoint <host[:port]>` 作为应实现能力） |
| BR-07 | 客户端本地名与 profile.`name` 解耦：改本地名不回写服务器 |
| BR-08 | 吊销 peer 后，旧 URI/二维码/文件不得再能连上 |
| BR-09 | 产品不收集用户流量内容；若有可选诊断日志，默认关且不含私钥 |
| BR-10 | store 仅分发软件，不运营节点 |

## 非功能（性能/安全/兼容）

| ID | 类别 | 要求 | 优先级 |
|----|------|------|--------|
| NFR-01 | 安全 | 服务端私钥仅存服务器受控路径；`config`/`status`/`logs` 常规输出不含服务端私钥与客户端私钥 | must |
| NFR-02 | 安全 | 客户端凭据加密存储；截屏/分享提醒（移动端导入成功后可提示） | must |
| NFR-03 | 安全 | 安装包提供 SHA256；桌面/移动目标平台按能力代码签名或商店签名 | must |
| NFR-04 | 安全 | DNS 走隧道；Kill Switch 见 FR-C09 | must |
| NFR-05 | 稳定 | 握手失败、endpoint 不可达、时钟异常等有明确错误码/文案 | must |
| NFR-06 | 性能 | 在 1 vCPU / 1GB 内存级 Linux VPS 上可完成安装与单客户端满隧道（文档声明推荐配置） | should |
| NFR-07 | 兼容 | 终端二维码在 80 列常见 SSH 下可扫（过窄终端提示放大/导出文件） | must |
| NFR-08 | 合规文案 | 安装结束与 store 页均有责任声明 | must |
| NFR-09 | 可测 | 三形态互转有固定测试向量（写入契约或 QA 附件） | must |

## 边界与不做

与 `scope.md` 一致：

- 无官方节点 / 节点目录  
- 无强制账号  
- 无 OpenVPN/IPSec 等并列协议  
- 无「必须桌面才能出码」  
- ~~无 Windows Server 服务端包~~ → **已纳入**（IN-02b；见 `scope.md`）  
- 无裁剪 MVP  
- 无离线安装包全集  

技术栈选型不在本规格绑死；实现后回写 `stack.md`。

## 验收表

### A. 规格/契约本身（S01）

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| SP-01 | 三形态等价 | 读 01-spec + 03-contract | 核对 Profile/URI/QR/文件 | 单一载荷 v1，QR=URI，文件=JSON 规范 | must |
| SP-02 | CLI 面 | 读 FR-S 命令表 | 核对 | install/show/config/status/启停/peer/uninstall/help 齐全 | must |
| SP-03 | 去中心化 | 读 FR-C/W 与边界 | 核对 | 无默认节点、无强制账号 | must |
| SP-04 | 平台映射 | 读验收 B/C/D | 核对 | 四端 + store 均有 must 条目 | must |

### B. 服务端（映射 S02）

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| SV-01 | 一键安装 | 受支持发行版干净机 | 按 store 文档安装 | 服务运行；可 `nbvpn show` | must |
| SV-02 | 四系覆盖 | Debian/Ubuntu/RHEL/CentOS(或 Rocky/Alma) | 各至少一系冒烟 | 均达 SV-01 | must |
| SV-03 | 终端二维码 | 无桌面 SSH | `nbvpn show` | 终端 QR 可被手机客户端扫入 | must |
| SV-04 | URI/文件 | 已安装 | `show --uri` / 导出 json | 可被客户端导入 | must |
| SV-05 | 查看配置 | 已安装 | `nbvpn config` | 有摘要；无服务端私钥 | must |
| SV-06 | 服务管理 | 已安装 | stop→status→start→restart | 状态与连通符合预期 | must |
| SV-07 | 吊销 | 两 peer | revoke 其一 | 旧 profile 不能连；另一仍可 | must |
| SV-08 | 错误可读 | 人为端口占用等 | 安装或 start | 明确可行动提示 | must |

### C. 客户端（映射 S03）

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| CL-01 | 空列表 | 新装 | 打开 App | 无服务器、未连接 | must |
| CL-02 | URI 导入 | 有效 URI | 粘贴添加 | 可改名并可连接 | must |
| CL-03 | 文件导入 | `.nbvpn.json` | 导入 | 与 URI 等价可连 | must |
| CL-04 | 扫码 | 终端 QR | 扫码 | 同上 | must |
| CL-05 | 改名 | 已添加 | 改本地名 | 仅显示变化 | must |
| CL-06 | 四端连通 | S02 节点 | Win/macOS/Android/iOS 各连一次 | 隧道可用 | must |
| CL-07 | 重连 | 已连接 | 断网再恢复 | 自动重连或等价恢复 | must |
| CL-08 | 无账号 | — | 使用全部本地功能 | 无登录要求 | must |
| CL-09 | Kill Switch | 已开 KS | 断开隧道 | 不泄漏（按平台测试法） | must |
| CL-10 | 坏 URI | 篡改/截断 | 导入 | 失败提示，不写坏配置 | must |

### D. Store 落地页（映射 S04）

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| ST-01 | 分区 | store 页上线 | 打开 | 客户端/服务端分区清晰 | must |
| ST-02 | 客户端齐套 | 产物已传 | 检查链接 | 四端均可下载 | must |
| ST-03 | 服务端齐套 | 同上 | 检查 | Debian/Ubuntu/CentOS/RHEL 入口齐全 | must |
| ST-04 | 无登录 | 访客 | 下载 | 无强制注册 | must |
| ST-05 | 无节点列表 | 浏览 | 检查 | 无官方节点/一键连官方 | must |
| ST-06 | 三步指引 | 新用户 | 阅读 | ≤3 步说清主路径 | must |
| ST-07 | 校验和 | 发版 | 核对 | 版本+SHA256 可见 | must |

### E. 客户交付（映射 S05）

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| CD-01 | E2E | S02–S04 完成 | store→安装→三形态→四端连接 | 全通过 | must |
| CD-02 | 安全基线 | 发版包 | 抽查 | 无默认节点；无私钥进日志；checksum 可用 | must |
| CD-03 | 文档 | 发版 | 检查 | 安装/CLI/导入/责任声明齐全 | must |

## 待确认

引导项 Q-01～Q-08 已全部关闭。本规格采用的默认假设（无需再问即可开发）：

| 项 | 默认 | 若推翻 |
|----|------|--------|
| CentOS 家族 | Rocky/Alma 同等支持 | 改 scope |
| 最低版本 | 见 BR-02 | 改 BR-02 + constraints |
| 默认端口/DNS/全隧道 | 见 BR-03～05 | 改规格并通知契约变更 |
| Endpoint 探测 | 自动探测 + 手动设置 | — |
| `nbvpn config set endpoint` | 作为 FR 应实现能力 | 实现阶段可命名微调但能力保留 |

新未决须写入 `open-questions.md`，禁止仅聊天修改。

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | T01 初稿：全量规格 + 验收映射 S01–S05 | spec（用户确认开 T01） |
