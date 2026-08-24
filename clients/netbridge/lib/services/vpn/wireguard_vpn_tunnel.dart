import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

import '../../profile/nbvpn_profile.dart';
import '../../profile/profile_codec.dart';
import 'apple_tunnel_config.dart';
import 'stub_vpn_tunnel.dart';
import 'vpn_tunnel.dart';

/// WireGuard via `wireguard_flutter`.
///
/// Android: real tunnel when VPN permission granted.
/// iOS/macOS: needs Packet Tunnel Network Extension (see apple/ + IMPL.md).
/// Windows: needs elevated privileges.
class WireGuardVpnTunnel implements VpnTunnel {
  WireGuardVpnTunnel({
    this.interfaceName = 'nbvpn',
    this.providerBundleIdentifier =
        AppleTunnelConfig.providerBundleIdentifier,
  });

  final String interfaceName;
  final String providerBundleIdentifier;

  final _controller = StreamController<VpnTunnelStage>.broadcast();
  bool _initialized = false;

  @override
  bool get supportsRealTunnel {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isWindows ||
        Platform.isIOS ||
        Platform.isMacOS;
  }

  @override
  String get capabilityNote {
    if (kIsWeb) return 'Web 不支持 VPN 隧道。';
    if (Platform.isAndroid) {
      return 'Android：通过 wireguard_flutter 建立真实隧道（需系统 VPN 授权）。'
          'Kill Switch 依赖隧道断开策略，完整阻断以系统能力为准。';
    }
    if (Platform.isWindows) {
      return 'Windows：wireguard_flutter 可建隧道，需管理员权限；'
          'Kill Switch 需额外防火墙规则（见 IMPL.md）。';
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return 'iOS/macOS：WGExtension 已嵌入（$providerBundleIdentifier）。'
          'Debug 可用 Personal Team 编过；真 Packet Tunnel 需付费账号 + NE/'
          'App Group（Release entitlements）。WireGuardKit 尚未 SPM 接入'
          '（passepartout 源 404），隧道数据面见 apple/*.example / IMPL.md。';
    }
    return '本平台暂无真实隧道集成。';
  }

  @override
  Stream<VpnTunnelStage> get stageStream => _controller.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await WireGuardFlutter.instance.initialize(interfaceName: interfaceName);
    WireGuardFlutter.instance.vpnStageSnapshot.listen((stage) {
      _controller.add(_mapStage(stage));
    });
    _initialized = true;
    // Prefer live OS stage so UI does not wipe an already-up tunnel.
    try {
      final live = await WireGuardFlutter.instance.stage();
      _controller.add(_mapStage(live));
    } catch (_) {
      _controller.add(VpnTunnelStage.disconnected);
    }
  }

  @override
  Future<VpnTunnelStage> currentStage() async {
    try {
      final s = await WireGuardFlutter.instance.stage();
      return _mapStage(s);
    } catch (_) {
      return VpnTunnelStage.error;
    }
  }

  @override
  Future<void> connect(NbVpnProfile profile, {required bool killSwitch}) async {
    await initialize();
    final conf = ProfileCodec.toWireGuardConf(profile);
    // killSwitch preference is persisted in Settings; OS-level KS varies by
    // platform (see IMPL.md). Parameter kept for future native wiring.
    // ignore: unused_local_variable
    final _ = killSwitch;
    _controller.add(VpnTunnelStage.connecting);
    await WireGuardFlutter.instance.startVpn(
      serverAddress: profile.server.endpoint,
      wgQuickConfig: conf,
      providerBundleIdentifier: providerBundleIdentifier,
    );
  }

  @override
  Future<void> disconnect() async {
    _controller.add(VpnTunnelStage.disconnecting);
    await WireGuardFlutter.instance.stopVpn();
  }

  VpnTunnelStage _mapStage(VpnStage stage) {
    return switch (stage) {
      VpnStage.disconnected => VpnTunnelStage.disconnected,
      VpnStage.preparing => VpnTunnelStage.preparing,
      VpnStage.connecting => VpnTunnelStage.connecting,
      VpnStage.connected => VpnTunnelStage.connected,
      VpnStage.disconnecting => VpnTunnelStage.disconnecting,
      VpnStage.denied => VpnTunnelStage.denied,
      VpnStage.noConnection => VpnTunnelStage.noConnection,
      VpnStage.exiting => VpnTunnelStage.disconnecting,
      VpnStage.waitingConnection => VpnTunnelStage.reconnecting,
      VpnStage.authenticating => VpnTunnelStage.connecting,
      VpnStage.reconnect => VpnTunnelStage.reconnecting,
    };
  }
}

/// Prefer WireGuard plugin when the platform (and Apple extension) is ready;
/// otherwise Stub so UI flows remain testable.
VpnTunnel createVpnTunnel({bool forceStub = false}) {
  if (forceStub || kIsWeb) {
    return StubVpnTunnel();
  }
  if (Platform.isAndroid || Platform.isWindows) {
    return WireGuardVpnTunnel();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    if (AppleTunnelConfig.extensionTargetLinked) {
      return WireGuardVpnTunnel(
        providerBundleIdentifier: AppleTunnelConfig.providerBundleIdentifier,
      );
    }
    return StubVpnTunnel(
      capabilityNote:
          'iOS/macOS：WGExtension 脚手架已就位，但尚未在 Xcode 链接/签名 '
          '(AppleTunnelConfig.extensionTargetLinked=false)。'
          '不会弹出系统 VPN 权限；点连接会提示改用官方 WireGuard 或完成签名。'
          'App Group: ${AppleTunnelConfig.appGroupId}。',
    );
  }
  return StubVpnTunnel();
}
