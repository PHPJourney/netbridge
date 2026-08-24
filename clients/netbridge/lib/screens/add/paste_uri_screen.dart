import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../layout/responsive.dart';
import '../../profile/profile_errors.dart';
import '../../services/server_import.dart';
import '../../widgets/common_widgets.dart';

/// Paste nbvpn URI / JSON (plain or encrypted with passphrase).
class PasteUriScreen extends StatefulWidget {
  const PasteUriScreen({super.key});

  @override
  State<PasteUriScreen> createState() => _PasteUriScreenState();
}

class _PasteUriScreenState extends State<PasteUriScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _validating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _controller.text = data!.text!;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      final entries = await ProfileImportService.parseText(
        context,
        _controller.text,
      );
      if (entries == null) {
        setState(() => _validating = false);
        return;
      }
      if (entries.isEmpty) {
        throw ProfileException(ProfileErrorCode.uriDecode, detail: 'empty pack');
      }
      if (!mounted) return;
      Navigator.of(context).pop(entries);
    } catch (e) {
      setState(() {
        _error = ProfileImportService.errorMessage(e, lang);
        _validating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = isDesktopLayout(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pasteUriTitle)),
      body: DesktopConstrainedBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: desktop ? 8 : 6,
              minLines: desktop ? 5 : 4,
              decoration: InputDecoration(
                hintText: l10n.pasteUriHint,
                alignLabelWithHint: true,
                helperText: l10n.pasteUriHelper,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: Text(l10n.pasteFromClipboard),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _validating ? null : _submit,
                  child: _validating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.validateContinue),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              ErrorCopyable(
                message: _error!,
                onRetry: () => setState(() {
                  _error = null;
                  _validating = false;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
