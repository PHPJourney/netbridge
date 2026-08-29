import 'package:flutter/material.dart';

import '../config/brand_links.dart';
import '../l10n/app_localizations.dart';
import '../layout/responsive.dart';
import '../services/settings_store.dart';
import '../services/vpn/vpn_logger.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../utils/open_url.dart';
import '../utils/share_text.dart';
import 'whitelist_screen.dart';

/// C-11: Kill Switch + leak protection + whitelist / About / language.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = isDesktopLayout(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final real = c.supportsRealTunnel;
        final tiles = <Widget>[
          SwitchListTile(
            title: Text(l10n.leakProtectionTitle),
            subtitle: Text(l10n.leakProtectionSubtitle),
            value: c.leakProtection,
            onChanged: (v) => c.setLeakProtection(v),
          ),
          SwitchListTile(
            title: Text(l10n.killSwitch),
            subtitle: Text(
              real
                  ? l10n.killSwitchSubtitleReal
                  : l10n.killSwitchSubtitleStub,
            ),
            value: c.killSwitch,
            onChanged: c.leakProtection
                ? null
                : (v) => c.setKillSwitch(v),
          ),
          SwitchListTile(
            title: Text(l10n.splitTunnelTitle),
            subtitle: Text(
              c.leakProtection
                  ? '${l10n.splitTunnelSubtitle}\n${l10n.leakProtectionVsSplitHint}'
                  : l10n.splitTunnelSubtitle,
            ),
            value: c.excludePrivateNetworks,
            onChanged: c.leakProtection
                ? null
                : (v) => c.setExcludePrivateNetworks(v),
          ),
          ListTile(
            title: Text(l10n.whitelistTitle),
            subtitle: Text(
              c.whitelistEntries.isEmpty
                  ? l10n.whitelistSubtitle
                  : l10n.whitelistCount(c.whitelistEntries.length),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WhitelistScreen(controller: c),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.tunnelCapability),
            subtitle: Text(
              real
                  ? '${c.vpnCapabilityNote}\n${l10n.tunnelAppleLinkedNote}'
                  : '${c.vpnCapabilityNote}\n${l10n.tunnelStubSuffix}',
            ),
            isThreeLine: true,
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.cantConnectTitle),
            subtitle: Text(l10n.cantConnectBody),
            isThreeLine: true,
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.fullTunnelCarTitle),
            subtitle: Text(l10n.fullTunnelCarHint),
            isThreeLine: true,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.language,
              style: const TextStyle(
                color: NbColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppLocaleMode>(
              segments: [
                ButtonSegment(
                  value: AppLocaleMode.system,
                  label: Text(l10n.languageSystem),
                ),
                ButtonSegment(
                  value: AppLocaleMode.zh,
                  label: Text(l10n.languageChinese),
                ),
                ButtonSegment(
                  value: AppLocaleMode.en,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {c.localeMode},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) c.setLocaleMode(s.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.aboutSection,
              style: const TextStyle(
                color: NbColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.versionLabel(BrandLinks.appVersion)),
            subtitle: Text(l10n.responsibilityOneLiner),
            isThreeLine: true,
          ),
          ListTile(
            title: Text(l10n.officialWebsite),
            subtitle: Text(
              BrandLinks.officialSite,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalUrl(context, BrandLinks.officialSite),
          ),
          ListTile(
            title: Text(l10n.termsOfService),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalUrl(context, BrandLinks.termsUrl),
          ),
          ListTile(
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalUrl(context, BrandLinks.privacyUrl),
          ),
          ListTile(
            title: Text(l10n.partnersTitle),
            subtitle: Text(l10n.partnersBody),
          ),
          ListTile(
            title: Text(l10n.diagnosticLogTitle),
            subtitle: Text(l10n.diagnosticLogSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) {
                final d = AppLocalizations.of(ctx);
                return AlertDialog(
                  title: Text(d.diagnosticLogTitle),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        VpnLog.tail(300).isEmpty
                            ? d.diagnosticLogEmpty
                            : VpnLog.tail(300).join('\n'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await VpnLog.clear();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(d.diagnosticLogClear),
                    ),
                    TextButton(
                      onPressed: () async {
                        final text = await VpnLog.readFile();
                        if (!ctx.mounted) return;
                        await shareText(
                          ctx,
                          text.isEmpty ? VpnLog.tail(300).join('\n') : text,
                        );
                      },
                      child: Text(d.diagnosticLogExport),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(d.close),
                    ),
                  ],
                );
              },
            ),
          ),
          ListTile(
            title: Text(l10n.aboutDetails),
            subtitle: Text(l10n.aboutDetailsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) {
                  final d = AppLocalizations.of(ctx);
                  return AlertDialog(
                    title: Text(d.aboutDialogTitle),
                    content: SingleChildScrollView(
                      child: Text(d.aboutBody),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(d.close),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.versionFooter(BrandLinks.appVersion),
              style: const TextStyle(
                color: NbColors.mutedText,
                fontSize: 12,
              ),
            ),
          ),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: desktop
              ? DesktopConstrainedBody(
                  maxWidth: kDesktopContentMaxWidth,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: tiles,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: tiles,
                ),
        );
      },
    );
  }
}
