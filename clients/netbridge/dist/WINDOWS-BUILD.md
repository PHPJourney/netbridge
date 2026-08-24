# Windows package (build on a Windows machine)

Flutter cannot cross-compile Windows from macOS. This Mac build therefore has
**no** `NetBridge-windows.exe` unless you pass `WINDOWS_ARTIFACT`.

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
- `dist/NetBridge-windows.exe` — main runner exe
- `dist/NetBridge-windows-portable.zip` — full Flutter Windows Release folder (required DLLs)

VPN: WireGuard tunnel may require **Run as administrator**. No Authenticode
signing is applied by this script.
