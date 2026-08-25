import '../../profile/nbvpn_profile.dart';

/// Platform VPN tunnel abstraction.
abstract class VpnTunnel {
  Stream<VpnTunnelStage> get stageStream;

  Future<void> initialize();

  /// Start tunnel for [profile]. Implementations must not log private keys.
  ///
  /// [killSwitch]: preference for blocking non-VPN traffic (OS-dependent).
  /// [excludePrivateNetworks]: rewrite full-tunnel AllowedIPs to exclude LAN.
  /// [forceFullTunnel]: leak-protection mode — ignores exclude-private.
  /// [bypassCidrs]: IPv4 CIDRs removed from AllowedIPs (direct whitelist).
  Future<void> connect(
    NbVpnProfile profile, {
    required bool killSwitch,
    bool excludePrivateNetworks = false,
    bool forceFullTunnel = false,
    List<String> bypassCidrs = const [],
  });

  Future<void> disconnect();

  Future<VpnTunnelStage> currentStage();

  /// Human-readable capability note for settings / IMPL.
  String get capabilityNote;

  bool get supportsRealTunnel;
}

enum VpnTunnelStage {
  disconnected,
  preparing,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  denied,
  error,
  noConnection,
}
