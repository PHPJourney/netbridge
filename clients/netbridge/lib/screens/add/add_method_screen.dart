import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../profile/profile.dart';
import '../../theme.dart';
import '../home_screen.dart' show pickAndParseNbVpnFile, supportsCameraScan;
import 'paste_uri_screen.dart';
import 'scan_qr_screen.dart';

/// C-02: choose paste / file / scan.
class AddMethodScreen extends StatelessWidget {
  const AddMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addMethodTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
            l10n.noOfficialNodes,
            style: const TextStyle(color: NbColors.mutedText, height: 1.4),
          ),
          const SizedBox(height: 24),
          _MethodCard(
            icon: Icons.content_paste,
            title: l10n.pasteUri,
            subtitle: l10n.pasteUriSubtitle,
            onTap: () async {
              final p = await Navigator.of(context).push<NbVpnProfile>(
                MaterialPageRoute(builder: (_) => const PasteUriScreen()),
              );
              if (p != null && context.mounted) {
                Navigator.of(context).pop(p);
              }
            },
          ),
          const SizedBox(height: 12),
          _MethodCard(
            icon: Icons.insert_drive_file_outlined,
            title: l10n.importFile,
            subtitle: l10n.importFileSubtitle,
            onTap: () async {
              final p = await pickAndParseNbVpnFile(context);
              if (p != null && context.mounted) {
                Navigator.of(context).pop(p);
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
                    final p = await Navigator.of(context).push<NbVpnProfile>(
                      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                    );
                    if (p != null && context.mounted) {
                      Navigator.of(context).pop(p);
                    }
                  }
                : null,
          ),
          if (!supportsCameraScan) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final p = await Navigator.of(context).push<NbVpnProfile>(
                  MaterialPageRoute(builder: (_) => const PasteUriScreen()),
                );
                if (p != null && context.mounted) {
                  Navigator.of(context).pop(p);
                }
              },
              child: Text(l10n.usePasteUriInstead),
            ),
          ],
        ],
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
