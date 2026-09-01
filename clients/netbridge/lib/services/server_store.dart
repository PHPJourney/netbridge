import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_entry.dart';

/// Persists server list. No default servers.
///
/// Mirrored into two stores (Keychain via [FlutterSecureStorage] and
/// [SharedPreferences]); on load the fresher copy wins and is mirrored back,
/// so a deleted entry can never resurrect from a stale store.
class ServerStore {
  ServerStore({
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _prefsOverride = prefs;

  static const _key = 'nbvpn.servers.v1';

  final FlutterSecureStorage _storage;
  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? SharedPreferences.getInstance();

  List<ServerEntry> _parse(String raw) {
    if (raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => ServerEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Desktop/web: the app is non-sandboxed and SharedPreferences persists
  /// fine — the OS keychain is unnecessary and flutter_secure_storage's macOS
  /// plugin throws ENTITLEMENT_NOT_FOUND for non-sandboxed apps. Mobile keeps
  /// the keychain (Keystore / Keychain) as the primary store.
  bool get _useKeychain {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<String?> _readSecure() async {
    if (!_useKeychain) return null;
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecure(String payload) async {
    if (!_useKeychain) return;
    try {
      await _storage.write(key: _key, value: payload);
    } catch (_) {
      // Keychain unavailable — prefs mirror stays authoritative.
    }
  }

  Future<String?> _readPrefs() async {
    try {
      return (await _prefs()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<List<ServerEntry>> load() async {
    try {
      // Prefs is authoritative (desktop + web); Keychain is a mirror.
      // Never compare the two lists — a stale Keychain copy with a newer
      // timestamp must not shadow prefs (deleted entries would resurrect).
      final fromPrefs = await _readPrefs();
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        final list = _parse(fromPrefs);
        // Heal the mirror so a stale Keychain copy can never win later.
        try {
          await _writeSecure(fromPrefs);
        } catch (_) {
          // Keychain unavailable — prefs stays authoritative.
        }
        return list;
      }

      final fromSecure = await _readSecure();
      if (fromSecure != null && fromSecure.isNotEmpty) {
        final list = _parse(fromSecure);
        // Migrate Keychain → prefs so next launch is reliable.
        if (list.isNotEmpty) {
          await _writePrefs(fromSecure);
        }
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePrefs(String payload) async {
    final prefs = await _prefs();
    await prefs.setString(_key, payload);
  }

  Future<void> save(List<ServerEntry> entries) async {
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    // Empty list must be an explicit `[]` so a deleted profile can be
    // re-imported after process death (no stale credential fingerprint).
    final normalized = entries.isEmpty ? '[]' : payload;

    Object? secureError;
    try {
      await _writeSecure(normalized);
    } catch (e) {
      secureError = e;
    }

    try {
      await _writePrefs(normalized);
    } catch (e) {
      // Both backends failed — surface so caller can show an error.
      if (secureError != null) {
        throw StateError('server list persist failed: $secureError; prefs: $e');
      }
      rethrow;
    }

    // Desktop: prefs is enough. Mobile: if Keychain failed, prefs is backup
    // but still warn via debug (UI already has the in-memory list).
    if (secureError != null && kDebugMode) {
      debugPrint('ServerStore: secure write failed, used prefs: $secureError');
    }
  }
}
