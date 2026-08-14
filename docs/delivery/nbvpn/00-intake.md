# 00 Intake — 网桥 VPN（nbvpn）

> Context Pack：`docs/dev-workflow/context/`  
> 需求短名：`nbvpn`  
> 目标类型：交付客户；**不裁 MVP，全量同步**  
> 编排日期：2026-08-14

---

## 1. 业务摘要

- **一句话目标**：向客户交付去中心化自建节点 VPN——`nbvpn` 管理 Linux / Windows Server 节点，配置文件 / `nbvpn:` URI / 二维码导入 Win·macOS·Android·iOS 客户端；无默认官方服务器。
- **用户与场景**：自建用户从落地页下载 → Linux 或 Windows Server 安装并展示三形态连接信息 → 四端傻瓜式导入连接。
- **成功标准**：① 无桌面也能用 CLI 出二维码/URI/配置文件；② 四端可连同一节点并重连；③ 无官方节点/强制账号，责任声明清晰，可按 acceptance 客户验收。
- **已知约束**：WireGuard only；完全去中心化；服务端 Linux 须覆盖 Debian/Ubuntu/CentOS/RHEL，并含 Windows Server MVP；CLI=`nbvpn`；URI=`nbvpn:`；四端与落地页同步交付。
- **Context 路径**：`docs/dev-workflow/context/`

详情对齐：[`brief.md`](../../dev-workflow/context/brief.md) · [`scope.md`](../../dev-workflow/context/scope.md) · [`constraints.md`](../../dev-workflow/context/constraints.md)

---

## 2. 范围（做 / 不做）

与 [`scope.md`](../../dev-workflow/context/scope.md) 一致，摘要如下。

| 做 | 不做 |
|----|------|
| WG；Linux（Debian/Ubuntu/CentOS/RHEL）服务端 + `nbvpn` CLI（含终端二维码） | 官方节点 / 节点目录 |
| **Windows Server 服务端 MVP**（`nbvpn.exe` + install.ps1；见 IN-02b） | 强制账号 |
| 连接信息：配置文件 + URI + 二维码 | 多协议并列 |
| 客户端四端同步：Win / macOS / Android / iOS | 无桌面就不能出码 |
| 下载站/store 分区下载（客户端+服务端） | 裁剪 MVP；离线安装包全集 |
| 客户交付级全量验收 | （原 OUT-05 已撤销） |

未决：无（引导项 Q-01～Q-08 均已关闭；Q-04 结论已改为纳入 Windows Server）。规格阶段若再遇发行版最低大版本等细节，写入新 open-question 或规格默认值。

---

## 3. 竖切 / 里程碑排期

| M# | Sxx | 目标 | 依赖 | 建议顺序 | acceptance | 验收一句话 |
|----|-----|------|------|----------|------------|------------|
| M1 | S01 | 规格与连接信息契约冻结 | Context | **先做** | [`slices/S01-spec-contract/acceptance.md`](../../dev-workflow/slices/S01-spec-contract/acceptance.md) | 三形态契约 + `nbvpn` 命令面 + 四端/落地页验收表就绪 |
| M2 | S02 | Linux 服务端 + `nbvpn` | S01 | 与 M3/M4 **并行** | [`slices/S02-server-nbvpn/acceptance.md`](../../dev-workflow/slices/S02-server-nbvpn/acceptance.md) | 无桌面安装后可出码/URI/配置并管理服务 |
| M2 | S03 | 四端客户端同步 | S01（设计可并行） | 与 M2/M4 **并行** | [`slices/S03-clients/acceptance.md`](../../dev-workflow/slices/S03-clients/acceptance.md) | 四端均可三形态导入并连接 |
| M2 | S04 | 下载站落地页 | S01（设计可并行） | 与 M2/M3 **并行** | [`slices/S04-download-site/acceptance.md`](../../dev-workflow/slices/S04-download-site/acceptance.md) | 分区下载且无账号墙/无节点列表 |
| M3 | S05 | 客户交付验收与发版 | S02–S04 | **最后** | [`slices/S05-customer-delivery/acceptance.md`](../../dev-workflow/slices/S05-customer-delivery/acceptance.md) | E2E 通过 + 交付清单完整 |

