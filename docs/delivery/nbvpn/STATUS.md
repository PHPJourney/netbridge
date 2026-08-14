# Status

- 需求: nbvpn
- 当前状态: impl（Windows Server MVP 已落地；T07 仍 NO-GO — Store mock≠真 CDN、Apple NE、无四端实机 E2E）
- 竖切: S02 含 Windows Server MVP；S05 客户交付 QA 未因 Win 节点改 GO
- Context 根: docs/dev-workflow/context/
- 冻结契约: 是（2026-08-14；Profile/URI 不变）
- 阻塞: DEF-01 OpenList **真**直链仍待上传（清单见 OPENLIST-UPLOAD.md）；DEF-02 Apple Team/NE；DEF-04 正式签名包 / Windows 客户端 exe；云安全组 UDP 51820；Win2012 真机 install 未完成（WG/Wintun 存疑）
- 已解除: DEF-03 无 Linux VPS — Debian 12 `netbridge-vps` 已冒烟；Q-04 已改为纳入 Windows Server
- 最近变更: 交叉编译刷新 `nbvpn-windows-amd64.exe`；OpenList 上传清单；Win2012 探测 — 2026-08-14
- Windows 测试机: `154.36.178.124`（2012 R2）；SSH 不可用；WinRM 5985 NTLM 可用；别名 `netbridge-win2012` **未建**（无 OpenSSH）
- 证据路径:
  - docs/delivery/nbvpn/OPENLIST-UPLOAD.md
  - docs/delivery/nbvpn/04-impl-notes.md
  - server/install/windows/{install.ps1,WINDOWS.md}
  - server/nbvpn/dist/nbvpn-windows-amd64.exe (+ `.sha256`)
  - server/nbvpn/dist/nbvpn-linux-amd64 (+ `.sha256`) — Linux 路径未改
  - apps/store/public/releases.json（servers.windows mock）
  - docs/dev-workflow/context/scope.md（IN-02b；OUT-05 历史行）
