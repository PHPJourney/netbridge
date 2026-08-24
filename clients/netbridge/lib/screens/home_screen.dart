import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../layout/responsive.dart';
import '../models/server_entry.dart';
import '../profile/profile.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/status_banner.dart';
import 'add/add_method_screen.dart';
import 'add/confirm_add_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedId;

  AppController get controller => widget.controller;

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
      if (_selectedId == entry.id) {
        setState(() => _selectedId = null);
      }
    }
  }

  ServerEntry? _resolveSelected(AppController c) {
    if (c.servers.isEmpty) return null;
    final id = _selectedId ?? c.activeServerId ?? c.servers.first.id;
    for (final s in c.servers) {
      if (s.id == id) return s;
    }
    return c.servers.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final desktop = isDesktopLayout(context);
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
                statusDetail: c.statusDetail,
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
                        : desktop
                            ? _DesktopSplit(
                                controller: c,
                                selected: _resolveSelected(c),
                                onSelect: (id) => setState(() => _selectedId = id),
                                onConnect: (id) => c.connect(id),
                                onDisconnect: c.disconnect,
                                onRename: (s) => _rename(context, s),
                                onDelete: (s) => _delete(context, s),
                              )
                            : _MobileServerList(
                                controller: c,
                                onConnect: (id) => c.connect(id),
                                onDisconnect: c.disconnect,
                                onRename: (s) => _rename(context, s),
                                onDelete: (s) => _delete(context, s),
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

class _MobileServerList extends StatelessWidget {
  const _MobileServerList({
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRename,
    required this.onDelete,
  });

  final AppController controller;
  final ValueChanged<String> onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<ServerEntry> onRename;
  final ValueChanged<ServerEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: c.servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = c.servers[i];
        final isActive = c.activeServerId == s.id;
        final connected = isActive && c.status == VpnUiStatus.connected;
        final busy = isActive &&
            (c.status == VpnUiStatus.connecting ||
                c.status == VpnUiStatus.reconnecting);
        return _ServerTile(
          entry: s,
          connected: connected,
          busy: busy,
          selected: false,
          onTap: null,
          onConnect: () => onConnect(s.id),
          onDisconnect: onDisconnect,
          onRename: () => onRename(s),
          onDelete: () => onDelete(s),
        );
      },
    );
  }
}

class _DesktopSplit extends StatelessWidget {
  const _DesktopSplit({
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRename,
    required this.onDelete,
  });

  final AppController controller;
  final ServerEntry? selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<ServerEntry> onRename;
  final ValueChanged<ServerEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: kDesktopListPaneWidth,
          child: Material(
            color: NbColors.surface.withValues(alpha: 0.55),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 96),
              itemCount: c.servers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = c.servers[i];
                final isActive = c.activeServerId == s.id;
                final connected =
                    isActive && c.status == VpnUiStatus.connected;
                final busy = isActive &&
                    (c.status == VpnUiStatus.connecting ||
                        c.status == VpnUiStatus.reconnecting);
                final isSelected = selected?.id == s.id;
                return _ServerTile(
                  entry: s,
                  connected: connected,
                  busy: busy,
                  selected: isSelected,
                  compactActions: true,
                  onTap: () => onSelect(s.id),
                  onConnect: () => onConnect(s.id),
                  onDisconnect: onDisconnect,
                  onRename: () => onRename(s),
                  onDelete: () => onDelete(s),
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: NbColors.surfaceAlt),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                    l10n.emptyTitle,
                    style: const TextStyle(color: NbColors.mutedText),
                  ),
                )
              : _DesktopDetailPane(
                  entry: selected!,
                  controller: c,
                  onConnect: () => onConnect(selected!.id),
                  onDisconnect: onDisconnect,
                  onRename: () => onRename(selected!),
                  onDelete: () => onDelete(selected!),
                ),
        ),
      ],
    );
  }
}

class _DesktopDetailPane extends StatelessWidget {
  const _DesktopDetailPane({
    required this.entry,
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRename,
    required this.onDelete,
  });

  final ServerEntry entry;
  final AppController controller;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final isActive = c.activeServerId == entry.id;
    final connected = isActive && c.status == VpnUiStatus.connected;
    final busy = isActive &&
        (c.status == VpnUiStatus.connecting ||
            c.status == VpnUiStatus.reconnecting);

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 96),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.localName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: NbColors.warmText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.profile.server.endpoint,
                style: const TextStyle(
                  color: NbColors.mutedText,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              _DetailRow(
                label: l10n.labelAddress,
                value: entry.profile.client.address.join(', '),
              ),
              _DetailRow(
                label: l10n.labelDns,
                value: entry.profile.client.dns.join(', '),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
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
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onRename,
                    child: Text(l10n.rename),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: NbColors.danger),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: NbColors.warmText, fontSize: 14),
            ),
          ),
        ],
      ),
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
    this.selected = false,
    this.compactActions = false,
    this.onTap,
  });

  final ServerEntry entry;
  final bool connected;
  final bool busy;
  final bool selected;
  final bool compactActions;
  final VoidCallback? onTap;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = selected ? NbColors.surfaceAlt : NbColors.surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            12,
            compactActions ? 4 : 8,
            12,
          ),
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
              if (!compactActions) ...[
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
              ],
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'connect') onConnect();
                  if (v == 'disconnect') onDisconnect();
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  if (compactActions && !(connected || busy))
                    PopupMenuItem(value: 'connect', child: Text(l10n.connect)),
                  if (compactActions && (connected || busy))
                    PopupMenuItem(
                      value: 'disconnect',
                      enabled: !busy,
                      child: Text(l10n.disconnect),
                    ),
                  PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
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
