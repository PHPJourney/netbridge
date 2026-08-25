import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../layout/responsive.dart';
import '../profile/cidr_util.dart';
import '../state/app_controller.dart';
import '../theme.dart';

/// Commercial MVP: IPv4 CIDR bypass list (+ domain placeholders for future DNS).
class WhitelistScreen extends StatefulWidget {
  const WhitelistScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<WhitelistScreen> createState() => _WhitelistScreenState();
}

class _WhitelistScreenState extends State<WhitelistScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(AppLocalizations l10n) async {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    final isCidr = looksLikeIpv4Cidr(raw);
    final isDomain = looksLikeDomain(raw);
    if (!isCidr && !isDomain) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.whitelistInvalid)),
      );
      return;
    }
    final next = List<String>.from(widget.controller.whitelistEntries);
    final key = isCidr ? (Ip4Cidr.tryParse(raw)?.toString() ?? raw) : raw.toLowerCase();
    if (next.any((e) => e.toLowerCase() == key.toLowerCase())) {
      _input.clear();
      return;
    }
    next.add(key);
    await widget.controller.setWhitelistEntries(next);
    _input.clear();
    if (isDomain && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.whitelistDomainNote)),
      );
    }
  }

  Future<void> _remove(String entry) async {
    final next = widget.controller.whitelistEntries
        .where((e) => e != entry)
        .toList();
    await widget.controller.setWhitelistEntries(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = isDesktopLayout(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.whitelistEntries;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.whitelistSubtitle,
                style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        labelText: l10n.whitelistAdd,
                        hintText: l10n.whitelistAddHint,
                      ),
                      onSubmitted: (_) => _add(l10n),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _add(l10n),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.whitelistEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NbColors.mutedText),
                ),
              )
            else
              ...entries.map((e) {
                final cidr = looksLikeIpv4Cidr(e);
                return ListTile(
                  title: Text(e),
                  subtitle: Text(
                    cidr ? l10n.whitelistCidrNote : l10n.whitelistDomainNote,
                  ),
                  trailing: IconButton(
                    tooltip: l10n.whitelistRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(e),
                  ),
                );
              }),
          ],
        );

        return Scaffold(
          appBar: AppBar(title: Text(l10n.whitelistTitle)),
          body: desktop
              ? DesktopConstrainedBody(
                  maxWidth: kDesktopContentMaxWidth,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: body,
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [body],
                ),
        );
      },
    );
  }
}
