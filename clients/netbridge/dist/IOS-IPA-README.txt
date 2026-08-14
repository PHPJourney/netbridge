NetBridge iOS IPA — signing requirements
========================================

This machine currently has NO Apple Development / Distribution identities
(security find-identity -v -p codesigning → 0 valid).

What you must provide for a REAL installable IPA (non–App Store OK):
  1. Paid Apple Developer Program membership
  2. APPLE_TEAM_ID (10-char Team ID)
  3. Apple Development or Apple Distribution certificate in login keychain
  4. Provisioning profile(s) for:
       - com.netbridge.netbridge
       - com.netbridge.netbridge.WGExtension  (if NE linked)
  5. ios/ExportOptions.plist (see ios/ExportOptions.plist.example)
       method: ad-hoc | development | enterprise (NOT app-store if sideloading)

Then:
  export APPLE_TEAM_ID=XXXXXXXXXX
  # optionally copy ExportOptions.plist.example → ExportOptions.plist and edit teamID
  ./scripts/package-all.sh

Or manually:
  flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

Unsigned / --no-codesign IPA (if present as NetBridge-iOS.ipa):
  - Useful as a pipeline artifact only
  - CANNOT install on normal devices (no matching provisioning)
  - Dev devices still need a signed build with your Team UUID registered

Network Extension / real WireGuard tunnel additionally needs NE entitlements
on both host + extension — see apple/README.md and IMPL.md.
