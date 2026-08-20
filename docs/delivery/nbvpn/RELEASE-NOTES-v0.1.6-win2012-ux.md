# RELEASE NOTES — v0.1.6 (Server 2012 UX)

## Root cause (user reports on v0.1.4 / v0.1.5)

Screenshot title **「Setup - 网桥 VPN (NetBridge) v0.1.4」** matches the **Flutter client** Inno `AppName`, not server `NetBridge nbvpn`.

| Asset | Status on v0.1.4 / v0.1.5 |
|-------|---------------------------|
| `nbvpn-windows-amd64-win2012.exe` | Present; embeds **go1.20.14**; PE MajorOS/Subsystem **6.1** — theoretically runnable on 2012 R2 |
| `NetBridge-nbvpn-Setup.exe` | Present; `MinVersion=10.0` (correct refuse on 2012) |
| `NetBridge-windows-setup.exe` | Present; **no MinVersion** before v0.1.6 → English refuse / unusable on 2012 |

**Conclusion:** win2012 **server** binary was not “broken” by wrong Go version. Users hit **client / modern Setup** by mistake.

## Fixes in v0.1.6

- Client Setup: `MinVersion=10.0` + zh/en banner pointing to win2012 + `install.ps1`.
- Store: Windows server card banner + Advanced default-open with 3 steps + install.ps1 button; client card “Win10+ only / not 2012”.
- CI `windows-win2012`: assert `GOVERSION=go1.20.14` and binary embeds `go1.20.*`.
- Docs: `WINDOWS.md` forbids client Setup on 2012.

## Correct 2012 install

1. Download `nbvpn-windows-amd64-win2012.exe`
2. Download `install.ps1` (same folder)
3. Elevated: `powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipWireGuard`