说明：「全量同步」= M1 契约冻结后，S02/S03/S04 并行实现，S05 统一验收；禁止无契约直接开四端实现。

---

## 4. 工种任务单

### T01 | 冻结产品规格与连接信息契约
- 负责人角色: spec
- 匹配 skill: handoff-protocol, role-spec
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/glossary.md
  - docs/dev-workflow/context/constraints.md
  - docs/dev-workflow/context/stack.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S01-spec-contract/acceptance.md
- 输入: 见 00-intake §范围；口述已落盘 context
- 输出路径: docs/delivery/nbvpn/01-spec.md（契约附件可同目录）
- 完成定义 (DoD):
  - [ ] 连接信息三形态等价规则与版本字段写清
  - [ ] `nbvpn` 子命令与傻瓜式输出（含终端二维码）写清
  - [ ] 四端客户端与落地页验收表可测
  - [ ] 与 scope/constraints 无冲突（含：仅 store 下载、Debian/Ubuntu/CentOS/RHEL）
- 下游交接对象: T02 design；T03 backend；T04/T05 frontend
- 建议并行: 否（阻塞实现）

### T02 | 设计交接（落地页 + 客户端关键流）
- 负责人角色: design
- 匹配 skill: handoff-protocol, role-design
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/open-questions.md
  - docs/dev-workflow/context/glossary.md
- 本刀 acceptance: docs/dev-workflow/slices/S03-clients/acceptance.md ；兼 S04-download-site/acceptance.md
- 输入: docs/delivery/nbvpn/01-spec.md
- 输出路径: docs/delivery/nbvpn/02-design.md
- 完成定义 (DoD):
  - [ ] 落地页信息架构与下载分区
  - [ ] 客户端：空状态 → 三形态添加 → 列表/连接关键页流程与状态
  - [ ] 不出现官方节点/账号墙设计
- 下游交接对象: T04、T05
- 建议并行: 是（与 T01 尾声可叠；不得早于契约字段冻结）

### T03 | Linux 服务端安装包与 nbvpn CLI
- 负责人角色: backend
- 匹配 skill: handoff-protocol, role-backend
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/constraints.md
  - docs/dev-workflow/context/stack.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S02-server-nbvpn/acceptance.md
- 输入: docs/delivery/nbvpn/01-spec.md
- 输出路径: 代码仓库（服务端/CLI 目录待 stack 回写）；docs/delivery/nbvpn/03-impl-notes-server.md
- 完成定义 (DoD):
  - [ ] 安装后服务可管
  - [ ] 三形态连接信息可出（含终端二维码）
  - [ ] 查看配置与服务启停/状态/重启可用
  - [ ] 回写 stack.md 实际技术选型
- 下游交接对象: T06 qa
- 建议并行: 是（与 T04、T05）

### T04 | 四端客户端实现
- 负责人角色: frontend
- 匹配 skill: handoff-protocol, role-frontend
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/constraints.md
  - docs/dev-workflow/context/glossary.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S03-clients/acceptance.md
- 输入: 01-spec.md；02-design.md
- 输出路径: 各客户端工程目录（待 stack）；docs/delivery/nbvpn/03-impl-notes-clients.md
- 完成定义 (DoD):
  - [ ] Win/macOS/Android/iOS 均可三形态导入
  - [ ] 默认无服务器；支持本地改名与连接/断开
  - [ ] 重连与凭据安全存储达规格
  - [ ] 回写 stack.md
- 下游交接对象: T06 qa
- 建议并行: 是（与 T03、T05；四端内部可再拆子 Agent）

