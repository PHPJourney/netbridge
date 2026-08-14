import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/server_entry.dart';
import '../profile/nbvpn_profile.dart';
import '../services/server_store.dart';
import '../services/settings_store.dart';
import '../services/vpn/vpn_errors.dart';
import '../services/vpn/vpn_tunnel.dart';
import '../services/vpn/wireguard_vpn_tunnel.dart';

class AppController extends ChangeNotifier {
  AppController({
    ServerStore? serverStore,
    SettingsStore? settingsStore,
    VpnTunnel? tunnel,
  })  : _serverStore = serverStore ?? ServerStore(),
        _settingsStore = settingsStore ?? SettingsStore(),
        _tunnel = tunnel ?? createVpnTunnel();

  final ServerStore _serverStore;
  final SettingsStore _settingsStore;
  final VpnTunnel _tunnel;
  final _uuid = const Uuid();

  List<ServerEntry> servers = [];
  bool loading = true;
  bool killSwitch = true;
  AppLocaleMode localeMode = AppLocaleMode.system;
  /// Resolved UI language for errors / snackbars without BuildContext (`zh`|`en`).
  String languageCode = 'zh';
  VpnUiStatus status = VpnUiStatus.disconnected;
  String? activeServerId;
  String? lastError;
  String? statusDetail;
  StreamSubscription<VpnTunnelStage>? _stageSub;
  bool _usingFallbackStub = false;
  VpnTunnel? _fallbackStub;

  VpnTunnel get tunnel => _fallbackStub ?? _tunnel;

  String get vpnCapabilityNote => tunnel.capabilityNote;

  bool get supportsRealTunnel => tunnel.supportsRealTunnel && !_usingFallbackStub;

