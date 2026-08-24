import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cross-device share helpers (system share sheet / temp files / NFC tag write).
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

  static Future<bool> isNfcAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return false;
      return NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Practical NFC payload budget for NDEF text (bytes). Larger → use file share.
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

  /// Write [payload] as NDEF Text to the next NFC tag (Android/iOS when available).
  /// Returns false if NFC unavailable; throws if payload too large or write fails.
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
            // iOS NDEF write status varies; attempt query then write via status.
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

  static Future<void> stopNfc() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
