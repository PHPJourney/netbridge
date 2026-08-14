import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_entry.dart';

/// Persists server list. No default servers.
///
/// Mobile: prefer [FlutterSecureStorage] (Keystore / Keychain).
/// Desktop (esp. sandboxed macOS): Keychain often fails without Team /
/// keychain-access-groups — always mirror to [SharedPreferences] and fall back
/// on read so the list survives Keychain errors.
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

  bool get _preferPrefsPrimary {
    if (kIsWeb) return true;
    try {
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  List<ServerEntry> _parse(String raw) {
    if (raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => ServerEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<String?> _readSecure() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
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
      if (_preferPrefsPrimary) {
        final fromPrefs = await _readPrefs();
        if (fromPrefs != null && fromPrefs.isNotEmpty) {
          return _parse(fromPrefs);
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
      }

      final fromSecure = await _readSecure();
      if (fromSecure != null && fromSecure.isNotEmpty) {
        return _parse(fromSecure);
      }
      final fromPrefs = await _readPrefs();
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        return _parse(fromPrefs);
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

  Future<void> _writeSecure(String payload) async {
    await _storage.write(key: _key, value: payload);
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
