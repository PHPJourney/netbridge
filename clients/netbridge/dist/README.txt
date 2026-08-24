NetBridge client distribution packages (local build)
Version: 0.1.13
Generated: 2026-08-24T11:58Z
Icon: assets/branding/netbridge_icon_1024.png (= icon-privacy-store-try.png)
      applied via flutter_launcher_icons → Android/iOS/macOS/Windows assets

Artifacts (canonical names)
---------------------------
  NetBridge-android-arm64.apk   Android arm64-v8a, R8 minify, debug-signed sideload
  NetBridge-windows.exe         Windows runner (or portable zip) — build on Windows / WINDOWS_ARTIFACT
  NetBridge-macOS.dmg           macOS app + Applications link; ad-hoc codesign
  NetBridge-iOS.ipa             iOS IPA (signed only with Apple Team; else UNSIGNED stub)

Also produced when applicable:
  NetBridge-android.apk         alias of arm64 slim APK
  NetBridge-android-armeabi-v7a.apk  optional 32-bit ARM APK
  NetBridge-macOS.app / .zip    same app as in the DMG
  NetBridge-windows-portable.zip  full Flutter Windows Release folder
  *.sha256                      checksums
  PACKAGE-STATUS.txt            per-platform OK / STUB / SKIPPED
  IOS-IPA-README.txt            what is required for a real IPA
  WINDOWS-BUILD.md              how to produce the Windows exe (WINDOWS_ARTIFACT)

Signing notes
-------------
  Android  debug keystore (sideload OK; not Play Store)
  macOS    ad-hoc (codesign --sign -); NOT Developer ID / NOT notarized; Gatekeeper: right-click Open
  iOS      unsigned stub unless APPLE_TEAM_ID + certs; see IOS-IPA-README.txt
  Windows  no Authenticode from this Mac; icon .ico already updated in-repo

Install (short)
---------------
  Android: allow unknown sources → install APK → paste URI from VPS
  Windows: unzip portable.zip OR run .exe (VPN may need Administrator)
  macOS:   open DMG → drag NetBridge.app to Applications → right-click Open (Gatekeeper)
  iOS:     unsigned IPA will NOT install; need Team ID + profiles (see IOS-IPA-README.txt)

VPN capability matrix
---------------------
  Android  REAL WireGuard via wireguard_flutter (system VPN prompt)
  Windows  Plugin may work; often needs Administrator; no Authenticode here
  macOS    Ad-hoc / self-sign: UI+import OK; system Packet Tunnel needs Apple Team + NE
  iOS      Same as macOS; without Team ID this IPA is pipeline-only

URI:
  ssh netbridge-vps 'nbvpn show --uri'

See docs/delivery/nbvpn/TRY-CONNECT.md
