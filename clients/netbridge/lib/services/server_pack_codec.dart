import 'dart:convert';
import 'dart:io';

import '../models/server_entry.dart';
import '../profile/nbvpn_profile.dart';
import '../profile/profile_codec.dart';
import 'server_pack_crypto.dart';

/// Portable multi-server export / sync payload (clear or passphrase-encrypted).
class ServerPackCodec {
  ServerPackCodec._();

  static const packType = 'nbvpn.server_pack';
  static const encPrefix = 'nbvpn-enc:1?';

  /// Cleartext pack map (not yet encrypted).
  static Map<String, dynamic> buildPack(List<ServerEntry> entries) {
    return {
      'v': 1,
      'type': packType,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'servers': entries
          .map(
            (e) => {
              'localName': e.localName,
              'profile': e.profile.toJson(),
            },
          )
          .toList(),
    };
  }

  static String encodeClearJson(List<ServerEntry> entries, {bool pretty = true}) {
    final map = buildPack(entries);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  /// Single-profile `.nbvpn.json` (legacy / one file per peer).
  static String encodeSingleProfileJson(NbVpnProfile profile, {bool pretty = true}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(profile.toJson())
        : jsonEncode(profile.toJson());
  }

  /// Encrypt pack. [compact] gzips plaintext and uses QR-friendly PBKDF iters.
  static Future<Map<String, dynamic>> encryptPack(
    List<ServerEntry> entries,
    String passphrase, {
    bool compact = false,
  }) async {
    final plainJson = utf8.encode(jsonEncode(buildPack(entries)));
    List<int> plaintext = plainJson;
    String? comp;
    if (compact) {
      plaintext = gzip.encode(plainJson);
      comp = 'gzip';
    }
    final env = await ServerPackCrypto.encrypt(
      plaintext: plaintext,
      passphrase: passphrase,
      // Slightly fewer iters for QR size/time; still strong enough for sync.
      iterations: compact ? 60000 : ServerPackCrypto.defaultIterations,
    );
    if (comp != null) {
      env['comp'] = comp;
    }
    return env;
  }

  /// Encrypted URI for QR / paste. Uses gzip + compact envelope for scannability.
  static Future<String> encryptPackUri(
    List<ServerEntry> entries,
    String passphrase,
  ) async {
    final env = await encryptPack(entries, passphrase, compact: true);
    final raw = utf8.encode(jsonEncode(env));
    final payload = base64Url.encode(raw).replaceAll('=', '');
    return '$encPrefix$payload';
  }

  static bool looksLikeEncryptedUri(String raw) {
    final s = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return s.startsWith('nbvpn-enc:1?');
  }

  static bool looksLikeEncryptedJson(String raw) {
    try {
      final m = jsonDecode(raw.trim());
      return m is Map &&
          m['alg'] == 'AES-256-GCM' &&
          m['ciphertext'] != null &&
          m['salt'] != null;
    } catch (_) {
      return false;
    }
  }

  static Future<List<({String localName, NbVpnProfile profile})>> decryptPackUri(
    String uri,
    String passphrase,
  ) async {
    final trimmed = uri.trim().replaceAll(RegExp(r'\s+'), '');
    if (!trimmed.toLowerCase().startsWith('nbvpn-enc:1?')) {
      throw FormatException('not an nbvpn-enc URI');
    }
    final payload = trimmed.substring('nbvpn-enc:1?'.length);
    final raw = _decodeBase64Url(payload);
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map) throw FormatException('bad envelope');
    return decryptEnvelope(decoded.cast<String, dynamic>(), passphrase);
  }

  static Future<List<({String localName, NbVpnProfile profile})>> decryptEnvelope(
    Map<String, dynamic> envelope,
    String passphrase,
  ) async {
    var plain = await ServerPackCrypto.decrypt(
      envelope: envelope,
      passphrase: passphrase,
    );
    final comp = envelope['comp']?.toString();
    if (comp == 'gzip') {
      plain = gzip.decode(plain);
    }
    return parseClearPackBytes(plain);
  }

  static List<({String localName, NbVpnProfile profile})> parseClearPackBytes(
    List<int> bytes,
  ) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map && decoded['type'] == packType) {
      final list = decoded['servers'];
      if (list is! List) throw FormatException('servers missing');
      return list.whereType<Map>().map((e) {
        final map = e.cast<String, dynamic>();
        final profile = NbVpnProfile.fromJson(
          (map['profile'] as Map).cast<String, dynamic>(),
        );
        ProfileCodec.validate(profile);
        final name = map['localName']?.toString() ?? profile.name;
        return (localName: name, profile: profile);
      }).toList();
    }
    // Single profile object
    if (decoded is Map) {
      // Encrypted envelope mistaken for clear — reject early
      if (decoded['alg'] == 'AES-256-GCM' && decoded['ciphertext'] != null) {
        throw FormatException('encrypted envelope requires passphrase');
      }
      final profile =
          NbVpnProfile.fromJson(decoded.cast<String, dynamic>());
      ProfileCodec.validate(profile);
      return [(localName: profile.name, profile: profile)];
    }
    // Array of profiles or {localName, profile}
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) {
        final map = e.cast<String, dynamic>();
        if (map.containsKey('profile')) {
          final profile = NbVpnProfile.fromJson(
            (map['profile'] as Map).cast<String, dynamic>(),
          );
          ProfileCodec.validate(profile);
          return (
            localName: map['localName']?.toString() ?? profile.name,
            profile: profile,
          );
        }
        final profile = NbVpnProfile.fromJson(map);
        ProfileCodec.validate(profile);
        return (localName: profile.name, profile: profile);
      }).toList();
    }
    throw FormatException('unrecognized pack');
  }

  static String wireGuardBundle(List<ServerEntry> entries) {
    final buf = StringBuffer();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (i > 0) buf.writeln();
      buf.writeln('# ${e.localName}');
      buf.write(ProfileCodec.toWireGuardConf(e.profile));
    }
    return buf.toString();
  }

  static List<int> _decodeBase64Url(String payload) {
    var s = payload.replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - s.length % 4) % 4;
    s = s.padRight(s.length + pad, '=');
    return base64.decode(s);
  }
}
