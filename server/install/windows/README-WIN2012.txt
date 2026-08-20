NetBridge nbvpn — Server 2012 / 2012 R2

本安装包：NetBridge-nbvpn-Setup-win2012.exe
包含：
- nbvpn.exe（Go 1.20 CLI）
- nbvpn-gui.exe（纯 Win32 管理 GUI，无 Fyne / 无 MinGW CRT）
- WireGuard for Windows 0.5.3（历史官方 MSI，兼容 Server 2012；不是现代 1.1）

安装后：
- 开始菜单 →「NetBridge nbvpn GUI」—— 启停、状态、peer、URI、QR、数据目录
- 可选：「NetBridge nbvpn 管理 (菜单)」cmd 数字菜单
- 「nbvpn 命令提示符」

说明：
- 现代 NetBridge-nbvpn-Setup.exe（WG 1.1 + Fyne）仅 Win10 / Server 2016+
- 官方已 sunset 对旧系统的支持；本包钉死 0.5.3（Chocolatey 校验 SHA256）
- 若 MSI 静默安装后需重启，请重启再 nbvpn start / 开 GUI「启动」

文档：WINDOWS.md
