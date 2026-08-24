import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../profile/nbvpn_profile.dart';
import '../profile/profile_codec.dart';
import '../profile/profile_errors.dart';
import 'server_pack_codec.dart';

typedef ImportedServer = ({String localName, NbVpnProfile profile});

/// Unified import pipeline for paste / scan / file / NFC / Bluetooth.
class ProfileImportService {
  ProfileImportService._();

  static bool looksEncrypted(String raw) {
    final t = raw.trim();
    return ServerPackCodec.looksLikeEncryptedUri(t) ||
        ServerPackCodec.looksLikeEncryptedJson(t);
  }

  /// Prefer `nbvpn-enc:` / `nbvpn:` payloads from a multi-candidate scan.
  static String preferVpnPayload(String candidate) {
    final cleaned = ProfileCodec.sanitizeUriInput(candidate);
    final lower = cleaned.toLowerCase();
    if (lower.startsWith('nbvpn-enc:') || lower.startsWith('nbvpn:')) {
      return cleaned;
    }
    return candidate.trim();
  }

  /// Best payload from QR scan candidates.
  static String bestFromScan(Iterable<String?> candidates) {
    String best = '';
    String bestVpn = '';
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final preferred = preferVpnPayload(candidate);
      final lower = preferred.toLowerCase();
      if (lower.startsWith('nbvpn-enc:') || lower.startsWith('nbvpn:')) {
        if (preferred.length > bestVpn.length) bestVpn = preferred;
      }
      if (candidate.length > best.length) best = candidate;
    }
    return bestVpn.isNotEmpty ? bestVpn : best;
  }

  static String errorMessage(Object e, String languageCode) {
    if (e is ImportException) return e.messageForLanguage(languageCode);
    if (e is ProfileException) return e.messageForLanguage(languageCode);
    final en = languageCode.toLowerCase().startsWith('en');
    return en ? 'Import failed: $e' : '导入失败：$e';
  }

  /// Ask for passphrase; returns null if cancelled or empty.
  static Future<String?> askPassphrase(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importPassphraseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.importPassphraseBody),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.passphrase,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    final text = field.text;
    field.dispose();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  /// Decrypt with explicit passphrase (no dialog).
  static Future<List<ImportedServer>> decryptWithPassphrase(
    String raw,
    String passphrase,
  ) async {
    try {
      if (ServerPackCodec.looksLikeEncryptedUri(raw)) {
        return await ServerPackCodec.decryptPackUri(raw, passphrase);
      }
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) throw const FormatException('bad envelope');
      return await ServerPackCodec.decryptEnvelope(
        decoded.cast<String, dynamic>(),
        passphrase,
      );
    } on SecretBoxAuthenticationError {
      throw ImportException.badPassphrase();
    } on ArgumentError {
      throw ImportException.badPassphrase();
    } catch (e) {
      if (e is ImportException || e is ProfileException) rethrow;
      final msg = '$e'.toLowerCase();
      if (msg.contains('mac') ||
          msg.contains('authentication') ||
          msg.contains('secretbox')) {
        throw ImportException.badPassphrase();
      }
      throw ImportException.decryptFailed('$e');
    }
  }

  /// Parse clear or encrypted text. Shows passphrase dialog when needed.
  /// Returns null if user cancels passphrase prompt.
  static Future<List<ImportedServer>?> parseText(
    BuildContext context,
    String raw,
  ) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ProfileException(
        ProfileErrorCode.uriDecode,
        detail: '内容为空',
      );
    }

    if (looksEncrypted(trimmed)) {
      final pass = await askPassphrase(context);
      if (pass == null) return null;
      return decryptWithPassphrase(trimmed, pass);
    }

    return parseClearText(trimmed);
  }

  /// Parse plaintext URI / JSON / pack (no passphrase).
  static List<ImportedServer> parseClearText(String raw) {
    final trimmed = raw.trim();
    try {
      final look = ProfileCodec.sanitizeUriInput(trimmed);
      final lower = look.toLowerCase();
      if (lower.startsWith('nbvpn:') && !lower.startsWith('nbvpn-enc:')) {
        final profile = ProfileCodec.decodeUri(look);
        return [(localName: profile.name, profile: profile)];
      }
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return ServerPackCodec.parseClearPackBytes(utf8.encode(trimmed));
      }
      try {
        return ServerPackCodec.parseClearPackBytes(utf8.encode(trimmed));
      } catch (_) {
        final profile = ProfileCodec.parseFlexibleImport(trimmed);
        return [(localName: profile.name, profile: profile)];
      }
    } on ProfileException {
      rethrow;
    } catch (e) {
      throw ProfileException(
        ProfileErrorCode.uriDecode,
        detail: '$e',
      );
    }
  }

  static Future<List<ImportedServer>?> parseBytes(
    BuildContext context,
    List<int> bytes,
  ) {
    return parseText(context, utf8.decode(bytes));
  }
}

/// Back-compat alias.
typedef ServerImport = ProfileImportService;

/// Import-specific errors with localized messages.
class ImportException implements Exception {
  ImportException(this.code, {this.detail});

  final ImportErrorCode code;
  final String? detail;

  factory ImportException.badPassphrase() =>
      ImportException(ImportErrorCode.badPassphrase);

  factory ImportException.decryptFailed([String? detail]) =>
      ImportException(ImportErrorCode.decryptFailed, detail: detail);

  String messageForLanguage(String languageCode) {
    final en = languageCode.toLowerCase().startsWith('en');
    return switch (code) {
      ImportErrorCode.badPassphrase => en
          ? 'Wrong passphrase, or the encrypted data is corrupted.'
          : '口令错误，或加密数据已损坏。',
      ImportErrorCode.decryptFailed => detail == null || detail!.isEmpty
          ? (en
              ? 'Could not decrypt the encrypted config.'
              : '无法解密加密配置。')
          : (en
              ? 'Could not decrypt: $detail'
              : '无法解密：$detail'),
      ImportErrorCode.unsupported => en
          ? 'Unsupported encrypted format. Upgrade the app.'
          : '不支持的加密格式，请升级客户端。',
    };
  }

  @override
  String toString() =>
      'ImportException($code${detail != null ? ': $detail' : ''})';
}

enum ImportErrorCode {
  badPassphrase,
  decryptFailed,
  unsupported,
}
