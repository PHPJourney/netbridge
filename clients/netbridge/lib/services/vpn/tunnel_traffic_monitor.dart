import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One sample of tunnel byte counters.
class TunnelTrafficSample {
  const TunnelTrafficSample({
    required this.rxBytes,
    required this.txBytes,
    required this.at,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime at;

  String get rxHuman => _human(rxBytes);
  String get txHuman => _human(txBytes);

  static String _human(int v) {
    if (v >= 1024 * 1024 * 1024) return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    if (v >= 1024 * 1024) return '${(v / (1024 * 1024)).toStringAsFixed(1)}MB';
    if (v >= 1024) return '${(v / 1024).toStringAsFixed(0)}KB';
    return '${v}B';
  }
}

/// Polls the WireGuard tunnel interface counters and emits a human-readable
/// status line (speed + totals) for the tray tooltip/menu.
///
/// macOS/Linux: `netstat -ib` on the utun interface.
/// Windows: not supported (returns no data — tray shows connection only).
class TunnelTrafficMonitor {
  TunnelTrafficMonitor({this.interval = const Duration(seconds: 1)});

  final Duration interval;

  Timer? _timer;
  String? _ifName;
  bool _running = false;
  TunnelTrafficSample? _prev;

  /// Fired with e.g. `↑1.1 MB/s  ↓3.2 MB/s · 上 40.9MB 下 190.9MB`.
  final ValueNotifier<String> status = ValueNotifier('');

  bool get isRunning => _running;

  /// Locate the utun interface carrying [tunnelAddress] (e.g. 10.8.0.2).
  Future<String?> _findInterface(String tunnelAddress) async {
    if (Platform.isWindows) return null;
    try {
      final p = await Process.run('ifconfig', const ['-a']);
      if (p.exitCode != 0) return null;
      final lines = (p.stdout as String).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('inet $tunnelAddress')) {
          for (var j = i; j >= 0; j--) {
            final m = RegExp(r'^(utun\d+)').firstMatch(lines[j].trim());
            if (m != null) return m.group(1);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<TunnelTrafficSample?> _readCounters(String ifName) async {
    try {
      final p = await Process.run('netstat', ['-ib', '-I', ifName]);
      if (p.exitCode != 0) return null;
      final lines = (p.stdout as String).split('\n');
      // header row: find Ibytes / Obytes column offsets
      int? rxIdx, txIdx, addrIdx;
      for (final line in lines) {
        final hdr = line.trim().split(RegExp(r'\s+'));
        if (hdr.isNotEmpty && hdr.first == 'Name') {
          addrIdx = hdr.indexOf('Address');
          rxIdx = hdr.indexOf('Ibytes');
          txIdx = hdr.indexOf('Obytes');
          break;
        }
      }
      if (rxIdx == null || txIdx == null) return null;
      for (final line in lines) {
        final cols = line.trim().split(RegExp(r'\s+'));
        if (cols.length > (addrIdx ?? 0) && cols.length > txIdx &&
            cols.length > rxIdx &&
            (cols[addrIdx ?? 0] == ifName ||
                cols[addrIdx ?? 0] == '10.8.0.2')) {
          final rx = int.tryParse(cols[rxIdx]);
          final tx = int.tryParse(cols[txIdx]);
          if (rx != null && tx != null) {
            return TunnelTrafficSample(
                rxBytes: rx, txBytes: tx, at: DateTime.now());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Start polling. [tunnelAddress] identifies the utun interface.
  Future<void> start(String tunnelAddress) async {
    await stop();
    if (Platform.isWindows) return;
    _ifName = await _findInterface(tunnelAddress);
    _running = true;
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    final name = _ifName;
    if (name == null) {
      _ifName = await _findInterface('10.8.0.2');
      if (_ifName == null) return;
    }
    final sample = await _readCounters(_ifName!);
    if (sample == null) return;
    final prev = _prev;
    _prev = sample;
    if (prev == null) return;
    final dt = sample.at.difference(prev.at).inMilliseconds.clamp(1, 10000);
    final rxSpeed = (sample.rxBytes - prev.rxBytes).clamp(0, 1 << 62) * 1000 / dt;
    final txSpeed = (sample.txBytes - prev.txBytes).clamp(0, 1 << 62) * 1000 / dt;
    status.value =
        '↑${_speedHuman(txSpeed)}  ↓${_speedHuman(rxSpeed)} · 上 ${sample.txHuman} 下 ${sample.rxHuman}';
  }

  static String _speedHuman(double bps) {
    if (bps >= 1024 * 1024) return '${(bps / (1024 * 1024)).toStringAsFixed(1)}MB/s';
    if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(0)}KB/s';
    return '${bps.toStringAsFixed(0)}B/s';
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _prev = null;
    status.value = '';
  }

  void dispose() {
    _timer?.cancel();
    _prev = null;
    status.dispose();
  }
}
