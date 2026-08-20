# RELEASE NOTES — v0.1.8 (Setup-win2012 = WG 0.5.3 + Win32 GUI)

## 目标

Server 2012 / 2012 R2 也能**双击安装**，并具备 **WireGuard 真隧道能力** 与 **可双击的管理 GUI**（不再只有 CLI dry-run / cmd 菜单）。

## WireGuard（证据与钉死）

| 项 | 事实 |
|----|------|
| 现代 `wireguard-amd64-1.1.msi` | 官方要求 Win10 / Server 2016+；Jason Donenfeld 邮件列表 2026-03 明确 sunset 旧系统 |
| 官方下载索引现状 | 仅列出 1.1（旧 MSI 可能已从目录页移除） |
| **本版钉死** | **`wireguard-amd64-0.5.3.msi`**（历史官方，WAPT/Chocolatey 面向 Win6.1+） |
| SHA256 | `76fcec042c5989c5b816cd32eaed1e5b1c3b998a4b1c9eca55f299e3314ef7e4`（Chocolatey 校验） |
| 来源 | `download.wireguard.com` + Internet Archive fallbacks |
| 安装 | Setup-win2012 / `install.ps1` 在 2012 上**静默安装 0.5.3**；已装则跳过；**拒绝**在 2012 上装 1.1 |

若 0.5.3 下载失败或 msiexec 在某台 2012 上失败：Setup 会硬失败并写 `%TEMP%\nbvpn-setup-last-error.txt`（不再静默 dry-run）。`wireguard-go` embed 未做本版交付（优先官方旧 MSI）。

## GUI

- 产物：`nbvpn-gui-win2012.exe` → 安装后 `nbvpn-gui.exe`
- **纯 Win32 + `CGO_ENABLED=0`**（无 Fyne、无动态 MinGW CRT → 避免 14001）
- 功能：刷新状态、启停、peer 列表、显示/复制 URI、打开 QR PNG、数据目录、添加 peer
- 现代路径仍用 Fyne `nbvpn-gui-windows-amd64.exe`（Win10+/2016+ Setup）

## 用户怎么装 / 怎么管

1. 下载并双击（管理员）：**`NetBridge-nbvpn-Setup-win2012.exe`**
2. 开始菜单 → **「NetBridge nbvpn GUI」**
3. 可选 cmd 菜单 / CLI：`nbvpn status` 等

现代系统继续用 **`NetBridge-nbvpn-Setup.exe`**（WG 1.1 + Fyne）。

## 下载

- 2012：https://github.com/PHPJourney/netbridge/releases/latest/download/NetBridge-nbvpn-Setup-win2012.exe
- 现代：https://github.com/PHPJourney/netbridge/releases/latest/download/NetBridge-nbvpn-Setup.exe
