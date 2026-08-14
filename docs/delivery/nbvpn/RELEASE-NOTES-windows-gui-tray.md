# RELEASE NOTES — Windows native GUI + WireGuard Setup harden (pre-v0.1.3)

> Tag **v0.1.3** when ready for GitHub Release. This commit is on `main` only.

## Server (`NetBridge-nbvpn-Setup.exe`)

- **WG auto-install**: Setup **must** embed pinned MSI; `install.ps1` hard-fails Setup on error (no silent skip).
- **`nbvpn-gui.exe`**: Fyne native window (not browser). In-window QR, Start/Stop via hidden `nbvpn`, app icon.
- **Tray**: close → hide; tunnel keeps running; tray exit quits process.
- **Icon**: embedded in `nbvpn.exe` / `nbvpn-gui.exe` + Setup icon.

## Client (Flutter Windows)

- Close → tray; left-click tray restores; right-click: show / switch server / connect-disconnect / exit.
- VPN stays connected while hidden.

## Tag

Push does **not** create a tag. Create `v0.1.3` when you want Release artifacts.
