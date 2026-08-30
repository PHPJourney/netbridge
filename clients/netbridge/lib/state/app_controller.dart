import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/build_flags.dart';
import '../models/server_entry.dart';
import '../profile/cidr_util.dart';
import '../profile/nbvpn_profile.dart';
import '../services/server_store.dart';
import '../services/settings_store.dart';
import '../services/vpn/vpn_connectivity_verifier.dart';
import '../services/vpn/vpn_errors.dart';
import '../services/vpn/vpn_logger.dart';
import '../services/vpn/vpn_notifier.dart';
import '../services/vpn/vpn_tunnel.dart';
import '../services/vpn/wireguard_vpn_tunnel.dart';

class AppController extends ChangeNotifier {
  AppController({
    ServerStore? serverStore,
    SettingsStore? settingsStore,
    VpnTunnel? tunnel,
    VpnConnectivityVerifier? connectivityVerifier,
  })  : _serverStore = serverStore ?? ServerStore(),
        _settingsStore = settingsStore ?? SettingsStore(),
        _tunnel = tunnel ?? createVpnTunnel(),
        _connectivityVerifier =
            connectivityVerifier ?? const VpnConnectivityVerifier();

  final ServerStore _serverStore;
  final SettingsStore _settingsStore;
  final VpnTunnel _tunnel;
  final VpnConnectivityVerifier _connectivityVerifier;
  final _uuid = const Uuid();

  List<ServerEntry> servers = [];
  bool loading = true;
  bool killSwitch = true;
  bool excludePrivateNetworks = BuildFlags.defaultExcludePrivateNetworks;
  bool leakProtection = BuildFlags.defaultLeakProtection;
  List<String> whitelistEntries = const [];
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
  /// Set while [connect] awaits native startVpn — stream denied is often transient.
  int? _connectInFlightEpoch;
  /// When true, ignore disconnected stage clearing of [activeServerId]
  /// (used during intentional switch / reconnect).
  bool _suppressDisconnectClear = false;
  /// Blocks plugin "connected" from promoting UI until handshake probe passes.
  int? _handshakeVerifyEpoch;

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
      await VpnLog.init();
      await VpnNotifier.init();

      servers = await _serverStore.load();
      killSwitch = await _settingsStore.getKillSwitch();
      excludePrivateNetworks = await _settingsStore.getExcludePrivateNetworks();
      leakProtection = await _settingsStore.getLeakProtection();
      whitelistEntries = await _settingsStore.getWhitelistEntries();
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

  String get _vpnPermissionDeniedMessage => languageCode == 'en'
      ? 'VPN permission was denied. Allow “NetBridge VPN” in system settings, then tap Connect again.'
      : '系统拒绝了 VPN 权限。请在系统设置中允许「网桥 VPN」，然后再次点击连接。';

  String get _verifyingHandshakeDetail => languageCode == 'en'
      ? 'Verifying handshake…'
      : '正在验证握手…';

  String get _handshakeFailedMessage => languageCode == 'en'
      ? 'Handshake failed. The provider may block UDP forwarding, or server NAT may be misconfigured.'
      : '握手失败，可能被机房封禁 UDP 或 NAT 未配置。';

  /// If the OS tunnel is still up after app restart / lost UI state, reflect it.
  Future<void> _syncFromNativeStage() async {
    try {
      final stage = await tunnel.currentStage();
      // Bootstrap snapshot: never treat plugin idle noise as reconnect.
      _applyStage(stage, clearActiveOnDisconnect: true, fromBootstrap: true);
      if (stage == VpnTunnelStage.connected &&
          activeServerId == null &&
          servers.isNotEmpty) {
        // Tunnel up but we lost which server — prompt cleanup / rebind,
        // not "reconnecting".
        status = VpnUiStatus.disconnected;
        statusDetail = languageCode == 'en'
            ? 'A system VPN tunnel is still active. Select a server and connect '
                'to bind UI, or disconnect VPN in system settings.'
            : '系统隧道仍在运行。请选择服务器连接以同步界面，或在系统设置中断开 VPN。';
        notifyListeners();
      }
    } catch (_) {
      // ignore — stage stream will update later
    }
  }

  void _onStage(VpnTunnelStage stage) {
    VpnLog.stage(stage.name);
    _applyStage(stage, clearActiveOnDisconnect: !_suppressDisconnectClear);
  }

  /// True when the UI is bound to a user-initiated tunnel session.
  bool _hasTunnelSession() =>
      activeServerId != null || _suppressDisconnectClear;

