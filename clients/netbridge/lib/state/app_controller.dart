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

  /// Serializes connect / disconnect / switch so stage events cannot race.
  Future<void> _tunnelChain = Future<void>.value();
  int _tunnelEpoch = 0;
  /// When true, ignore disconnected stage clearing of [activeServerId]
  /// (used during intentional switch / reconnect).
  bool _suppressDisconnectClear = false;

  static const Duration _disconnectWaitTimeout = Duration(seconds: 8);

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
        await _syncFromNativeStage();
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

  /// If the OS tunnel is still up after app restart / lost UI state, reflect it.
  Future<void> _syncFromNativeStage() async {
    try {
      final stage = await tunnel.currentStage();
      _applyStage(stage, clearActiveOnDisconnect: true);
      if (stage == VpnTunnelStage.connected &&
          activeServerId == null &&
          servers.isNotEmpty) {
        // Tunnel up but we lost which server — keep connected UI generic;
        // user can reconnect a specific entry to re-bind id.
        status = VpnUiStatus.connected;
        statusDetail = languageCode == 'en'
            ? 'System tunnel is up; select a server and reconnect to bind UI.'
            : '系统隧道仍在运行；请选择服务器重新连接以同步界面状态。';
      }
    } catch (_) {
      // ignore — stage stream will update later
    }
  }

  void _onStage(VpnTunnelStage stage) {
    _applyStage(stage, clearActiveOnDisconnect: !_suppressDisconnectClear);
  }

  void _applyStage(
    VpnTunnelStage stage, {
    required bool clearActiveOnDisconnect,
  }) {
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
      if (clearActiveOnDisconnect && status == VpnUiStatus.disconnected) {
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
    // Update UI immediately — never wait on Keychain/prefs (macOS sandbox
    // Keychain often fails; a thrown persist used to skip notifyListeners).
    servers = [...servers, entry];
    notifyListeners();
    try {
      await persist();
    } catch (e) {
      lastError = languageCode == 'en'
          ? 'Server saved in memory but disk persist failed: $e'
          : '服务器已加入列表，但写入本地存储失败：$e';
      notifyListeners();
    }
    return entry;
  }

  Future<void> renameServer(String id, String localName) async {
    final i = servers.indexWhere((e) => e.id == id);
    if (i < 0) return;
    servers[i].localName = localName.trim();
    servers[i].updatedAt = DateTime.now().toUtc();
    notifyListeners();
    try {
      await persist();
    } catch (e) {
      lastError = languageCode == 'en'
          ? 'Rename kept in memory but persist failed: $e'
          : '已重命名，但写入本地存储失败：$e';
      notifyListeners();
    }
  }

  /// Replace local name and/or profile fields for an existing entry.
  Future<void> updateServer(
    String id, {
    String? localName,
    NbVpnProfile? profile,
  }) async {
    final i = servers.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final old = servers[i];
    final nextName = (localName ?? old.localName).trim();
    servers = [
      for (var j = 0; j < servers.length; j++)
        if (j == i)
          ServerEntry(
            id: old.id,
            localName: nextName.isEmpty ? old.localName : nextName,
            profile: profile ?? old.profile,
            createdAt: old.createdAt,
            updatedAt: DateTime.now().toUtc(),
          )
        else
          servers[j],
    ];
    notifyListeners();
    try {
      await persist();
    } catch (e) {
      lastError = languageCode == 'en'
          ? 'Edit kept in memory but persist failed: $e'
          : '已保存编辑，但写入本地存储失败：$e';
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    if (activeServerId == id && status != VpnUiStatus.disconnected) {
      await disconnect();
    }
    if (activeServerId == id) {
      activeServerId = null;
    }
    servers = servers.where((e) => e.id != id).toList();
    notifyListeners();
    try {
      await persist();
    } catch (e) {
      lastError = languageCode == 'en'
          ? 'Removed from list but persist failed: $e'
          : '已从列表移除，但写入本地存储失败：$e';
      notifyListeners();
    }
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

  String get stubVpnBlockedMessage => languageCode == 'en'
      ? 'This build has no signed Network Extension, so macOS/iOS will not show a system VPN permission dialog and cannot create a real tunnel. Use the official WireGuard app with the .conf from `nbvpn`, or sign + embed WGExtension (Apple Developer Team) — see Settings / IMPL.md.'
      : '当前构建未嵌入已签名的 Network Extension：macOS/iOS 不会弹出系统 VPN 权限，也无法建立真实隧道。请用官方 WireGuard 客户端导入 nbvpn 导出的 .conf；若需应用内真连，需 Apple Developer Team 签名并链接 WGExtension（见设置页 / IMPL.md）。';

  Future<T> _enqueueTunnelOp<T>(Future<T> Function() op) {
    final run = _tunnelChain.then((_) => op());
    _tunnelChain = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _waitUntilDisconnected({
    required Duration timeout,
  }) async {
    final current = await tunnel.currentStage();
    if (current == VpnTunnelStage.disconnected) return;

    final done = Completer<void>();
    late StreamSubscription<VpnTunnelStage> sub;
    Timer? timer;

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    sub = tunnel.stageStream.listen((s) {
      if (s == VpnTunnelStage.disconnected) finish();
    });
    timer = Timer(timeout, finish);

    try {
      // Re-check in case we raced the emission.
      final again = await tunnel.currentStage();
      if (again == VpnTunnelStage.disconnected) {
        finish();
      }
      await done.future;
    } finally {
      await sub.cancel();
      timer.cancel();
    }
  }

  /// Stop tunnel and wait until stage is disconnected (with timeout).
  Future<void> _disconnectAndWait({required int epoch}) async {
    _suppressDisconnectClear = true;
    try {
      try {
        await tunnel.disconnect();
      } catch (e) {
        lastError = humanize(e);
        status = VpnUiStatus.error;
        notifyListeners();
        rethrow;
      }
      await _waitUntilDisconnected(timeout: _disconnectWaitTimeout);
      if (epoch != _tunnelEpoch) return;
      activeServerId = null;
      status = VpnUiStatus.disconnected;
      statusDetail = null;
      notifyListeners();
    } finally {
      _suppressDisconnectClear = false;
    }
  }

  Future<void> connect(String serverId) => _enqueueTunnelOp(() async {
        ServerEntry? entry;
        for (final e in servers) {
          if (e.id == serverId) {
            entry = e;
            break;
          }
        }
        if (entry == null) return;

        lastError = null;
        statusDetail = null;

        // Stub ≠ VPN: never fake “connected” or imply a permission prompt.
        if (!supportsRealTunnel) {
          activeServerId = null;
          status = VpnUiStatus.error;
          lastError = stubVpnBlockedMessage;
          notifyListeners();
          return;
        }

        final epoch = ++_tunnelEpoch;

        // Serial switch: always tear down existing tunnel before connect.
        final needsTeardown = status != VpnUiStatus.disconnected ||
            activeServerId != null;
        if (needsTeardown) {
          final switching = activeServerId != null && activeServerId != serverId;
          if (switching) {
            status = VpnUiStatus.connecting;
            statusDetail = languageCode == 'en'
                ? 'Switching server…'
                : '正在切换服务器…';
            notifyListeners();
          }
          try {
            await _disconnectAndWait(epoch: epoch);
          } catch (_) {
            if (epoch != _tunnelEpoch) return;
            // Continue attempt only if OS still reports disconnected.
            final stage = await tunnel.currentStage();
            if (stage != VpnTunnelStage.disconnected) {
              return;
            }
          }
          if (epoch != _tunnelEpoch) return;
        }

        activeServerId = serverId;
        status = VpnUiStatus.connecting;
        statusDetail = null;
        notifyListeners();

        try {
          await tunnel.connect(entry.profile, killSwitch: killSwitch);
          if (epoch != _tunnelEpoch) return;
          // Prefer live stage over assuming connect() completion == connected.
          final stage = await tunnel.currentStage();
          if (epoch != _tunnelEpoch) return;
          _applyStage(stage, clearActiveOnDisconnect: true);
          if (stage == VpnTunnelStage.connected) {
            activeServerId = serverId;
            notifyListeners();
          }
        } catch (e) {
          if (epoch != _tunnelEpoch) return;
          // Apple: do not silently fall back to Stub “connected”.
          if (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) {
            status = VpnUiStatus.error;
            lastError =
                '$stubVpnBlockedMessage ${languageCode == 'en' ? 'Detail' : '详情'}: ${humanize(e)}';
            activeServerId = null;
            notifyListeners();
            return;
          }
          status = VpnUiStatus.error;
          lastError = humanize(e);
          activeServerId = null;
          notifyListeners();
        }
      });

  Future<void> disconnect() => _enqueueTunnelOp(() async {
        final epoch = ++_tunnelEpoch;
        try {
          await _disconnectAndWait(epoch: epoch);
        } catch (_) {
          // error already surfaced
        }
      });

  Future<void> retry() async {
    final id = activeServerId;
    if (id == null) return;
    await connect(id);
  }

  /// Re-read native VPN stage (e.g. after UI desync while OS tunnel stays up).
  Future<void> refreshTunnelStage() => _enqueueTunnelOp(() async {
        await _syncFromNativeStage();
        notifyListeners();
      });

  ServerEntry? get activeServer {
    if (activeServerId == null) return null;
    try {
      return servers.firstWhere((e) => e.id == activeServerId);
    } catch (_) {
      return null;
    }
  }

  /// True only when this list row is the tunnel-bound server and connected.
  bool isServerConnected(String serverId) =>
      activeServerId == serverId && status == VpnUiStatus.connected;

  @override
  void dispose() {
    _stageSub?.cancel();
    super.dispose();
  }
}
