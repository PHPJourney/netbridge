import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../layout/responsive.dart';
import '../../services/server_import.dart';
import '../../theme.dart';
import '../../widgets/common_widgets.dart';

/// Add-server flow: receive config sent via Bluetooth (pick received file).
class BluetoothImportScreen extends StatefulWidget {
  const BluetoothImportScreen({super.key});

  @override
  State<BluetoothImportScreen> createState() => _BluetoothImportScreenState();
}

class _BluetoothImportScreenState extends State<BluetoothImportScreen> {
  bool _busy = false;
  String? _error;

  bool get _isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt', 'nbvpn'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _error = l10n.cannotReadFile;
          _busy = false;
        });
        return;
      }
      final entries = await ProfileImportService.parseBytes(context, bytes);
      if (!mounted) return;
      if (entries == null) {
        setState(() => _busy = false);
        return;
      }
      Navigator.of(context).pop(entries);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ProfileImportService.errorMessage(e, lang);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importViaBluetooth)),
      body: DesktopConstrainedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SecretWarningCallout(),
            const SizedBox(height: 16),
            Icon(Icons.bluetooth, size: 64, color: NbColors.accent),
            const SizedBox(height: 16),
            Text(
              _isMobile ? l10n.importViaBluetoothBody : l10n.importViaBluetoothDesktop,
              style: const TextStyle(color: NbColors.mutedText, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(l10n.importBluetoothPickFile),
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              ErrorCopyable(
                message: _error!,
                onRetry: () => setState(() {
                  _error = null;
                  _busy = false;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
