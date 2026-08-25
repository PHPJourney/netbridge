import 'dart:async';

import '../../profile/nbvpn_profile.dart';
import 'vpn_tunnel.dart';

/// State-machine stub used when native WireGuard is unavailable.
/// Advances connecting → connected; supports simulated reconnect.
class StubVpnTunnel implements VpnTunnel {
  StubVpnTunnel({String? capabilityNote})
      : _capabilityNote = capabilityNote ??
            '当前平台为模拟隧道：可验证 UI 与状态机。真实 VPN 需原生 WireGuard 集成（见 IMPL.md）。';

  final String _capabilityNote;
  final _controller = StreamController<VpnTunnelStage>.broadcast();
  VpnTunnelStage _stage = VpnTunnelStage.disconnected;
  Timer? _reconnectTimer;

  @override
  bool get supportsRealTunnel => false;

  @override
  String get capabilityNote => _capabilityNote;

  @override
  Stream<VpnTunnelStage> get stageStream => _controller.stream;

  @override
  Future<void> initialize() async {
    _emit(VpnTunnelStage.disconnected);
  }

  @override
  Future<VpnTunnelStage> currentStage() async => _stage;

  @override
  Future<void> connect(
    NbVpnProfile profile, {
    required bool killSwitch,
    bool excludePrivateNetworks = false,
  }) async {
    _reconnectTimer?.cancel();
    _emit(VpnTunnelStage.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Validate endpoint presence already done by profile; mark connected.
    _emit(VpnTunnelStage.connected);
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _emit(VpnTunnelStage.disconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _emit(VpnTunnelStage.disconnected);
  }

  /// Simulate brief outage then auto-reconnect (FR-C07).
  void simulateNetworkBlip() {
    if (_stage != VpnTunnelStage.connected) return;
    _emit(VpnTunnelStage.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _emit(VpnTunnelStage.connected);
    });
  }

  void _emit(VpnTunnelStage s) {
    _stage = s;
    if (!_controller.isClosed) {
      _controller.add(s);
    }
  }
}