  void _applyDenied() {
    status = VpnUiStatus.error;
    lastError = _vpnPermissionDeniedMessage;
    statusDetail = null;
    activeServerId = null;
    notifyListeners();
  }

  void _applyStage(
    VpnTunnelStage stage, {
    required bool clearActiveOnDisconnect,
    bool fromBootstrap = false,
    bool trusted = false,
  }) {
    // Permission denied from the stage stream is often a transient pre-dialog
    // blip on first startVpn. Only trust it after connect() settles, or when
    // we were already connected (permission revoked mid-session).
    if (stage == VpnTunnelStage.denied) {
      if (!trusted) {
        if (!_hasTunnelSession() || _connectInFlightEpoch != null) return;
        if (status != VpnUiStatus.connected &&
            status != VpnUiStatus.reconnecting) {
          return;
        }
      }
      _applyDenied();
      return;
    }

    final hasSession = _hasTunnelSession();

    // No user session (empty list / never connected / after disconnect):
    // ignore reconnect / waiting / noConnection plugin noise.
    if (!hasSession) {
      switch (stage) {
        case VpnTunnelStage.connected:
          status = VpnUiStatus.disconnected;
          statusDetail = languageCode == 'en'
              ? 'A system VPN tunnel is still active but no server is bound. '
                  'Disconnect VPN in system settings, or add a server and connect.'
              : '检测到系统 VPN 仍在运行，但本地未绑定服务器。请在系统设置中断开 VPN，或添加服务器后连接。';
        case VpnTunnelStage.reconnecting:
        case VpnTunnelStage.noConnection:
        case VpnTunnelStage.connecting:
        case VpnTunnelStage.preparing:
        case VpnTunnelStage.disconnected:
        case VpnTunnelStage.disconnecting:
          status = VpnUiStatus.disconnected;
          statusDetail = null;
        case VpnTunnelStage.error:
          // Bootstrap/plugin error without a session is not actionable reconnect.
          if (fromBootstrap) {
            status = VpnUiStatus.disconnected;
            statusDetail = null;
          } else {
            status = VpnUiStatus.error;
            lastError ??= languageCode == 'en'
                ? 'Tunnel error. Retry or check that the node is reachable.'
                : '隧道错误，请重试或检查节点是否可达。';
          }
        case VpnTunnelStage.denied:
          break; // handled above
      }
      if (clearActiveOnDisconnect &&
          (stage == VpnTunnelStage.disconnected ||
              stage == VpnTunnelStage.disconnecting)) {
        activeServerId = null;
      }
      notifyListeners();
      return;
    }

    // During intentional teardown/switch, ignore late reconnect noise.
    if (_suppressDisconnectClear &&
        (stage == VpnTunnelStage.reconnecting ||
            stage == VpnTunnelStage.noConnection ||
            stage == VpnTunnelStage.connected)) {
      return;
    }

    switch (stage) {
      case VpnTunnelStage.disconnected:
      case VpnTunnelStage.disconnecting:
        status = VpnUiStatus.disconnected;
        statusDetail = null;
        if (clearActiveOnDisconnect) {
          activeServerId = null;
        }
      case VpnTunnelStage.preparing:
      case VpnTunnelStage.connecting:
        status = VpnUiStatus.connecting;
      case VpnTunnelStage.connected:
        if (_handshakeVerifyEpoch != null) {
          status = VpnUiStatus.connecting;
          statusDetail = _verifyingHandshakeDetail;
        } else {
          status = VpnUiStatus.connected;
          statusDetail = null;
        }
      case VpnTunnelStage.reconnecting:
      case VpnTunnelStage.noConnection:
        // Only show reconnect when we already had a live tunnel session.
        // During first connect, waitingConnection/noConnection is plugin noise.
        if (status == VpnUiStatus.connected ||
            status == VpnUiStatus.reconnecting) {
          status = VpnUiStatus.reconnecting;
        } else {
          status = VpnUiStatus.connecting;
        }
      case VpnTunnelStage.error:
        status = VpnUiStatus.error;
        lastError ??= languageCode == 'en'
            ? 'Tunnel error. Retry or check that the node is reachable.'
            : '隧道错误，请重试或检查节点是否可达。';
        activeServerId = null;
      case VpnTunnelStage.denied:
        break; // handled above
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

  Future<void> setExcludePrivateNetworks(bool value) async {
    excludePrivateNetworks = value;
    await _settingsStore.setExcludePrivateNetworks(value);
    notifyListeners();
  }

  Future<void> setLeakProtection(bool value) async {
    leakProtection = value;
    await _settingsStore.setLeakProtection(value);
    // Leak mode forces full tunnel on connect; keep KS preference aligned.
    if (value && !killSwitch) {
      killSwitch = true;
      await _settingsStore.setKillSwitch(true);
    }
    notifyListeners();
  }

  Future<void> setWhitelistEntries(List<String> entries) async {
    whitelistEntries = List<String>.from(entries);
    await _settingsStore.setWhitelistEntries(whitelistEntries);
    notifyListeners();
  }

  /// IPv4 CIDRs from whitelist that are applied to AllowedIPs on connect.
  List<String> get whitelistCidrs => whitelistEntries
      .map((e) => e.trim())
      .where(looksLikeIpv4Cidr)
      .toList();

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
          VpnLog.error('connect blocked: stub tunnel ($stubVpnBlockedMessage)');
          VpnNotifier.failed(stubVpnBlockedMessage);
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

        _connectInFlightEpoch = epoch;
        _handshakeVerifyEpoch = epoch;
        try {
          await tunnel.connect(
            entry.profile,
            killSwitch: leakProtection ? true : killSwitch,
            excludePrivateNetworks: excludePrivateNetworks,
            forceFullTunnel: leakProtection,
            bypassCidrs: whitelistCidrs,
          );
          if (epoch != _tunnelEpoch) return;
          // Prefer live stage over assuming connect() completion == connected.
          var stage = await tunnel.currentStage();
          if (epoch != _tunnelEpoch) return;
          if (stage == VpnTunnelStage.denied) {
            _applyStage(stage, clearActiveOnDisconnect: true, trusted: true);
            return;
          }
          if (stage != VpnTunnelStage.connected) {
            _applyStage(stage, clearActiveOnDisconnect: true, trusted: true);
            return;
          }

          // Plugin "connected" only means interface up — verify handshake/egress.
          status = VpnUiStatus.connecting;
          statusDetail = _verifyingHandshakeDetail;
          notifyListeners();

          final allowedIPs = VpnConnectivityVerifier.effectiveAllowedIPs(
            entry.profile.server.allowedIPs,
            excludePrivateNetworks: excludePrivateNetworks,
            forceFullTunnel: leakProtection,
            bypassCidrs: whitelistCidrs,
          );
          // obfs2: the WG peer is the local bridge, so UDP reachability
          // probes must target 127.0.0.1:<localUdp>, not the public endpoint.
          final verifyEndpoint =
              (entry.profile.obfs?.isObfs2 ?? false)
                  ? '127.0.0.1:${entry.profile.obfs!.localUdp}'
                  : entry.profile.server.activeEndpoint;
          final verifyResult = await _connectivityVerifier.verify(
            allowedIPs: allowedIPs,
            endpoint: verifyEndpoint,
            isCancelled: () => epoch != _tunnelEpoch,
          );

          if (epoch != _tunnelEpoch) return;
          _handshakeVerifyEpoch = null;

          if (verifyResult == VpnVerificationResult.cancelled) return;

          if (verifyResult != VpnVerificationResult.success) {
            final handshakeError = _handshakeFailedMessage;
            VpnLog.error('handshake verify failed: $handshakeError');
            VpnNotifier.failed(handshakeError);
            try {
              await _disconnectAndWait(epoch: epoch);
            } catch (_) {
              // error already surfaced
            }
            if (epoch != _tunnelEpoch) return;
            status = VpnUiStatus.error;
            lastError = handshakeError;
            statusDetail = null;
            activeServerId = null;
            notifyListeners();
            return;
          }

          stage = await tunnel.currentStage();
          if (epoch != _tunnelEpoch) return;
          if (stage == VpnTunnelStage.denied) {
            _applyStage(stage, clearActiveOnDisconnect: true, trusted: true);
            return;
          }
          activeServerId = serverId;
          status = VpnUiStatus.connected;
          statusDetail = null;
          notifyListeners();
          VpnLog.connect('connected to ${entry.profile.server.activeEndpoint} (id=$serverId)');
          VpnNotifier.connected(entry.profile.server.activeEndpoint);
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
            VpnLog.error('connect failed: $lastError');
            VpnNotifier.failed(lastError ?? 'connection failed');
            return;
          }
          status = VpnUiStatus.error;
          lastError = humanize(e);
          activeServerId = null;
          notifyListeners();
          VpnLog.error('connect failed: $lastError');
          VpnNotifier.failed(lastError ?? 'connection failed');
        } finally {
          if (_handshakeVerifyEpoch == epoch) {
            _handshakeVerifyEpoch = null;
          }
          if (_connectInFlightEpoch == epoch) {
            _connectInFlightEpoch = null;
          }
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
