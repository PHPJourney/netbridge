import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/server_entry.dart';
import '../profile/profile.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/status_banner.dart';
import 'add/add_method_screen.dart';
import 'add/confirm_add_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _openAdd(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profile = await Navigator.of(context).push<NbVpnProfile>(
      MaterialPageRoute(builder: (_) => const AddMethodScreen()),
    );
    if (profile == null || !context.mounted) return;

    // Same endpoint+keys already present → clear feedback, never silent no-op.
    final existing = controller.findDuplicate(profile);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alreadyAdded(existing.localName))),
      );
      return;
    }

    final confirmed = await Navigator.of(context).push<({NbVpnProfile profile, String localName})>(
      MaterialPageRoute(
        builder: (_) => ConfirmAddScreen(profile: profile),
      ),
    );
    if (confirmed == null || !context.mounted) return;

    final again = controller.findDuplicate(confirmed.profile);
    if (again != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.alreadyAdded(again.localName))),
      );
      return;
    }

    await controller.addServer(
      profile: confirmed.profile,
      localName: confirmed.localName,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.added)),
      );
    }
  }

  Future<void> _rename(BuildContext context, ServerEntry entry) async {
    final field = TextEditingController(text: entry.localName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(d.rename),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(labelText: d.localDisplayName),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(d.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(d.save)),
          ],
        );
      },
    );
    if (ok == true) {
      await controller.renameServer(entry.id, field.text);
    }
  }

  Future<void> _delete(BuildContext context, ServerEntry entry) async {
    final connected = controller.activeServerId == entry.id &&
        controller.status != VpnUiStatus.disconnected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(d.deleteServer),
          content: Text(
            connected
                ? d.deleteConfirmConnected(entry.localName)
                : d.deleteConfirm(entry.localName),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(d.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: NbColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(d.delete),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await controller.deleteServer(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                tooltip: l10n.settings,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(controller: c),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              StatusBanner(
                status: c.status,
                serverName: c.activeServer?.localName,
                errorText: c.lastError,
                onCopyError: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copiedError)),
                  );
                },
                onRetry: c.retry,
              ),
              Expanded(
                child: c.loading
                    ? const Center(child: CircularProgressIndicator())
                    : c.servers.isEmpty
                        ? EmptyServerState(onAdd: () => _openAdd(context))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            itemCount: c.servers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = c.servers[i];
                              final isActive = c.activeServerId == s.id;
                              final connected = isActive &&
                                  c.status == VpnUiStatus.connected;
                              final busy = isActive &&
                                  (c.status == VpnUiStatus.connecting ||
                                      c.status == VpnUiStatus.reconnecting);
                              return _ServerTile(
                                entry: s,
                                connected: connected,
                                busy: busy,
                                onConnect: () => c.connect(s.id),
                                onDisconnect: c.disconnect,
                                onRename: () => _rename(context, s),
                                onDelete: () => _delete(context, s),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: c.servers.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openAdd(context),
                  backgroundColor: NbColors.accent,
                  foregroundColor: NbColors.deepTeal,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addServer),
                ),
        );
      },
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.entry,
    required this.connected,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRename,
    required this.onDelete,
  });

  final ServerEntry entry;
  final bool connected;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: NbColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? NbColors.ok
                    : busy
                        ? NbColors.warn
                        : NbColors.mutedText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.localName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: NbColors.warmText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.profile.server.endpoint,
                    style: const TextStyle(
                      color: NbColors.mutedText,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (connected || busy)
              OutlinedButton(
                onPressed: busy ? null : onDisconnect,
                child: Text(busy ? '…' : l10n.disconnect),
              )
            else
              FilledButton(
                onPressed: onConnect,
                child: Text(l10n.connect),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared helpers used by add flows.
Future<NbVpnProfile?> pickAndParseNbVpnFile(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotReadFile)),
      );
    }
    return null;
  }
  try {
    return ProfileCodec.parseJsonBytes(bytes);
  } on ProfileException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.messageForLanguage(lang))),
      );
    }
    return null;
  }
}

bool get supportsCameraScan {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

Future<void> copyText(String text) =>
    Clipboard.setData(ClipboardData(text: text));
