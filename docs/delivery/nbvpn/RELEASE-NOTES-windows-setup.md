# Release notes — Windows Setup (next tag)

Use this block in the next GitHub Release (`v0.1.1` or later) after CI attaches Setup artifacts.

## Highlights

- **Windows client**: primary download is now **`NetBridge-windows-setup.exe`** (Inno Setup → Program Files, Start Menu, uninstaller). Portable zip remains secondary: `NetBridge-windows-portable.zip`.
- **Windows server (nbvpn)**: primary download **`NetBridge-nbvpn-Setup.exe`**. **Bundles pinned WireGuard for Windows MSI** and silently installs when missing (skip if already present). Advanced path: `install.ps1` + raw exe. Server 2012 R2: `nbvpn-windows-amd64-win2012.exe` (no official WG auto-install).
- **Server 2012**: skip broken `New-NetNat`; WG auto-install skipped with explicit banner; profiles still written; **terminal half-block QR always printed** (GUI win2012 shows QR in-window; PNG optional).
- **ProgramData** is a hidden folder — after install run `explorer %ProgramData%\nbvpn`.
- After Setup on Win10+/2016+: `nbvpn start` should work without a separate wireguard.com visit (reboot once if MSI exit 3010).

## Assets (expected names)

| Asset | Role |
|-------|------|
| `NetBridge-windows-setup.exe` | Client installer |
| `NetBridge-windows-portable.zip` | Client portable |
| `NetBridge-nbvpn-Setup.exe` | Server node installer |
| `nbvpn-windows-amd64.exe` | Server raw exe (Win10+) |
| `nbvpn-windows-amd64-win2012.exe` | Server raw exe (2012 R2) |
| `nbvpn-server-<tag>.zip` | Full server bundle |

## Store / Pages

Update `apps/store/public/releases.json` SHA256 fields after the Release is published (`pending_next_tag` placeholders).
