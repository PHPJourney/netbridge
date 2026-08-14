# Acceptance — S02 服务端与 nbvpn CLI

> 本刀验收以本文件为准；项目全局事实见 `docs/dev-workflow/context/`。

## 竖切目标

在无桌面的服务器上，用户用傻瓜式命令完成安装，并用 `nbvpn` 查看配置、管理服务，同时得到可复制 URI、可导出配置文件与终端二维码。覆盖 **Linux（Debian/Ubuntu/CentOS/RHEL）** 与 **Windows Server MVP**。

## 范围内

- Linux 一键/脚本安装包，覆盖 Debian、Ubuntu、CentOS、RHEL（最低大版本以规格为准）
- Windows Server：`nbvpn-windows-amd64.exe` + `server/install/windows/install.ps1`（WireGuard for Windows）
- `nbvpn`：快速使用、查看已装配置、展示三形态连接信息、服务管理
- 安装后自检与可理解的错误提示
- 卸载/升级路径（规格已定的部分）

## 范围外（本刀不做）

- 客户端 App、下载站页面实现（Store 条目回填除外）
- Windows 与 Linux 在 NAT/RRAS 上的完整运维对等（见 `WINDOWS.md` 诚实缺口；MVP 以可装可 show 为主）

## 验收标准

| ID | 场景 | 前置 | 步骤 | 期望 | 优先级 |
|----|------|------|------|------|--------|
| AC-01 | 一键安装（Linux） | 干净 Linux + 公网/可达网络 | 按文档执行安装 | 服务可启动；输出默认连接信息 | must |
| AC-01w | Windows 安装 MVP | Windows Server + WireGuard for Windows + 管理员 | 运行 `install.ps1` 或放置 exe 后 `nbvpn install` | 可 `nbvpn show` 得 URI/QR/文件；有 WG 时可启隧道服务 | must |
| AC-02 | 终端二维码 | 无桌面 SSH/终端会话 | `nbvpn` 展示二维码 | 终端内可见可扫码的 QR（块字符等） | must |
| AC-03 | URI 与配置文件 | 已安装 | 导出/打印 URI 与配置文件 | 与二维码载荷等价；可复制 | must |
| AC-04 | 查看配置 | 已安装 | 查看已装配置命令 | 展示节点关键参数且不泄露不应展示的私钥（按规格） | must |
| AC-05 | 服务管理 | 已安装 + WG 可用 | 启停/状态/重启 | 状态正确；失败有原因 | must |
| AC-06 | 傻瓜式 | 非专家用户文档 | 仅按最短路径操作 | 无需手写 WireGuard 配置即可拿到三形态信息 | must |

## 依赖的 Context

- [x] brief.md
- [x] scope.md（IN-02b）
- [x] glossary.md
- [x] constraints.md
- [x] stack.md
- [x] open-questions.md（Q-04 已关闭为纳入）

## 相关交付产物

- 需求短名 / delivery 路径：`docs/delivery/nbvpn/`
- 规格 / 契约：`docs/delivery/nbvpn/01-spec.md`；实现说明按 handoff
- Windows：`server/install/windows/`

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿 | intake |
| 2026-08-14 | 纳入 Windows Server MVP（OUT-05→IN-02b） | 用户确认 |
