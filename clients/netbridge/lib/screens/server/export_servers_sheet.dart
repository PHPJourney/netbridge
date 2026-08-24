import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../services/server_pack_codec.dart';
import '../../services/server_share_service.dart';
import '../../theme.dart';

/// Export backup: cleartext .nbvpn.json / optional .conf (contains private keys).
Future<void> showExportServersSheet(
  BuildContext context, {
  required List<ServerEntry> servers,
  String? initialSelectedId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExportServersSheet(
      servers: servers,
      initialSelectedId: initialSelectedId,
    ),
  );
}

class _ExportServersSheet extends StatefulWidget {
  const _ExportServersSheet({
    required this.servers,
    this.initialSelectedId,
  });

  final List<ServerEntry> servers;
  final String? initialSelectedId;

  @override
  State<_ExportServersSheet> createState() => _ExportServersSheetState();
}

class _ExportServersSheetState extends State<_ExportServersSheet> {
  late final Set<String> _selected;
  bool _alsoWgConf = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = {
      if (widget.initialSelectedId != null) widget.initialSelectedId!,
    };
    if (_selected.isEmpty && widget.servers.length == 1) {
      _selected.add(widget.servers.first.id);
    }
  }

  List<ServerEntry> get _picked =>
      widget.servers.where((e) => _selected.contains(e.id)).toList();

  Future<void> _confirmSecrets() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportBackupTitle),
        content: Text(l10n.exportBackupBody),
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
    if (ok == true) await _doExport();
  }

  Future<void> _doExport() async {
    final l10n = AppLocalizations.of(context);
    final picked = _picked;
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final jsonText = picked.length == 1
          ? ServerPackCodec.encodeSingleProfileJson(picked.first.profile)
          : ServerPackCodec.encodeClearJson(picked);
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '')
          .split('.')
          .first;
      await ServerShareService.shareFileBytes(
        bytes: utf8.encode(jsonText),
        filename: picked.length == 1
            ? '${_safeName(picked.first.localName)}.nbvpn.json'
            : 'netbridge-servers-$stamp.nbvpn.json',
        mimeType: 'application/json',
        subject: l10n.exportBackup,
      );
      if (_alsoWgConf) {
        final conf = ServerPackCodec.wireGuardBundle(picked);
        await ServerShareService.shareFileBytes(
          bytes: utf8.encode(conf),
          filename: picked.length == 1
              ? '${_safeName(picked.first.localName)}.conf'
              : 'netbridge-servers-$stamp.conf',
          mimeType: 'text/plain',
          subject: l10n.exportWireGuard,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _safeName(String name) {
    final s = name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return s.isEmpty ? 'server' : s;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                l10n.exportBackupTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NbColors.warmText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.exportBackupHint,
                style: const TextStyle(
                  color: NbColors.mutedText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _selected
                        ..clear()
                        ..addAll(widget.servers.map((e) => e.id)),
                    ),
                    child: Text(l10n.selectAll),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: Text(l10n.selectNone),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.servers.length,
                itemBuilder: (context, i) {
                  final s = widget.servers[i];
                  final checked = _selected.contains(s.id);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(s.localName),
                    subtitle: Text(
                      s.profile.server.endpoint,
                      style: const TextStyle(
                        color: NbColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(s.id);
                        } else {
                          _selected.remove(s.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            SwitchListTile(
              value: _alsoWgConf,
              onChanged: (v) => setState(() => _alsoWgConf = v),
              title: Text(l10n.exportAlsoWireGuard),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _busy || _selected.isEmpty ? null : _confirmSecrets,
                child: Text(_busy ? '…' : l10n.exportBackup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
