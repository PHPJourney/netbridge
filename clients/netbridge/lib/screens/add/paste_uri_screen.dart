import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../layout/responsive.dart';
import '../../profile/profile.dart';
import '../../services/server_pack_codec.dart';
import '../../widgets/common_widgets.dart';

/// C-03: paste nbvpn URI (or encrypted sync pack).
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

  Future<String?> _askPassphrase() async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncPassphraseTitle),
        content: TextField(
          controller: field,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.passphrase,
            border: const OutlineInputBorder(),
          ),
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

  Future<void> _submit() async {
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      final raw = _controller.text.trim();
      if (ServerPackCodec.looksLikeEncryptedUri(raw) ||
          ServerPackCodec.looksLikeEncryptedJson(raw)) {
        final pass = await _askPassphrase();
        if (pass == null) {
          setState(() => _validating = false);
          return;
        }
        final entries = ServerPackCodec.looksLikeEncryptedUri(raw)
            ? await ServerPackCodec.decryptPackUri(raw, pass)
            : await ServerPackCodec.decryptEnvelope(
                (jsonDecode(raw) as Map).cast<String, dynamic>(),
                pass,
              );
        if (entries.isEmpty) {
          throw const FormatException('empty pack');
        }
        if (!mounted) return;
        // Add-flow returns one profile; multi-pack → first entry.
        final first = entries.first;
        final profile = NbVpnProfile(
          v: first.profile.v,
          name: first.localName.isNotEmpty
              ? first.localName
              : first.profile.name,
          client: first.profile.client,
          server: first.profile.server,
        );
        Navigator.of(context).pop(profile);
        return;
      }

      final profile = ProfileCodec.parseFlexibleImport(raw);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on ProfileException catch (e) {
      setState(() {
        _error = e.messageForLanguage(lang);
        _validating = false;
      });
    } catch (_) {
      setState(() {
        _error = ProfileException(ProfileErrorCode.uriDecode)
            .messageForLanguage(lang);
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
