# Acceptance — S03 四端客户端同步

> 本刀验收以本文件为准；项目全局事实见 `docs/dev-workflow/context/`。

## 竖切目标

Windows / macOS / Android / iOS 客户端均可导入同一节点的连接信息（文件 / URI / 扫码），自定义本地名称并稳定连接；默认无任何服务器。

## 范围内

- 四端客户端（业务同步开发与交付）
- 添加服务器：配置文件、URI、二维码
- 服务器列表：连接/断开、改名、删除
- 自动重连、错误可见；安全存储凭据
- Kill Switch / DNS 防泄漏（按规格 must/should）

## 范围外（本刀不做）

- 服务端安装包与 `nbvpn` 实现（属 S02）
- 下载站页面（属 S04）
- 官方节点或账号系统

## 验收标准

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| AC-01 | 默认空列表 | 新装客户端 | 打开 App | 无预置服务器、不自动连接 | must |
| AC-02 | URI 导入 | 有效 `nbvpn:` 字符串 | 粘贴添加 | 出现可改名的服务器项 | must |
| AC-03 | 配置文件导入 | 有效配置文件 | 导入 | 与 URI 导入结果等价可连 | must |
| AC-04 | 扫码导入 | 终端/图片二维码 | 扫码添加 | 同上 | must |
| AC-05 | 自定义名称 | 已添加服务器 | 修改本地名称 | 仅改显示名，不影响连通参数 | must |
| AC-06 | 连接成功 | 服务端 S02 可用 | 四端分别连接 | 流量走隧道（按规格探测方式） | must |
| AC-07 | 重连 | 已连接后断网/切网 | 恢复网络 | 自动重连或明确可一键重连（按规格） | must |
| AC-08 | 平台齐套 | 客户交付包 | 检查产物 | Win/macOS/Android/iOS 均有可安装构建 | must |

## 依赖的 Context

- [x] brief.md
- [x] scope.md
- [x] glossary.md
- [x] constraints.md
- [x] stack.md
- [x] open-questions.md

## 相关交付产物

- 需求短名 / delivery 路径：`docs/delivery/nbvpn/`
- 规格 / 契约：`docs/delivery/nbvpn/01-spec.md`；设计交接若有 `02-design.md`

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | intake |