### T05 | 下载站落地页实现
- 负责人角色: frontend
- 匹配 skill: handoff-protocol, role-frontend
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/constraints.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S04-download-site/acceptance.md
- 输入: 01-spec.md；02-design.md
- 输出路径: 落地页工程目录（待 stack）；docs/delivery/nbvpn/03-impl-notes-site.md
- 完成定义 (DoD):
  - [ ] 客户端/服务端分区下载
  - [ ] 无登录墙、无节点列表
  - [ ] 傻瓜式三步指引与校验和展示（按规格）
- 下游交接对象: T06 qa
- 建议并行: 是（与 T03、T04）

### T06 | 全量 QA 与客户验收记录
- 负责人角色: qa
- 匹配 skill: handoff-protocol, role-qa
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S05-customer-delivery/acceptance.md（并回归 S02–S04）
- 输入: 各 impl-notes；01-spec 验收表
- 输出路径: docs/delivery/nbvpn/05-qa.md
- 完成定义 (DoD):
  - [ ] E2E 主路径执行并记录
  - [ ] must 缺陷清零或书面带风险接受
  - [ ] 明确是否放行 release
- 下游交接对象: T07 release
- 建议并行: 否（门禁）

### T07 | 客户交付发版
- 负责人角色: release
- 匹配 skill: handoff-protocol, role-release
- 必读 context:
  - docs/dev-workflow/context/brief.md
  - docs/dev-workflow/context/scope.md
  - docs/dev-workflow/context/constraints.md
  - docs/dev-workflow/context/open-questions.md
- 本刀 acceptance: docs/dev-workflow/slices/S05-customer-delivery/acceptance.md
- 输入: 05-qa.md 放行结论；构建产物
- 输出路径: docs/delivery/nbvpn/06-release.md
- 完成定义 (DoD):
  - [ ] 交付清单（四端+Linux 服务端+落地页+checksum）完整
  - [ ] 责任声明与安装文档随包
  - [ ] 回滚/已知问题已记录
- 下游交接对象: 客户交付
- 建议并行: 否（须 QA 通过）

---

## 5. 下一枪怎么开

默认下一枪：**T01 规格**（未冻结规格不得开 T03–T05 实现）。

```text
【任务】T01 冻结产品规格与连接信息契约
【请先 Read】
1. ~/.cursor/skills/handoff-protocol/SKILL.md
2. ~/.cursor/skills/role-spec/SKILL.md
3. docs/dev-workflow/context/brief.md
4. docs/dev-workflow/context/scope.md
5. docs/dev-workflow/context/glossary.md
6. docs/dev-workflow/context/constraints.md
7. docs/dev-workflow/context/stack.md
8. docs/dev-workflow/context/open-questions.md
9. docs/dev-workflow/slices/S01-spec-contract/acceptance.md
10. docs/delivery/nbvpn/00-intake.md
【硬性输出】按 skill 写到: docs/delivery/nbvpn/01-spec.md
【DoD】
- 连接信息三形态等价规则与版本字段写清
- nbvpn 子命令与傻瓜式输出（含终端二维码）写清
- 四端客户端与落地页验收表可测
- 与 scope/constraints 无冲突（含：仅 store 下载、Debian/Ubuntu/CentOS/RHEL）
【禁止】口口相传改需求；项目事实以 context/acceptance 为准；改契约走 handoff-protocol
【未决】引导项 Q-01～Q-08 已关闭；若规格中出现新未决须先写入 open-questions，禁止猜测结案
```

### 并行提示（仅 T01 完成后）

| 可并行 | 开场要点 |
|--------|----------|
| T02 design | acceptance：S03 + S04；输出 `02-design.md` |
| T03 backend | acceptance：S02；输出服务端/`nbvpn` + impl-notes |
| T04 frontend | acceptance：S03；四端客户端 |
| T05 frontend | acceptance：S04；落地页 |

---

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | intake 五件套初稿 | 用户确认编排 |
