import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/server_entry.dart';

/// Persists server list in secure storage. No default servers.
class ServerStore {
  ServerStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'nbvpn.servers.v1';

  final FlutterSecureStorage _storage;

  Future<List<ServerEntry>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ServerEntry.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ServerEntry> entries) async {
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: payload);
    // Empty list must clear the key payload so a deleted profile can be
    // re-imported after process death (no stale credential fingerprint).
    if (entries.isEmpty) {
      await _storage.write(key: _key, value: '[]');
    }
  }
}
