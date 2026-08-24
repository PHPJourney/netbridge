import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cross-device share helpers (system share sheet / temp files / NFC).
class ServerShareService {
  ServerShareService._();

  static bool get supportsShareSheet {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  static bool get supportsNfc {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isNfcAvailable() async {
    if (!supportsNfc) return false;
    try {
      return NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Practical NFC payload budget for NDEF text (bytes). Larger → use Bluetooth/file.
  static const nfcSoftLimitBytes = 800;

  static Future<void> shareText(String text, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  static Future<void> shareFileBytes({
    required List<int> bytes,
    required String filename,
    String? mimeType,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType, name: filename)],
        subject: subject,
      ),
    );
  }

  static NdefMessage _textMessage(String text) {
    const lang = 'en';
    final langBytes = utf8.encode(lang);
    final textBytes = utf8.encode(text);
    final payload = Uint8List.fromList([
      langBytes.length & 0x3F,
      ...langBytes,
      ...textBytes,
    ]);
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x54]), // 'T'
          identifier: Uint8List(0),
          payload: payload,
        ),
      ],
    );
  }

  static String? _parseNdefText(NdefMessage message) {
    for (final record in message.records) {
      if (record.typeNameFormat != TypeNameFormat.wellKnown) continue;
      if (record.type.length != 1 || record.type.first != 0x54) continue;
      final payload = record.payload;
      if (payload.isEmpty) continue;
      final langLen = payload.first & 0x3F;
      if (payload.length <= langLen) continue;
      return utf8.decode(payload.sublist(1 + langLen));
    }
    return null;
  }

  /// Write [payload] as NDEF Text to the next NFC tag (Android/iOS when available).
  static Future<bool> writeNfcText(String payload) async {
    final available = await isNfcAvailable();
    if (!available) return false;
    final encoded = utf8.encode(payload);
    if (encoded.length > nfcSoftLimitBytes) {
      throw StateError('nfc_payload_too_large');
    }
    final message = _textMessage(payload);
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          if (Platform.isAndroid) {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null || !ndef.isWritable) {
              throw StateError('nfc_tag_not_writable');
            }
            if (message.byteLength > ndef.maxSize) {
              throw StateError('nfc_payload_too_large');
            }
            await ndef.writeNdefMessage(message);
          } else if (Platform.isIOS) {
            final ndef = NdefIos.from(tag);
            if (ndef == null) {
              throw StateError('nfc_tag_not_writable');
            }
            if (ndef.status != NdefStatusIos.readWrite) {
              throw StateError('nfc_tag_not_writable');
            }
            await ndef.writeNdef(message);
          } else {
            throw StateError('nfc_unsupported');
          }
          await NfcManager.instance.stopSession();
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessageIos: '$e');
          rethrow;
        }
      },
    );
    return true;
  }

  /// Read NDEF Text from the next NFC tag. Returns payload or null if empty.
  static Future<String?> readNfcText() async {
    final available = await isNfcAvailable();
    if (!available) return null;

    String? result;
    Object? error;
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          NdefMessage? message;
          if (Platform.isAndroid) {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) throw StateError('nfc_no_ndef');
            message = await ndef.getNdefMessage();
            message ??= ndef.cachedNdefMessage;
          } else if (Platform.isIOS) {
            final ndef = NdefIos.from(tag);
            if (ndef == null) throw StateError('nfc_no_ndef');
            message = await ndef.readNdef();
          } else {
            throw StateError('nfc_unsupported');
          }
          if (message != null) {
            result = _parseNdefText(message);
          }
          await NfcManager.instance.stopSession();
        } catch (e) {
          error = e;
          await NfcManager.instance.stopSession(errorMessageIos: '$e');
        }
      },
    );
    if (error != null) throw error!;
    return result;
  }

  static Future<void> stopNfc() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
