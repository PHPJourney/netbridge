import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../layout/responsive.dart';
import '../../services/server_import.dart';
import '../../services/server_share_service.dart';
import '../../theme.dart';
import '../home_screen.dart' show pickAndParseNbVpnFiles, supportsCameraScan;
import 'bluetooth_import_screen.dart';
import 'nfc_import_screen.dart';
import 'paste_uri_screen.dart';
import 'scan_qr_screen.dart';

/// Choose import method: paste / file / scan / NFC / Bluetooth.
class AddMethodScreen extends StatelessWidget {
  const AddMethodScreen({super.key});

  static bool get supportsNfc {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void _popWith(BuildContext context, List<ImportedServer> entries) {
    Navigator.of(context).pop(entries);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addMethodTitle)),
      body: DesktopConstrainedBody(
        // Column only — DesktopConstrainedBody already scrolls; ListView here
        // gets unbounded height and renders blank on Android.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.chooseImportMethod,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NbColors.warmText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.importMethodsHint,
              style: const TextStyle(color: NbColors.mutedText, height: 1.4),
            ),
            const SizedBox(height: 20),
            _MethodCard(
              icon: Icons.content_paste,
              title: l10n.pasteUri,
              subtitle: l10n.pasteUriSubtitle,
              onTap: () async {
                final list = await Navigator.of(context).push<List<ImportedServer>>(
                  MaterialPageRoute(builder: (_) => const PasteUriScreen()),
                );
                if (list != null && list.isNotEmpty && context.mounted) {
                  _popWith(context, list);
                }
              },
            ),
            const SizedBox(height: 12),
            _MethodCard(
              icon: Icons.insert_drive_file_outlined,
              title: l10n.importFile,
              subtitle: l10n.importFileSubtitle,
              onTap: () async {
                final list = await pickAndParseNbVpnFiles(context);
                if (list != null && list.isNotEmpty && context.mounted) {
                  _popWith(context, list);
                }
              },
            ),
            const SizedBox(height: 12),
            _MethodCard(
              icon: Icons.qr_code_scanner,
              title: l10n.scanQr,
              subtitle: supportsCameraScan
                  ? l10n.scanQrSubtitleMobile
                  : l10n.scanQrSubtitleDesktop,
              enabled: supportsCameraScan,
              onTap: supportsCameraScan
                  ? () async {
                      final list = await Navigator.of(context).push<List<ImportedServer>>(
                        MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                      );
                      if (list != null && list.isNotEmpty && context.mounted) {
                        _popWith(context, list);
                      }
                    }
                  : null,
            ),
            if (supportsNfc) ...[
              const SizedBox(height: 12),
              _MethodCard(
                icon: Icons.nfc,
                title: l10n.importViaNfc,
                subtitle: l10n.importViaNfcSubtitle,
                enabled: ServerShareService.supportsNfc,
                onTap: () async {
                  final list = await Navigator.of(context).push<List<ImportedServer>>(
                    MaterialPageRoute(builder: (_) => const NfcImportScreen()),
                  );
                  if (list != null && list.isNotEmpty && context.mounted) {
                                        _popWith(context, list);
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            _MethodCard(
              icon: Icons.bluetooth,
              title: l10n.importViaBluetooth,
              subtitle: l10n.importViaBluetoothSubtitle,
              onTap: () async {
                final list = await Navigator.of(context).push<List<ImportedServer>>(
                  MaterialPageRoute(builder: (_) => const BluetoothImportScreen()),
                );
                if (list != null && list.isNotEmpty && context.mounted) {
                  _popWith(context, list);
                }
              },
            ),
            if (!supportsCameraScan) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final list = await Navigator.of(context).push<List<ImportedServer>>(
                    MaterialPageRoute(builder: (_) => const PasteUriScreen()),
                  );
                  if (list != null && list.isNotEmpty && context.mounted) {
                                        _popWith(context, list);
                  }
                },
                child: Text(l10n.usePasteUriInstead),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: NbColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: NbColors.accent, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: NbColors.warmText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: NbColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: NbColors.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
