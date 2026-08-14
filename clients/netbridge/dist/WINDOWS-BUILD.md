# Windows package (build on a Windows machine)

Flutter **cannot** cross-compile Windows desktop from macOS or from a Linux Docker
container. This Mac build therefore has **no** `NetBridge-windows.exe` unless you
pass `WINDOWS_ARTIFACT` from a real Windows build.

## OS requirements (client)

| Host | Can build Flutter Windows? | Can run client? |
|------|----------------------------|-----------------|
| Windows 10 / 11 | Yes (VS 2022 + Flutter) | Yes |
| Server 2019 / 2022 | Usually yes | Usually yes |
| **Server 2012 / 2012 R2** | **No** | **No** — modern Flutter Windows needs Win10+ APIs |
| Linux Docker on Mac | **No** — no Windows SDK / MSVC | N/A |
| Windows container on Windows host | Possible in theory; not supported in this repo | N/A |

**Server 2012 R2 is not a client runtime and not a build host.** Lab host
`154.36.178.124` (2012 R2) is for **server** `nbvpn` experiments only
(use `nbvpn-windows-amd64-win2012.exe`). Do **not** claim the Flutter client
works on 2012.

## Icon assets (already updated on Mac)

Launcher icons were generated with `dart run flutter_launcher_icons` from
`assets/branding/netbridge_icon_1024.png` (same bytes as
`assets/branding/icon-privacy-store-try.png`). Windows runner icon:

- `windows/runner/resources/app_icon.ico`

Rebuild on Windows will pick up that `.ico` automatically.

## Build on Windows (VS 2022 + Flutter desktop)

```bat
cd clients\netbridge
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter build windows --release
```

Then either:

```bat
bash scripts/package-all.sh
```

or copy the Release folder / exe to any host and set:

```bash
# Directory containing the runner .exe + DLLs:
export WINDOWS_ARTIFACT=/path/to/build/windows/x64/runner/Release
# Or a single .exe file:
# export WINDOWS_ARTIFACT=/path/to/NetBridge.exe
./scripts/package-all.sh
```

Outputs when Windows artifact is available:
- **`dist/NetBridge-windows-setup.exe`** — **primary** Inno Setup installer (Program Files + Start Menu + uninstaller)
- `dist/NetBridge-windows-portable.zip` — secondary portable zip (full Release folder)
- `dist/NetBridge-windows.exe` — runner exe alone (insufficient without DLLs)

## Inno Setup (local / CI)

CI (`build-clients.yml` on windows-2022) installs Inno Setup via Chocolatey and runs:

```powershell
cd clients\netbridge
flutter build windows --release
.\installer\windows\build-setup.ps1
# → dist\NetBridge-windows-setup.exe
```

Script: `clients/netbridge/installer/windows/NetBridge-setup.iss`

VPN: WireGuard tunnel may require **Run as administrator**. No Authenticode
signing is applied by this script.

## Docker note

- **Server (Go):** use `server/nbvpn/scripts/build-windows-docker.sh` — Docker **is**
  the recommended way to produce Win2012 vs Win10 server binaries on a Mac.
- **Client (Flutter):** Linux Docker on Mac **cannot** produce the Windows desktop
  app. Use a Win10+ machine (or CI Windows runner) and `WINDOWS_ARTIFACT`.