  void refreshResolvedLanguage() {
    languageCode = switch (localeMode) {
      AppLocaleMode.en => 'en',
      AppLocaleMode.zh => 'zh',
      AppLocaleMode.system =>
        PlatformDispatcher.instance.locale.languageCode.toLowerCase().startsWith('en')
            ? 'en'
            : 'zh',
    };
  }

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      servers = await _serverStore.load();
      killSwitch = await _settingsStore.getKillSwitch();
      localeMode = await _settingsStore.getLocaleMode();
      refreshResolvedLanguage();
      try {
        await _tunnel.initialize();
        _stageSub = _tunnel.stageStream.listen(_onStage);
      } catch (e) {
        // Fall back to stub so UI remains usable.
        _usingFallbackStub = true;
        _fallbackStub = createVpnTunnel(forceStub: true);
        await _fallbackStub!.initialize();
        _stageSub = _fallbackStub!.stageStream.listen(_onStage);
        lastError = languageCode == 'en'
            ? 'Native VPN init failed; switched to stub tunnel: $e'
            : '原生 VPN 初始化失败，已切换为模拟隧道：$e';
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _onStage(VpnTunnelStage stage) {
    status = switch (stage) {
      VpnTunnelStage.disconnected ||
      VpnTunnelStage.disconnecting =>
        VpnUiStatus.disconnected,
      VpnTunnelStage.preparing ||
      VpnTunnelStage.connecting =>
        VpnUiStatus.connecting,
      VpnTunnelStage.connected => VpnUiStatus.connected,
      VpnTunnelStage.reconnecting ||
      VpnTunnelStage.noConnection =>
        VpnUiStatus.reconnecting,
      VpnTunnelStage.denied ||
      VpnTunnelStage.error =>
        VpnUiStatus.error,
    };
    if (stage == VpnTunnelStage.disconnected ||
        stage == VpnTunnelStage.disconnecting) {
      if (status == VpnUiStatus.disconnected) {
        activeServerId = null;
      }
    }
    if (stage == VpnTunnelStage.denied) {
      lastError = languageCode == 'en'
          ? 'VPN permission was denied. Allow “NetBridge VPN” in system settings.'
          : '系统拒绝了 VPN 权限。请在系统设置中允许「网桥 VPN」。';
    }
    if (stage == VpnTunnelStage.error) {
      lastError ??= languageCode == 'en'
          ? 'Tunnel error. Retry or check that the node is reachable.'
          : '隧道错误，请重试或检查节点是否可达。';
    }
    notifyListeners();
  }

  Future<void> persist() => _serverStore.save(servers);

  /// Existing entry with the same endpoint + WireGuard keys, if any.
  ServerEntry? findDuplicate(NbVpnProfile profile) {
    for (final e in servers) {
      if (e.profile.sameCredentialsAs(profile)) return e;
    }
    return null;
  }

  Future<ServerEntry> addServer({
    required NbVpnProfile profile,
    required String localName,
  }) async {
    final existing = findDuplicate(profile);
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now().toUtc();
    final entry = ServerEntry(
      id: _uuid.v4(),
      localName: localName.trim().isEmpty ? profile.name : localName.trim(),
      profile: profile,
      createdAt: now,
      updatedAt: now,
    );
    servers = [...servers, entry];
    await persist();
    notifyListeners();
    return entry;
  }

  Future<void> renameServer(String id, String localName) async {
    final i = servers.indexWhere((e) => e.id == id);
    if (i < 0) return;
    servers[i].localName = localName.trim();
    servers[i].updatedAt = DateTime.now().toUtc();
    await persist();
    notifyListeners();
  }

  Future<void> deleteServer(String id) async {
    if (activeServerId == id && status != VpnUiStatus.disconnected) {
      await disconnect();
    }
    if (activeServerId == id) {
      activeServerId = null;
    }
    servers = servers.where((e) => e.id != id).toList();
    await persist();
    notifyListeners();
  }

  Future<void> setKillSwitch(bool value) async {
    killSwitch = value;
    await _settingsStore.setKillSwitch(value);
    notifyListeners();
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    localeMode = mode;
    refreshResolvedLanguage();
    await _settingsStore.setLocaleMode(mode);
    notifyListeners();
  }

  String humanize(Object error) =>
      humanizeVpnError(error, languageCode: languageCode);

  Future<void> connect(String serverId) async {
    ServerEntry? entry;
    for (final e in servers) {
      if (e.id == serverId) {
        entry = e;
        break;
      }
    }
    if (entry == null) return;

    lastError = null;
    // Only one tunnel: disconnect first if switching.
    if (activeServerId != null &&
        activeServerId != serverId &&
        status != VpnUiStatus.disconnected) {
      await disconnect();
    }

    activeServerId = serverId;
    status = VpnUiStatus.connecting;
    notifyListeners();

    try {
      await tunnel.connect(entry.profile, killSwitch: killSwitch);
    } catch (e) {
      // On Apple, if extension is linked but startVpn fails, fall back to stub
      // so UI remains usable (scaffold without WireGuardKit / unsigned build).
      if (!_usingFallbackStub &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        try {
          await _stageSub?.cancel();
          _usingFallbackStub = true;
          _fallbackStub = createVpnTunnel(forceStub: true);
          await _fallbackStub!.initialize();
          _stageSub = _fallbackStub!.stageStream.listen(_onStage);
          lastError = languageCode == 'en'
              ? 'Packet Tunnel failed to start; fell back to stub (not production VPN). Detail: ${humanize(e)}'
              : 'Packet Tunnel 启动失败，已回退模拟隧道（非生产 VPN）。详情：${humanize(e)}';
          await _fallbackStub!.connect(entry.profile, killSwitch: killSwitch);
          notifyListeners();
          return;
        } catch (_) {
          // fall through to error
        }
      }
      status = VpnUiStatus.error;
      lastError = humanize(e);
      // Do not log profile secrets.
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await tunnel.disconnect();
    } catch (e) {
      lastError = humanize(e);
      status = VpnUiStatus.error;
      notifyListeners();
      return;
    }
    activeServerId = null;
    status = VpnUiStatus.disconnected;
    notifyListeners();
  }

  Future<void> retry() async {
    final id = activeServerId;
    if (id == null) return;
    await connect(id);
  }

  ServerEntry? get activeServer {
    if (activeServerId == null) return null;
    try {
      return servers.firstWhere((e) => e.id == activeServerId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _stageSub?.cancel();
    super.dispose();
  }
}
