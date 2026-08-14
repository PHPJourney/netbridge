# Acceptance — S05 客户交付验收

> 本刀验收以本文件为准；项目全局事实见 `docs/dev-workflow/context/`。

## 竖切目标

按客户交付标准完成端到端验收：从落地页下载 → Linux 安装 `nbvpn` → 三形态导入四端 → 连接稳定；产出发布说明与回滚/已知问题记录。

## 范围内

- 跨竖切回归（S02+S03+S04）
- 缺陷记录与放行结论
- 发布检查、版本产物清单、客户交付说明

## 范围外（本刀不做）

- 新增大功能（应回流 scope/规格）

## 验收标准

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| AC-01 | E2E 主路径 | S02–S04 宣称完成 | 按客户手册走通全流程 | 四端均可连同一自建节点 | must |
| AC-02 | 安全基线 | 构建产物 | 抽查 | 无默认节点；凭据非明文日志；校验和可用 | must |
| AC-03 | 文档齐套 | 发布包 | 检查 | 安装、CLI、客户端导入、责任声明齐全 | must |
| AC-04 | QA 门禁 | 缺陷列表 | 评审 | must 缺陷清零或客户书面接受带风险项 | must |
| AC-05 | 交付清单 | 发版 | 核对 | 客户端四端 + Linux 服务端 + 落地页 + checksum 列表完整 | must |

## 依赖的 Context

- [x] brief.md
- [x] scope.md
- [x] glossary.md
- [x] constraints.md
- [x] stack.md
- [x] open-questions.md

## 相关交付产物

- 需求短名 / delivery 路径：`docs/delivery/nbvpn/`
- QA：`docs/delivery/nbvpn/05-qa.md`；Release：`docs/delivery/nbvpn/06-release.md`

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | intake |
