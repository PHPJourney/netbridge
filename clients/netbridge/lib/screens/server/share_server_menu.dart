import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/brand_links.dart';
import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../services/server_pack_codec.dart';
import '../../services/server_share_service.dart';
import '../../utils/open_url.dart';
import 'encrypted_qr_screen.dart';

/// External share: encrypted QR / encrypted file / app link only.
Future<void> showShareServerMenu(
  BuildContext context, {
  required ServerEntry entry,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.encryptedShareTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.encryptedShareHint,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: Text(l10n.shareEncryptedQr),
            subtitle: Text(l10n.shareEncryptedQrSubtitle),
            onTap: () => Navigator.pop(ctx, 'qr'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.shareEncryptedFile),
            subtitle: Text(l10n.shareEncryptedFileSubtitle),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.shareApp),
            subtitle: Text(l10n.shareAppSubtitle),
            onTap: () => Navigator.pop(ctx, 'app'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;

  if (choice == 'app') {
    final url = BrandLinks.officialSite;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shareApp),
        content: Text(l10n.shareAppConfirm(url)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.share),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ServerShareService.shareText(
        '${l10n.shareAppMessage}\n$url',
        subject: l10n.appTitle,
      );
    } catch (_) {
      if (context.mounted) await openExternalUrl(context, url);
    }
    return;
  }

  final pass = await _askSharePassphrase(context);
  if (pass == null || !context.mounted) return;

  if (choice == 'file') {
    try {
      final env = await ServerPackCodec.encryptPack([entry], pass);
      final json = const JsonEncoder.withIndent('  ').convert(env);
      await ServerShareService.shareFileBytes(
        bytes: utf8.encode(json),
        filename: 'netbridge-share.nbvpn.enc.json',
        mimeType: 'application/json',
        subject: l10n.shareEncryptedFile,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.syncFailed}: $e')),
        );
      }
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EncryptedQrScreen(entries: [entry], passphrase: pass),
    ),
  );
}

Future<String?> _askSharePassphrase(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final field = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.syncPassphraseTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.syncPassphraseBody),
          const SizedBox(height: 12),
          TextField(
            controller: field,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.passphrase,
              border: const OutlineInputBorder(),
            ),
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
  final pass = field.text;
  field.dispose();
  if (ok != true || pass.isEmpty) return null;
  return pass;
}
