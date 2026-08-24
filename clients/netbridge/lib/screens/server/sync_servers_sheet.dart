import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../services/server_pack_codec.dart';
import '../../services/server_share_service.dart';
import '../../theme.dart';
import 'encrypted_qr_screen.dart';

/// Sync entry: encrypted QR / file share / NFC (Android when available).
Future<void> showSyncServersSheet(
  BuildContext context, {
  required List<ServerEntry> servers,
  String? initialSelectedId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _SyncServersSheet(
      servers: servers,
      initialSelectedId: initialSelectedId,
    ),
  );
}

class _SyncServersSheet extends StatefulWidget {
  const _SyncServersSheet({
    required this.servers,
    this.initialSelectedId,
  });

  final List<ServerEntry> servers;
  final String? initialSelectedId;

  @override
  State<_SyncServersSheet> createState() => _SyncServersSheetState();
}

class _SyncServersSheetState extends State<_SyncServersSheet> {
  late String _selectedId;
  bool _nfcChecking = true;
  bool _nfcOk = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId ??
        (widget.servers.isNotEmpty ? widget.servers.first.id : '');
    _probeNfc();
  }

  Future<void> _probeNfc() async {
    final ok = await ServerShareService.isNfcAvailable();
    if (mounted) {
      setState(() {
        _nfcOk = ok;
        _nfcChecking = false;
      });
    }
  }

  ServerEntry? get _entry {
    for (final s in widget.servers) {
      if (s.id == _selectedId) return s;
    }
    return widget.servers.isEmpty ? null : widget.servers.first;
  }

  Future<String?> _askPassphrase() async {
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
    final text = field.text;
    field.dispose();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  Future<void> _syncQr() async {
    final entry = _entry;
    if (entry == null) return;
    final pass = await _askPassphrase();
    if (pass == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EncryptedQrScreen(entries: [entry], passphrase: pass),
      ),
    );
  }

  Future<void> _syncFile() async {
    final l10n = AppLocalizations.of(context);
    final entry = _entry;
    if (entry == null) return;
    final pass = await _askPassphrase();
    if (pass == null || !mounted) return;
    try {
      final env = await ServerPackCodec.encryptPack([entry], pass);
      final json = const JsonEncoder.withIndent('  ').convert(env);
      await ServerShareService.shareFileBytes(
        bytes: utf8.encode(json),
        filename: 'netbridge-sync.nbvpn.enc.json',
        mimeType: 'application/json',
        subject: l10n.sync,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.syncFailed}: $e')),
        );
      }
    }
  }

  Future<void> _syncNfc() async {
    final l10n = AppLocalizations.of(context);
    if (!_nfcOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nfcUnsupported)),
      );
      return;
    }
    final entry = _entry;
    if (entry == null) return;
    final pass = await _askPassphrase();
    if (pass == null || !mounted) return;
    try {
      final uri = await ServerPackCodec.encryptPackUri([entry], pass);
      if (uri.length > ServerShareService.nfcSoftLimitBytes) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.nfcTooLargeTitle),
            content: Text(l10n.nfcTooLargeBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _syncFile();
                },
                child: Text(l10n.syncViaFile),
              ),
            ],
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nfcHoldTag)),
      );
      await ServerShareService.writeNfcText(uri);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nfcWriteOk)),
        );
      }
    } catch (e) {
      await ServerShareService.stopNfc();
      if (!mounted) return;
      final msg = '$e'.contains('nfc_payload_too_large')
          ? l10n.nfcTooLargeBody
          : '${l10n.nfcFailed}: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                l10n.syncTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NbColors.warmText,
                ),
              ),
            ),
            if (widget.servers.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedId,
                  decoration: InputDecoration(labelText: l10n.server),
                  items: [
                    for (final s in widget.servers)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.localName),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedId = v);
                  },
                ),
              ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.syncViaQr),
              subtitle: Text(l10n.syncViaQrSubtitle),
              onTap: _syncQr,
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: Text(l10n.syncViaFile),
              subtitle: Text(l10n.syncViaFileSubtitle),
              onTap: _syncFile,
            ),
            ListTile(
              leading: const Icon(Icons.nfc),
              enabled: !_nfcChecking && _nfcOk,
              title: Text(l10n.syncViaNfc),
              subtitle: Text(
                _nfcChecking
                    ? '…'
                    : _nfcOk
                        ? l10n.syncViaNfcSubtitle
                        : l10n.nfcUnsupported,
              ),
              onTap: _nfcOk ? _syncNfc : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l10n.syncBluetoothNote,
                style: const TextStyle(
                  color: NbColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
