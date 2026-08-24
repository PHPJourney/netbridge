import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../layout/responsive.dart';
import '../../services/server_import.dart';
import '../../services/server_share_service.dart';
import '../../theme.dart';
import '../../widgets/common_widgets.dart';

/// Add-server flow: read plaintext nbvpn URI/profile from NFC tag.
class NfcImportScreen extends StatefulWidget {
  const NfcImportScreen({super.key});

  @override
  State<NfcImportScreen> createState() => _NfcImportScreenState();
}

class _NfcImportScreenState extends State<NfcImportScreen> {
  bool _nfcOk = false;
  bool _checking = true;
  bool _reading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final ok = await ServerShareService.isNfcAvailable();
    if (mounted) {
      setState(() {
        _nfcOk = ok;
        _checking = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(ServerShareService.stopNfc());
    super.dispose();
  }

  Future<void> _read() async {
    if (!_nfcOk || _reading) return;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final payload = await ServerShareService.readNfcText();
      if (!mounted) return;
      if (payload == null || payload.trim().isEmpty) {
        setState(() {
          _error = l10n.nfcReadEmpty;
          _reading = false;
        });
        return;
      }
      final entries = await ProfileImportService.parseText(context, payload);
      if (!mounted) return;
      if (entries == null) {
        setState(() => _reading = false);
        return;
      }
      Navigator.of(context).pop(entries);
    } catch (e) {
      await ServerShareService.stopNfc();
      if (!mounted) return;
      setState(() {
        _error = ProfileImportService.errorMessage(e, lang);
        _reading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importViaNfc)),
      body: DesktopConstrainedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SecretWarningCallout(),
            const SizedBox(height: 16),
            Icon(Icons.nfc, size: 64, color: _nfcOk ? NbColors.accent : NbColors.mutedText),
            const SizedBox(height: 16),
            Text(
              l10n.importViaNfcBody,
              style: const TextStyle(color: NbColors.mutedText, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_checking)
              const Center(child: CircularProgressIndicator())
            else if (!_nfcOk)
              Text(
                l10n.nfcUnsupported,
                style: const TextStyle(color: NbColors.danger),
                textAlign: TextAlign.center,
              )
            else
              FilledButton.icon(
                onPressed: _reading ? null : _read,
                icon: _reading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.nfc),
                label: Text(_reading ? l10n.nfcHoldTag : l10n.nfcStartRead),
              ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              ErrorCopyable(
                message: _error!,
                onRetry: () => setState(() {
                  _error = null;
                  _reading = false;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
