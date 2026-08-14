# RELEASE NOTES — WireGuard msiexec quoting + GUI 14001 (pre-v0.1.4)

> Tag **v0.1.4** when ready for GitHub Release. This commit is on `main` only — do **not** treat as a release until tagged.

## Fixes (v0.1.3 → v0.1.4)

### WireGuard Setup hard-fail

- **Root cause (Win10+/2016+):** `Install-WireGuard.ps1` passed msiexec args as a PowerShell array; MSI under `C:\Program Files\NetBridge\vendor\wireguard\` contains spaces → msiexec often **1619/1603** → `install.ps1` exit 1 → Inno aborted.
- **Fix:** single quoted `ArgumentList` string; treat **3010/1641** as success; accept **1638** / partial install if `wireguard.exe` exists; success = **exe on disk**.
- **Server 2012:** Setup `MinVersion=10.0` + clear refuse banner. Use `nbvpn-windows-amd64-win2012.exe` + `install.ps1` (WG skipped, dry-run).
- **Logs:** `%TEMP%\nbvpn-setup-latest.log`, `%TEMP%\nbvpn-setup-last-error.txt`, msiexec logs under TEMP + `%ProgramData%\nbvpn\` — Inno MsgBox shows detail.

### GUI CreateProcess 14001

- **Root cause:** Fyne/CGO MinGW build dynamically linked runtime DLLs (`libgcc` / `libstdc++` / `libwinpthread`) → SxS / 14001 on clean hosts.
- **Fix:** CI static-links MinGW CRT (`CGO_LDFLAGS` + `-extldflags=-static`); `objdump` gate; Setup **no longer** auto-launches GUI post-install.

### Client tray right-click + single instance

- **Tray:** Windows `tray_manager` does not auto-show menu after `setContextMenu`; right-click now calls `popUpContextMenu`.
- **Flutter client single instance:** `windows_single_instance` — second launch shows/focuses existing window (incl. tray-hidden) then exits.
- **`nbvpn-gui` single instance:** named mutex + `FindWindow` restore/focus.

## Tag

Push does **not** create a tag. Create **`v0.1.4`** when you want Release artifacts / store sha update.
