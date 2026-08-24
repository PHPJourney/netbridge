import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/server_entry.dart';
import '../../profile/nbvpn_profile.dart';
import '../../profile/profile_codec.dart';
import '../../profile/profile_errors.dart';
import '../../state/app_controller.dart';
import '../../theme.dart';

/// Edit local display name + mutable profile fields; private key reveal gated.
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
  late final TextEditingController _address;
  late final TextEditingController _dns;
  late final TextEditingController _allowedIps;
  late final TextEditingController _mtu;
  late final TextEditingController _keepalive;
  late final TextEditingController _privateKey;
  late final TextEditingController _publicKey;
  late final TextEditingController _presharedKey;

  bool _showPrivateKey = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.entry.profile;
    _localName = TextEditingController(text: widget.entry.localName);
    _name = TextEditingController(text: p.name);
    _endpoint = TextEditingController(text: p.server.endpoint);
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
    _privateKey = TextEditingController(text: p.client.privateKey);
    _publicKey = TextEditingController(text: p.server.publicKey);
    _presharedKey =
        TextEditingController(text: p.server.presharedKey ?? '');
  }

  @override
  void dispose() {
    _localName.dispose();
    _name.dispose();
    _endpoint.dispose();
    _address.dispose();
    _dns.dispose();
    _allowedIps.dispose();
    _mtu.dispose();
    _keepalive.dispose();
    _privateKey.dispose();
    _publicKey.dispose();
    _presharedKey.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _confirmRevealPrivateKey() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.revealPrivateKeyTitle),
        content: Text(l10n.revealPrivateKeyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.reveal),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _showPrivateKey = true);
    }
  }

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
      final psk = _presharedKey.text.trim();
      final profile = NbVpnProfile(
        v: NbVpnProfile.supportedVersion,
        name: _name.text.trim(),
        client: ClientSection(
          privateKey: _privateKey.text.trim(),
          address: _splitList(_address.text),
          dns: _splitList(_dns.text),
          mtu: mtuText.isEmpty ? null : int.tryParse(mtuText),
        ),
        server: ServerSection(
          publicKey: _publicKey.text.trim(),
          endpoint: _endpoint.text.trim(),
          allowedIPs: _splitList(_allowedIps.text),
          persistentKeepalive:
              kaText.isEmpty ? null : int.tryParse(kaText),
          presharedKey: psk.isEmpty ? null : psk,
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
            l10n.secretWarning,
            style: const TextStyle(color: NbColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _field(_localName, l10n.localDisplayName),
          _field(_name, l10n.profileName),
          _field(_endpoint, l10n.labelEndpoint),
          _field(_address, l10n.labelAddress),
          _field(_dns, l10n.labelDns),
          _field(_allowedIps, l10n.labelAllowedIps),
          _field(_mtu, l10n.labelMtu, keyboard: TextInputType.number),
          _field(
            _keepalive,
            l10n.labelKeepalive,
            keyboard: TextInputType.number,
          ),
          _field(_publicKey, l10n.labelServerPublicKey),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _privateKey,
                  obscureText: !_showPrivateKey,
                  decoration: InputDecoration(
                    labelText: l10n.labelPrivateKey,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _showPrivateKey ? l10n.hide : l10n.reveal,
                onPressed: () {
                  if (_showPrivateKey) {
                    setState(() => _showPrivateKey = false);
                  } else {
                    _confirmRevealPrivateKey();
                  }
                },
                icon: Icon(
                  _showPrivateKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _presharedKey,
            obscureText: !_showPrivateKey,
            decoration: InputDecoration(
              labelText: l10n.labelPresharedKey,
              border: const OutlineInputBorder(),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
