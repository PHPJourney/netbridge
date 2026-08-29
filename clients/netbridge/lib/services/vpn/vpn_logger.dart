import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Append-only VPN diagnostic log: in-memory ring buffer + file persistence.
///
/// Feeds the Settings "诊断日志" viewer/export and the failure notification
/// copy. Never logs profile secrets — callers must redact before logging.
class VpnLog {
  VpnLog._();

  static const int _ringCapacity = 400;
  static const int _maxFileBytes = 512 * 1024; // 512 KiB, rotate at half size
  static final List<String> _ring = [];
  static File? _file;
  static bool _ready = false;
  static bool _readyFailed = false;
  static String _lastFlushError = '';

  /// Timestamp prefix, e.g. `2026-08-30 12:01:02.345`.
  static String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }

  static Future<void> init() async {
    if (_ready || _readyFailed) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/vpn.log');
      _file = f;
      // Trim if the log grew beyond budget on a previous run.
      if (await f.exists() && await f.length() > _maxFileBytes) {
        final bytes = await f.readAsBytes();
        final keep = bytes.sublist(bytes.length - (_maxFileBytes ~/ 2));
        await f.writeAsBytes(keep);
      }
      _ready = true;
    } catch (e) {
      _readyFailed = true;
      _lastFlushError = e.toString();
    }
  }

  static bool get isReady => _ready;

  static String get lastFlushError => _lastFlushError;

  /// Logs one line. `level` is a short tag like `INFO`/`CONNECT`/`STAGE`/`ERR`.
  static void log(String level, String message) {
    final line = '${_stamp()} [$level] $message';
    _ring.add(line);
    if (_ring.length > _ringCapacity) {
      _ring.removeAt(0);
    }
    final f = _file;
    if (f != null) {
      unawaited(f.writeAsString('$line\n', mode: FileMode.append).then<void>(
        (_) {},
        onError: (Object e) {
          _lastFlushError = e.toString();
        },
      ));
    }
  }

  static void info(String message) => log('INFO', message);
  static void connect(String message) => log('CONNECT', message);
  static void stage(String message) => log('STAGE', message);
  static void error(String message) => log('ERR', message);

  /// Snapshot of the in-memory ring (newest last).
  static List<String> tail([int lines = 200]) {
    if (_ring.length <= lines) return List.of(_ring);
    return List.of(_ring.sublist(_ring.length - lines));
  }

  /// Full on-disk log contents (may be empty when file IO failed).
  static Future<String> readFile() async {
    final f = _file;
    if (f == null) return '';
    try {
      return await f.readAsString();
    } catch (e) {
      _lastFlushError = e.toString();
      return '';
    }
  }

  static Future<void> clear() async {
    _ring.clear();
    final f = _file;
    if (f != null) {
      try {
        await f.writeAsString('');
      } catch (e) {
        _lastFlushError = e.toString();
      }
    }
  }
}
