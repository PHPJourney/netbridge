# Stack — 技术栈与目录约定

> 仓库目前为空；产品向约束已确认，实现技术标「待选定」，由规格/实现回写。

## 已确认 / 已探测

| 层 | 技术 | 依据（文件或用户确认） |
|----|------|------------------------|
| 隧道协议 | WireGuard | 用户确认 |
| 服务端 CLI | Go（`github.com/netbridge/nbvpn`），命令名 `nbvpn`；Windows 可选本地 GUI `nbvpn-gui`（`cmd/nbvpn-gui`，调 CLI） | T03 实现；`server/nbvpn/` |
| 连接信息 URI | `nbvpn:1?<base64url(JSON)>`（Profile v1） | `03-contract.md` 冻结 |
| 前端（下载落地页） | Vite 6 静态站（HTML/CSS/JS），目录 `apps/store/` — **仅 UI**，不存安装包 | T05；`apps/store/IMPL.md` |
| 产物存储 / CDN | OpenList（柚子科技开源）`http://154.37.213.245:5244/store`；`releases.json` 填直链 | 用户确认；链接待上传后更新 |
| 客户端 | Flutter 3.35（`clients/netbridge/`），Android/iOS/Windows/macOS | T04 实现；见 `clients/netbridge/IMPL.md` |
| 服务端安装包 | `server/install/install.sh`（Linux，apt/dnf 装 wireguard-tools）+ `server/install/windows/`（Setup.exe / install.ps1；**捆绑固定版本 WireGuard MSI**） | T03 + Windows MVP |
| 数据 | 本地配置为主；无中心账号库 | 去中心化 |
| 基础设施 | 用户自备 VPS / Windows Server；我方仅分发安装包 | 用户确认 |

## 目录约定

| 用途 | 路径 |
|------|------|
| Context Pack | `docs/dev-workflow/context/` |
| 竖切验收 | `docs/dev-workflow/slices/` |
| Delivery | `docs/delivery/nbvpn/` |
| 前端应用（Store 落地页 UI） | `apps/store/`（非文件存储） |
| 产物清单回填脚本 | `scripts/fill-releases-after-upload.md`、`scripts/update-releases-urls.sh` |
| 四端客户端 | `clients/netbridge/` |
| 服务端安装/CLI | `server/nbvpn/`（CLI）、`server/nbvpn/cmd/nbvpn-gui`（Windows 管理 UI）、`server/install/install.sh`（Linux）、`server/install/windows/`（Windows） |
| 共享契约（连接信息 schema） | `docs/delivery/nbvpn/03-contract.md`（NbVpnProfile v1） |
| 服务端状态目录 | Linux `/var/lib/nbvpn`；Windows `%ProgramData%\nbvpn`（`NBVPN_DATA_DIR` 可覆盖） |
| 测试 | `cd server/nbvpn && go test ./...` |

## 本地常用命令

| 用途 | 命令 |
|------|------|
| 服务端安装/管理（产品） | `nbvpn`（见 `server/nbvpn/README.md`） |
| 服务端构建 | `cd server/nbvpn && go build -o nbvpn .` |
| 服务端测试 | `cd server/nbvpn && go test ./...` |
| Linux 一键安装 | `sudo bash server/install/install.sh` |
| Windows Server 安装 | 管理员 PowerShell：`server/install/windows/install.ps1`（见 WINDOWS.md） |
| 交叉编译含 Windows | `./server/nbvpn/scripts/build-release.sh amd64 arm64 windows` |
| Store 开发 | `cd apps/store && npm run dev` |
| Store 构建 | `cd apps/store && npm run build` |
| Store 预览 | `cd apps/store && npm run preview` |
| 客户端依赖 | `cd clients/netbridge && flutter pub get` |
| 客户端测试 | `cd clients/netbridge && flutter test` |
| 客户端分析 | `cd clients/netbridge && flutter analyze` |
| 客户端运行 | `cd clients/netbridge && flutter run -d <device>` |

## 修订记录

| 日期 | 变更 | 确认人 |
|------|------|--------|
| 2026-08-14 | 初稿：空仓 + 协议/去中心化已确认 | 用户（会话） |
| 2026-08-14 | 写入 `nbvpn` / `nbvpn:` 与 delivery 路径 | 用户（会话） |
| 2026-08-14 | Store：Vite 静态站 `apps/store/` | frontend T05 |
| 2026-08-14 | 服务端：Go CLI `server/nbvpn/` + `install.sh` | backend T03 |
| 2026-08-14 | 客户端：Flutter `clients/netbridge/` 四端 | frontend T04 |
| 2026-08-14 | 分发：落地页 UI=`apps/store`；产物=OpenList `…:5244/store` | 用户确认 |
| 2026-08-14 | Windows Server：`install.ps1` + `nbvpn-windows-amd64.exe` | 用户确认纳入 |
