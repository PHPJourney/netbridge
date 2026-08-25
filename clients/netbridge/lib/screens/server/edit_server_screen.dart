import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../profile/nbvpn_profile.dart';
import '../../profile/profile_codec.dart';
import '../../profile/profile_errors.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';

/// Edit local display name + non-secret profile fields.
/// Private key / server public key / PSK are never shown or editable here.
class EditServerScreen extends StatefulWidget {
  const EditServerScreen({
    super.key,
    required this.controller,
    required this.entry,
  });

  final AppController controller;
  final ServerEntry entry;

  @override
  State<EditServerScreen> createState() => _EditServerScreenState();
}

class _EditServerScreenState extends State<EditServerScreen> {
  late final TextEditingController _localName;
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _endpointV6;
  late final TextEditingController _address;
  late final TextEditingController _dns;
  late final TextEditingController _allowedIps;
  late final TextEditingController _mtu;
  late final TextEditingController _keepalive;
  late bool _ipv6Enabled;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.entry.profile;
    _localName = TextEditingController(text: widget.entry.localName);
    _name = TextEditingController(text: p.name);
    _endpoint = TextEditingController(text: p.server.endpoint);
    _endpointV6 = TextEditingController(text: p.server.endpointV6 ?? '');
    _ipv6Enabled = p.server.ipv6Enabled;
    _address = TextEditingController(text: p.client.address.join(', '));
    _dns = TextEditingController(text: p.client.dns.join(', '));
    _allowedIps = TextEditingController(text: p.server.allowedIPs.join(', '));
    _mtu = TextEditingController(
      text: p.client.mtu != null && p.client.mtu! > 0 ? '${p.client.mtu}' : '',
    );
    _keepalive = TextEditingController(
      text: p.server.persistentKeepalive != null &&
              p.server.persistentKeepalive! > 0
          ? '${p.server.persistentKeepalive}'
          : '$defaultKeepalive',
    );
  }

  @override
  void dispose() {
    _localName.dispose();
    _name.dispose();
    _endpoint.dispose();
    _endpointV6.dispose();
    _address.dispose();
    _dns.dispose();
    _allowedIps.dispose();
    _mtu.dispose();
    _keepalive.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final mtuText = _mtu.text.trim();
      final kaText = _keepalive.text.trim();
      final v6Text = _endpointV6.text.trim();
      final old = widget.entry.profile;
      // Keys stay untouched — never read from UI.
      final profile = NbVpnProfile(
        v: NbVpnProfile.supportedVersion,
        name: _name.text.trim(),
        client: ClientSection(
          privateKey: old.client.privateKey,
          address: _splitList(_address.text),
          dns: _splitList(_dns.text),
          mtu: mtuText.isEmpty ? null : int.tryParse(mtuText),
        ),
        server: ServerSection(
          publicKey: old.server.publicKey,
          endpoint: _endpoint.text.trim(),
          endpointV6: v6Text.isEmpty ? null : v6Text,
          ipv6Enabled: _ipv6Enabled && v6Text.isNotEmpty,
          allowedIPs: _splitList(_allowedIps.text),
          persistentKeepalive:
              kaText.isEmpty ? null : int.tryParse(kaText),
          presharedKey: old.server.presharedKey,
        ),
      );
      ProfileCodec.validate(profile);
      await widget.controller.updateServer(
        widget.entry.id,
        localName: _localName.text,
        profile: profile,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saved)),
        );
        Navigator.of(context).pop(true);
      }
    } on ProfileException catch (e) {
      setState(() => _error = e.messageForLanguage(lang));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasV6 = _endpointV6.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editServer),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            l10n.editKeysLockedHint,
            style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _field(_localName, l10n.localDisplayName),
          _field(_name, l10n.profileName),
          _field(_endpoint, l10n.labelEndpoint),
          _field(
            _endpointV6,
            l10n.labelEndpointV6,
            helperText: l10n.endpointV6Helper,
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ipv6EnabledTitle),
            subtitle: Text(
              hasV6
                  ? (_ipv6Enabled
                      ? l10n.ipv6EnabledOnHint
                      : l10n.ipv6EnabledOffHint)
                  : l10n.ipv6EnabledNeedEndpointHint,
            ),
            value: _ipv6Enabled && hasV6,
            onChanged: hasV6
                ? (v) => setState(() => _ipv6Enabled = v)
                : null,
          ),
          _field(_address, l10n.labelAddress),
          _field(_dns, l10n.labelDns),
          _field(
            _allowedIps,
            l10n.labelAllowedIps,
            helperText: l10n.allowedIpsHelper,
          ),
          _field(_mtu, l10n.labelMtu, keyboard: TextInputType.number),
          _field(
            _keepalive,
            l10n.labelKeepalive,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: NbColors.mutedText),
            title: Text(l10n.keysConfigured),
            subtitle: Text(
              l10n.keysConfiguredSubtitle,
              style: const TextStyle(color: NbColors.mutedText, fontSize: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: NbColors.danger)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '…' : l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    String? helperText,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
