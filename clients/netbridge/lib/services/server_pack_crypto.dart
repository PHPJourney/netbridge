import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM + PBKDF2-HMAC-SHA256 passphrase encryption for server packs.
class ServerPackCrypto {
  ServerPackCrypto._();

  static const version = 1;
  static const defaultIterations = 120000;
  static const _saltLen = 16;
  static const _nonceLen = 12;

  static final _aes = AesGcm.with256bits();

  /// Encrypt [plaintext] with [passphrase]. Returns a JSON-serializable map.
  static Future<Map<String, dynamic>> encrypt({
    required List<int> plaintext,
    required String passphrase,
    int iterations = defaultIterations,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase required');
    }
    final salt = _randomBytes(_saltLen);
    final nonce = _randomBytes(_nonceLen);
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    return {
      'v': version,
      'alg': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iter': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  static Future<List<int>> decrypt({
    required Map<String, dynamic> envelope,
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase required');
    }
    final v = envelope['v'];
    if (v != version) {
      throw FormatException('unsupported crypto envelope v=$v');
    }
    final iter = envelope['iter'] is num
        ? (envelope['iter'] as num).toInt()
        : defaultIterations;
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final cipherText = base64Decode(envelope['ciphertext'] as String);
    final macBytes = base64Decode(envelope['mac'] as String);

    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    return _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
