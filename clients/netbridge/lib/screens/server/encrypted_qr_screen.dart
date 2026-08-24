import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../services/server_pack_codec.dart';
import '../../theme.dart';

/// Shows passphrase-encrypted QR for one or more servers.
class EncryptedQrScreen extends StatefulWidget {
  const EncryptedQrScreen({
    super.key,
    required this.entries,
    required this.passphrase,
  });

  final List<ServerEntry> entries;
  final String passphrase;

  @override
  State<EncryptedQrScreen> createState() => _EncryptedQrScreenState();
}

class _EncryptedQrScreenState extends State<EncryptedQrScreen> {
  String? _uri;
  String? _error;
  bool _loading = true;
  bool _tooDense = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    try {
      final uri = await ServerPackCodec.encryptPackUri(
        widget.entries,
        widget.passphrase,
      );
      if (!mounted) return;
      setState(() {
        _uri = uri;
        _tooDense = uri.length > 1800;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.encryptedQrTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: NbColors.danger),
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        l10n.encryptedQrHint,
                        style: const TextStyle(
                          color: NbColors.mutedText,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_tooDense)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            l10n.qrTooDenseHint,
                            style: const TextStyle(
                              color: NbColors.warn,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Expanded(
                        child: Center(
                          child: QrImageView(
                            data: _uri!,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                            size: 280,
                            errorStateBuilder: (ctx, err) => Text(
                              l10n.qrEncodeFailed,
                              style: const TextStyle(color: NbColors.danger),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l10n.exportSecretBody,
                        style: const TextStyle(
                          color: NbColors.mutedText,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
      ),
    );
  }
}
