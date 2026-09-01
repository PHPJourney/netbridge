import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';

import '../../profile/nbvpn_profile.dart';
import 'vpn_logger.dart';

/// Manages the obfs2 local bridge process on desktop platforms.
///
/// Preferred path on Apple/Android: the in-process embedded transport
/// (gomobile AAR / xcframework via MethodChannel `netbridge/obfs2`).
/// Desktop fallback: the bundled `nbvpn obfs2 client` binary — the app
/// writes a temporary obfs2.json (PSK from the profile) under the app
/// support dir and points the WireGuard Endpoint at `127.0.0.1:<localUdp>`.
class Obfs2Bridge {
  Obfs2Bridge._();

  static final Obfs2Bridge instance = Obfs2Bridge._();

  Process? _proc;
  bool _running = false;
  bool _inProcess = false;

  bool get isRunning => _running;

  bool isSupportedPlatform() =>
      !Platform.isAndroid && !Platform.isIOS && !kIsWebSafe;

  static bool get kIsWebSafe {
    try {
      return Platform.environment.containsKey('FLUTTER_WEB');
    } catch (_) {
      return false;
    }
  }

  Future<String> _dataDir() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/obfs2';
  }

  /// Writes a minimal obfs2.json from the profile section (PSK + ports +
  /// insecure + channels). Entries are passed via --server on the CLI.
  Future<void> _writeState(NbVpnProfile profile) async {
    final obfs = profile.obfs!;
    final dir = Directory(await _dataDir());
    await dir.create(recursive: true);
    final state = <String, dynamic>{
      'v': 1,
      'enabled': true,
      'psk': obfs.psk,
      'domain': 'local',
      'clientPort': obfs.localUdp,
      'channels': obfs.channels,
      if (obfs.insecure) 'insecure': true,
    };
    final f = File('${dir.path}/obfs2.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(state));
  }

  /// Locates the nbvpn binary: PATH first, then common bundle paths.
  Future<String?> _findBinary() async {
    for (final tool in ['which', 'where']) {
      try {
        final r = await Process.run(tool, ['nbvpn']);
        final out = (r.stdout as String).trim();
        if (r.exitCode == 0 && out.isNotEmpty) {
          return out.split('\n').first.trim();
        }
      } catch (_) {
        // tool missing — try the next one
      }
    }
    // Common macOS bundle locations (packaged-binary deployments).
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '${Directory.current.path}/nbvpn',
      // Self-contained packaging: obfs2 client embedded next to the app
      // executable (Contents/MacOS/) or in Resources.
      '$exeDir/nbvpn',
      '$exeDir/../Resources/nbvpn',
      '/usr/local/bin/nbvpn',
      '/opt/homebrew/bin/nbvpn',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Ensures the bridge is running for [profile]'s obfs2 section.
  /// Returns false when obfs2 is not applicable or the bridge cannot start.
  ///
  /// Apple/Android: in-process embedded transport (gomobile bindings).
  /// Desktop fallback: spawns the `nbvpn obfs2 client` binary.
  Future<bool> ensureRunning(NbVpnProfile profile) async {
    final obfs = profile.obfs;
    if (obfs == null || !obfs.isObfs2) return false;
    if (_running) {
      // Stale flag guard: the bridge may have died without us noticing
      // (Go runtime exit / error), leaving WG pointed at a dead loopback
      // port → "connected" but no traffic. Verify the port is actually
      // bound and restart if not.
      if (await _waitBridgeReady(obfs.localUdp)) return true;
      _running = false;
      _inProcess = false;
      VpnLog.info('obfs2 bridge was stale (port dead) — restarting');
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final ok = await _ensureInProcess(obfs);
      if (ok) {
        _inProcess = true;
        _running = true;
        return true;
      }
      if (Platform.isIOS) {
        VpnLog.error(
            'obfs2 bridge: iOS embedded transport unavailable (xcframework not linked)');
        return false;
      }
    }
    // Desktop fallback (macOS when in-process is unavailable, Linux/Windows).
    final ok = await _ensureDesktop(profile, obfs);
    if (ok) {
      _inProcess = false;
      _running = true;
      return true;
    }
    VpnLog.error('obfs2 bridge: in-process and binary paths both failed');
    return false;
  }

  /// In-process embedded transport via MethodChannel (gomobile bindings).
  Future<bool> _ensureInProcess(ObfsSection obfs) async {
    try {
      const channel = MethodChannel('netbridge/obfs2');
      final ok = await channel.invokeMethod<bool>('start', {
        'serverAddrs': obfs.entries.join(','),
        'psk': obfs.psk,
        'localUdp': obfs.localUdp,
        'insecure': obfs.insecure,
        'channels': obfs.channels,
      });
      if (ok == true) {
        if (!await _waitBridgeReady(obfs.localUdp)) {
          VpnLog.error(
              'obfs2 bridge (in-process) did not bind 127.0.0.1:${obfs.localUdp}');
          return false;
        }
        VpnLog.connect(
            'obfs2 bridge (in-process) started: ${obfs.entries.length} entries, channels=${obfs.channels}');
        return true;
      }
      VpnLog.error('obfs2 bridge (in-process) start returned false');
      return false;
    } catch (e) {
      VpnLog.error('obfs2 bridge (in-process) unavailable: $e');
      return false;
    }
  }

  /// Polls until the bridge actually owns [localUdp] (EADDRINUSE). A cold
  /// bridge binds asynchronously; without this the first connect races the
  /// bind and fails ("first connect errors, second succeeds").
  Future<bool> _waitBridgeReady(int localUdp,
      {int timeoutMs = 6000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final probe =
            await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, localUdp);
        probe.close(); // port free — bridge not bound yet, retry
      } on SocketException {
        return true; // EADDRINUSE — bridge owns the port
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  /// Desktop: spawn the nbvpn CLI bridge process.
  Future<bool> _ensureDesktop(NbVpnProfile profile, ObfsSection obfs) async {
    if (!isSupportedPlatform()) {
      VpnLog.error(
          'obfs2 bridge: not supported on this platform (mobile uses embedded transport)');
      return false;
    }
    final bin = await _findBinary();
    if (bin == null) {
      VpnLog.error(
          'obfs2 bridge: nbvpn binary not found (install nbvpn to PATH)');
      return false;
    }
    try {
      await _writeState(profile);
      final dataDir = await _dataDir();
      final args = <String>[
        'obfs2',
        'client',
        '--server=${obfs.entries.join(',')}',
        '--channels=${obfs.channels}',
        if (obfs.insecure) '--insecure',
      ];
      final env = Map<String, String>.from(Platform.environment)
        ..['NBVPN_DATA_DIR'] = dataDir;
      _proc = await Process.start(bin, args, environment: env);
      VpnLog.connect('obfs2 bridge started: $bin ${args.join(' ')}');
      // Bridge listens on local UDP <localUdp>; wait until it owns the port.
      if (!await _waitBridgeReady(obfs.localUdp)) {
        VpnLog.error(
            'obfs2 bridge did not bind 127.0.0.1:${obfs.localUdp}');
        _proc = null;
        return false;
      }
      return true;
    } catch (e) {
      _proc = null;
      VpnLog.error('obfs2 bridge start failed: $e');
      return false;
    }
  }

  /// Stops the bridge (app exit / explicit teardown).
  Future<void> stop() async {
    if (_inProcess) {
      _inProcess = false;
      _running = false;
      try {
        const channel = MethodChannel('netbridge/obfs2');
        await channel.invokeMethod<void>('stop');
      } catch (_) {
        // handler missing — nothing to stop
      }
      VpnLog.info('obfs2 bridge (in-process) stopped');
      return;
    }
    final p = _proc;
    _proc = null;
    _running = false;
    if (p != null) {
      try {
        p.kill(ProcessSignal.sigterm);
        await p.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        try {
          p.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
      VpnLog.info('obfs2 bridge stopped');
    }
  }
}
