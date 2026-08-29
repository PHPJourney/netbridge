/// Apple Packet Tunnel / App Group identifiers for 网桥 VPN.
///
/// WireGuardKit is vendored into ios|macos/WGExtension/vendor (Swift + C + Go
/// data plane, libwg-go.a). [extensionTargetLinked] stays true when WGExtension
/// is built and signed with a paid Team (Network Extension capability).
class AppleTunnelConfig {
  AppleTunnelConfig._();

  /// Must match Xcode WGExtension `PRODUCT_BUNDLE_IDENTIFIER`.
  static const String providerBundleIdentifier =
      'com.netbridge.netbridge.WGExtension';

  /// Must match Runner + WGExtension entitlements App Group.
  /// Create `group.com.netbridge.netbridge` under your Apple Team in the portal.
  static const String appGroupId = 'group.com.netbridge.netbridge';

  /// Host app bundle id (Flutter default).
  static const String hostBundleIdentifier = 'com.netbridge.netbridge';

  /// Set `true` when WGExtension is embedded in Runner (Xcode Embed Foundation
  /// Extensions) with matching bundle id / App Group. WireGuardKit is linked
  /// into the extension target. **Signing still requires a Team that can use
  /// Network Extension** (paid Apple Developer Program). Personal Team often
  /// builds but cannot activate Packet Tunnel — see IMPL.md.
  ///
  /// While `false`, iOS/macOS use [StubVpnTunnel] so UI remains usable.
  static const bool extensionTargetLinked = true;
}
