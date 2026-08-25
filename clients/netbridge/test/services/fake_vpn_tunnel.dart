import 'dart:async';

import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/vpn/vpn_tunnel.dart';

/// Controllable tunnel for unit tests (`supportsRealTunnel == true`).
class FakeVpnTunnel implements VpnTunnel {
  FakeVpnTunnel({
    this.connectDelay = const Duration(milliseconds: 40),
    this.disconnectDelay = const Duration(milliseconds: 30),
    this.failConnect = false,
    this.finalStage = VpnTunnelStage.connected,
  });

  final Duration connectDelay;
  final Duration disconnectDelay;
  final bool failConnect;
  final VpnTunnelStage finalStage;

  final _controller = StreamController<VpnTunnelStage>.broadcast();
  VpnTunnelStage _stage = VpnTunnelStage.disconnected;
  VpnTunnelStage initialStage = VpnTunnelStage.disconnected;
  int connectCount = 0;
  int disconnectCount = 0;
  final List<String> connectedEndpoints = [];
  bool? lastForceFullTunnel;
  bool? lastExcludePrivate;
  bool? lastKillSwitch;
  List<String> lastBypassCidrs = const [];

  @override
  bool get supportsRealTunnel => true;

  @override
  String get capabilityNote => 'fake tunnel for tests';

  @override
  Stream<VpnTunnelStage> get stageStream => _controller.stream;

  @override
  Future<void> initialize() async {
    _stage = initialStage;
    _emit(_stage);
  }

  void simulateStage(VpnTunnelStage stage) => _emit(stage);

  @override
  Future<VpnTunnelStage> currentStage() async => _stage;

  @override
  Future<void> connect(
    NbVpnProfile profile, {
    required bool killSwitch,
    bool excludePrivateNetworks = false,
    bool forceFullTunnel = false,
    List<String> bypassCidrs = const [],
  }) async {
    connectCount++;
    connectedEndpoints.add(profile.server.activeEndpoint);
    lastForceFullTunnel = forceFullTunnel;
    lastBypassCidrs = List<String>.from(bypassCidrs);
    lastExcludePrivate = excludePrivateNetworks;
    lastKillSwitch = killSwitch;
    _emit(VpnTunnelStage.connecting);
    await Future<void>.delayed(connectDelay);
    if (failConnect) {
      _emit(VpnTunnelStage.error);
      throw StateError('fake connect failed');
    }
    _emit(finalStage);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _emit(VpnTunnelStage.disconnecting);
    await Future<void>.delayed(disconnectDelay);
    _emit(VpnTunnelStage.disconnected);
  }

  void _emit(VpnTunnelStage s) {
    _stage = s;
    if (!_controller.isClosed) {
      _controller.add(s);
    }
  }
}
