import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../profile/profile_codec.dart';
import '../../services/server_pack_codec.dart';
import '../../services/server_share_service.dart';
import '../../theme.dart';

/// Near-field sync: NFC (plaintext) + Bluetooth (optional passphrase).
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
  bool _btUsePassword = false;

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

  Future<String?> _askPassphrase({required String title, required String body}) async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
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
    try {
      final uri = ProfileCodec.encodeUri(entry.profile);
      if (uri.length > ServerShareService.nfcSoftLimitBytes) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.nfcTooLargeTitle),
            content: Text(l10n.nfcTooLargePlainBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
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
          ? l10n.nfcTooLargePlainBody
          : '${l10n.nfcFailed}: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _syncBluetooth() async {
    final l10n = AppLocalizations.of(context);
    final entry = _entry;
    if (entry == null) return;
    try {
      if (_btUsePassword) {
        final pass = await _askPassphrase(
          title: l10n.syncPassphraseTitle,
          body: l10n.syncPassphraseBody,
        );
        if (pass == null || !mounted) return;
        final env = await ServerPackCodec.encryptPack([entry], pass);
        final json = const JsonEncoder.withIndent('  ').convert(env);
        await ServerShareService.shareFileBytes(
          bytes: utf8.encode(json),
          filename: 'netbridge-bt.nbvpn.enc.json',
          mimeType: 'application/json',
          subject: l10n.syncViaBluetooth,
        );
      } else {
        final uri = ProfileCodec.encodeUri(entry.profile);
        await ServerShareService.shareFileBytes(
          bytes: utf8.encode(uri),
          filename: 'netbridge-bt.nbvpn.txt',
          mimeType: 'text/plain',
          subject: l10n.syncViaBluetooth,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.syncFailed}: $e')),
        );
      }
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Text(
                l10n.nearFieldSyncTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NbColors.warmText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.nearFieldSyncHint,
                style: const TextStyle(
                  color: NbColors.mutedText,
                  fontSize: 12,
                  height: 1.4,
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
              leading: const Icon(Icons.nfc),
              enabled: !_nfcChecking && _nfcOk,
              title: Text(l10n.syncViaNfc),
              subtitle: Text(
                _nfcChecking
                    ? '…'
                    : _nfcOk
                        ? l10n.syncViaNfcPlainSubtitle
                        : l10n.nfcUnsupported,
              ),
              onTap: _nfcOk ? _syncNfc : null,
            ),
            SwitchListTile(
              value: _btUsePassword,
              onChanged: (v) => setState(() => _btUsePassword = v),
              title: Text(l10n.bluetoothUsePassword),
              subtitle: Text(l10n.bluetoothUsePasswordSubtitle),
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(l10n.syncViaBluetooth),
              subtitle: Text(l10n.syncViaBluetoothSubtitle),
              onTap: _syncBluetooth,
            ),
          ],
        ),
      ),
    );
  }
}
