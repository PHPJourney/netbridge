import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../profile/nbvpn_profile.dart';
import 'vpn_logger.dart';

/// Manages the obfs2 local bridge process on desktop platforms.
///
/// Desktop NetBridge does not embed the Go transport; instead it spawns the
/// `nbvpn obfs2 client` binary when a profile carries an obfs2 section, writes
/// a temporary obfs2.json (PSK from the profile) under the app support dir,
/// and points the WireGuard Endpoint at `127.0.0.1:<localUdp>`.
class Obfs2Bridge {
  Obfs2Bridge._();

  static final Obfs2Bridge instance = Obfs2Bridge._();

  Process? _proc;
  bool _running = false;

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
    final candidates = <String>[
      '${Directory.current.path}/nbvpn',
      '/usr/local/bin/nbvpn',
      '/opt/homebrew/bin/nbvpn',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Ensures the bridge process is running for [profile]'s obfs2 section.
  /// Returns false when obfs2 is not applicable or the bridge cannot start.
  Future<bool> ensureRunning(NbVpnProfile profile) async {
    final obfs = profile.obfs;
    if (obfs == null || !obfs.isObfs2) return false;
    if (!isSupportedPlatform()) {
      VpnLog.error(
          'obfs2 bridge: not supported on this platform (mobile uses embedded transport)');
      return false;
    }
    if (_running) return true;

    final bin = await _findBinary();
    if (bin == null) {
      VpnLog.error('obfs2 bridge: nbvpn binary not found (install nbvpn to PATH)');
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
      _running = true;
      VpnLog.connect('obfs2 bridge started: $bin ${args.join(' ')}');
      // Bridge listens on local UDP <localUdp>; give it a moment to bind.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      return true;
    } catch (e) {
      _running = false;
      _proc = null;
      VpnLog.error('obfs2 bridge start failed: $e');
      return false;
    }
  }

  /// Stops the bridge process (app exit / explicit teardown).
  Future<void> stop() async {
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
