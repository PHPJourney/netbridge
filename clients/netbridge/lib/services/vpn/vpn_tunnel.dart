import '../../profile/nbvpn_profile.dart';

/// Platform VPN tunnel abstraction.
abstract class VpnTunnel {
  Stream<VpnTunnelStage> get stageStream;

  Future<void> initialize();

  /// Start tunnel for [profile]. Implementations must not log private keys.
  Future<void> connect(
    NbVpnProfile profile, {
    required bool killSwitch,
    bool excludePrivateNetworks = false,
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
