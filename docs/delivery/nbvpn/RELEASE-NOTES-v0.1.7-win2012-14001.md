# RELEASE NOTES — v0.1.7 (Server 2012 14001 / SxS)

## Root cause

On Server 2012 R2, double-clicking `nbvpn-windows-amd64-win2012.exe` (and the modern `nbvpn-windows-amd64.exe`) failed with **CreateProcess error 14001** / 「并行配置不正确」(SxS).

This was **not** a wrong Setup package, and **not** Go 1.21+ / Fyne / CGO in the win2012 CLI path.

v0.1.6 Release PE checks already showed:

- embeds `go1.20.14`
- imports only `kernel32.dll` (pure Go, `CGO_ENABLED=0`)
- PE MajorOS / Subsystem **6.1**

The failure came from the **embedded application manifest** in `resource_windows_amd64.syso` (from `assets/nbvpn.manifest`):

```xml
<!-- INVALID GUID — 4th group has 3 hex digits instead of 4 -->
<supportedOS Id="{e2011457-1546-43dc-5fe-2a023fafe7aa}"/>
```

Correct Vista GUID is `{e2011457-1546-43dc-a9fe-2a023fafe7aa}`. A malformed `supportedOS` Id makes Windows fail activation-context generation → **ERROR_SXS_CANT_GEN_ACTCTX (14001)** before `main` runs. That is why even `nbvpn version` could not start.

## Fix

- Correct Vista `supportedOS` GUID in CLI + GUI manifests; regenerate `*.syso`.
- CI `windows-win2012`: assert valid GUID, no Fyne/CRT strings, import table is only `kernel32.dll`, PE subsystem 6.1, Go 1.20.14, `CGO_ENABLED=0`.
- Docs / Store: 2012 must use elevated PowerShell `install.ps1` (not Setup); verify with `.\nbvpn-windows-amd64-win2012.exe version` first.

## Correct 2012 install

```powershell
cd C:\NetBridge\deploy
.\nbvpn-windows-amd64-win2012.exe version
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipWireGuard
```

Download: [v0.1.7](https://github.com/PHPJourney/netbridge/releases/tag/v0.1.7) → `nbvpn-windows-amd64-win2012.exe` + `install.ps1`.
