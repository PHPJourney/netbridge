/// Apple Packet Tunnel / App Group identifiers for 网桥 VPN.
///
/// No Team ID or provisioning secrets live here. After Xcode embeds WGExtension
/// and you sign with a real Team, set [extensionTargetLinked] to true.
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

  /// Flip to `true` only after:
  /// 1) WGExtension target exists and is embedded in Runner
  /// 2) Network Extension + App Group entitlements signed for your Team
  /// 3) (for production tunnel) WireGuardKit linked into WGExtension
  ///
  /// While `false`, iOS/macOS use [StubVpnTunnel] so UI remains usable.
  static const bool extensionTargetLinked = false;
}
