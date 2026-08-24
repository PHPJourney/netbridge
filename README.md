# 网桥 VPN（NetBridge）

[![Build Server](https://github.com/PHPJourney/netbridge/actions/workflows/build-server.yml/badge.svg)](https://github.com/PHPJourney/netbridge/actions/workflows/build-server.yml)
[![Build Clients](https://github.com/PHPJourney/netbridge/actions/workflows/build-clients.yml/badge.svg)](https://github.com/PHPJourney/netbridge/actions/workflows/build-clients.yml)
[![Pages Store](https://github.com/PHPJourney/netbridge/actions/workflows/pages-store.yml/badge.svg)](https://github.com/PHPJourney/netbridge/actions/workflows/pages-store.yml)

去中心化自建节点 VPN：Linux / Windows 服务端 `nbvpn` + 四端客户端 + Store 下载页。无官方节点、无强制账号。

本仓库为 **公开 MIT** 版。付费商业交付（Private）见另仓与 [`docs/COMMERCIAL.md`](docs/COMMERCIAL.md) / [`LICENSE-COMMERCIAL.md`](LICENSE-COMMERCIAL.md)。

- **仓库（公开）**：https://github.com/PHPJourney/netbridge
- **商业私有仓**：https://github.com/PHPJourney/netbridge-commercial （需授权）
- **Store（GitHub Pages）**：https://phpjourney.github.io/netbridge/
- **安装包（GitHub Releases）**：https://github.com/PHPJourney/netbridge/releases

## 分发架构

| 组件 | 职责 |
|------|------|
| **`apps/store/` → GitHub Pages** | 落地页 UI（介绍、下载入口）。不托管大安装包。 |
| **GitHub Actions + Releases** | **主产物仓**：服务端 / 客户端二进制由 CI 构建并挂到 Release。 |
| **OpenList（可选镜像）** | 仍可作为第三方镜像；清单见 `docs/delivery/nbvpn/OPENLIST-UPLOAD.md`。优先用 Releases。 |

## CI 产物名

### 服务端（`build-server.yml`）

| 产物 | 说明 |
|------|------|
| `nbvpn-linux-amd64` | Linux x86_64 |
| `nbvpn-linux-arm64` | Linux arm64 |
| `nbvpn-windows-amd64.exe` | Win10+ / Server 2016+（Go 1.22） |
| `nbvpn-windows-amd64-win2012.exe` | **Server 2012 R2**（Go 1.20） |
| `NetBridge-nbvpn-Setup.exe` | 服务端现代 Setup（Win10+/2016+，含 WG MSI） |
| `NetBridge-nbvpn-Setup-win2012.exe` | **Server 2012 专用 Setup**（WG 0.5.3 + Win32 GUI + CLI） |
| `nbvpn-server-<tag>.zip` | 上述二进制 + `server/install` 脚本 |

### 客户端（`build-clients.yml`）

| 产物 | 说明 |
|------|------|
| `NetBridge-android-arm64.apk` | Android R8 release（另有 v7a 可选） |
| `NetBridge-windows.exe` / `NetBridge-windows-portable.zip` | Windows 10+ Flutter |
| `NetBridge-macOS.app.zip` | macOS **未公证** / ad-hoc |
| iOS | CI **跳过签名**（见 `IOS-CI-SKIP.txt`） |

打标签发布：

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 仓库结构

| 路径 | 说明 |
|------|------|
| `server/nbvpn/` | Go CLI（WireGuard 节点管理） |
| `server/install/` | Linux / Windows 安装脚本 |
| `clients/netbridge/` | Flutter 客户端 |
| `apps/store/` | 下载落地页（Pages） |
| `.github/workflows/` | CI：server / clients / pages |
| `docs/delivery/nbvpn/` | 规格与交付说明 |

## 快速开始

### Clone

```bash
git clone https://github.com/PHPJourney/netbridge.git
cd netbridge
```

### 服务端（开发 dry-run）

```bash
cd server/nbvpn && go build -o nbvpn .
export NBVPN_DATA_DIR=/tmp/nbvpn-dev
./nbvpn install
./nbvpn show
```

### Linux 生产

从 [Releases](https://github.com/PHPJourney/netbridge/releases) 下载 `nbvpn-linux-amd64`，或本地交叉编译：

```bash
cd server/nbvpn
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags='-s -w' -o dist/nbvpn-linux-amd64 .
sudo bash ../install/install.sh
```

### Store 本地预览

```bash
cd apps/store && npm ci && npm run build && npm run preview
# 生产 base：/netbridge/（GitHub project Pages）
```

### 客户端

```bash
cd clients/netbridge && flutter pub get && flutter run
```

## 文档

- Linux 安装预检 / 全系环境自愈（Debian/Ubuntu + RHEL/CentOS）：`server/install/LINUX-PREFLIGHT.md`
- 防火墙与缺 WireGuard 模块：`server/install/FIREWALL.md`
- Windows 节点：`server/install/windows/WINDOWS.md`（含 win2012 CI 产物）
- OpenList / Releases：`docs/delivery/nbvpn/OPENLIST-UPLOAD.md`
- 规格：`docs/delivery/nbvpn/01-spec.md`
- 契约：`docs/delivery/nbvpn/03-contract.md`
- 商业版另仓：`docs/COMMERCIAL.md`

## 安全提示

勿将 SSH 私钥、密码、`.env` 密钥提交进仓库。VPS / WinRM 凭据仅保存在本机配置中。
