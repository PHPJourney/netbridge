import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../profile/profile.dart';
import '../../theme.dart';
import '../../widgets/common_widgets.dart';

/// C-06: confirm add with editable localName + secret warning.
class ConfirmAddScreen extends StatefulWidget {
  const ConfirmAddScreen({super.key, required this.profile});

  final NbVpnProfile profile;

  @override
  State<ConfirmAddScreen> createState() => _ConfirmAddScreenState();
}

class _ConfirmAddScreenState extends State<ConfirmAddScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final ep = p.server.endpoint.trim();
    final endpointLooksBad = ep.isEmpty ||
        ep.startsWith('0.0.0.0:') ||
        ep.startsWith('[::]:') ||
        ep == '0.0.0.0';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmAddTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SecretWarningCallout(),
          if (endpointLooksBad) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NbColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NbColors.warn.withValues(alpha: 0.5)),
              ),
              child: Text(
                l10n.endpointLooksBad,
                style: const TextStyle(
                  color: NbColors.warmText,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.localDisplayName,
              helperText: l10n.localNameHelper,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: l10n.labelNode, value: p.server.endpoint),
          _SummaryRow(label: l10n.labelAddress, value: p.client.address.join(', ')),
          _SummaryRow(label: l10n.labelDns, value: p.client.dns.join(', ')),
          const SizedBox(height: 8),
          Text(
            l10n.confirmSecretHint,
            style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop((
                profile: p,
                localName: _name.text.trim().isEmpty ? p.name : _name.text.trim(),
              ));
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: NbColors.warmText, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
