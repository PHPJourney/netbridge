import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_flags.dart';

/// Locale preference: follow system, or force zh / en.
enum AppLocaleMode {
  system,
  zh,
  en;

  static AppLocaleMode parse(String? raw) => switch (raw) {
        'zh' => AppLocaleMode.zh,
        'en' => AppLocaleMode.en,
        _ => AppLocaleMode.system,
      };

  String get storageValue => switch (this) {
        AppLocaleMode.system => 'system',
        AppLocaleMode.zh => 'zh',
        AppLocaleMode.en => 'en',
      };
}

class SettingsStore {
  static const killSwitchKey = 'nbvpn.killSwitch';
  static const killSwitchPromptedKey = 'nbvpn.killSwitch.prompted';
  static const localeModeKey = 'nbvpn.localeMode';
  static const excludePrivateNetworksKey = 'nbvpn.splitTunnel.excludePrivate';
  static const domesticDirectKey = 'nbvpn.splitTunnel.domesticDirect';
  static const leakProtectionKey = 'nbvpn.leakProtection';
  static const whitelistEntriesKey = 'nbvpn.whitelist.entries';

  Future<bool> getKillSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    // Default ON per FR-C09.
    return prefs.getBool(killSwitchKey) ?? true;
  }

  Future<void> setKillSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(killSwitchKey, value);
  }

  Future<bool> wasKillSwitchPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(killSwitchPromptedKey) ?? false;
  }

  Future<void> markKillSwitchPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(killSwitchPromptedKey, true);
  }

  Future<AppLocaleMode> getLocaleMode() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLocaleMode.parse(prefs.getString(localeModeKey));
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeModeKey, mode.storageValue);
  }

  /// Automatic split tunnel: rewrite `0.0.0.0/0` / `::/0` to exclude-private CIDRs.
  Future<bool> getExcludePrivateNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(excludePrivateNetworksKey) ??
        BuildFlags.defaultExcludePrivateNetworks;
  }

  Future<void> setExcludePrivateNetworks(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(excludePrivateNetworksKey, value);
  }

  /// Domestic-direct split tunnel: bypass China CIDRs so mainland sites go
  /// direct (kept out of the encrypted tunnel). Default off (full tunnel).
  Future<bool> getDomesticDirect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(domesticDirectKey) ?? false;
  }

  Future<void> setDomesticDirect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(domesticDirectKey, value);
  }

  /// IP leak protection: force full tunnel + kill-switch intent on connect.
  Future<bool> getLeakProtection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(leakProtectionKey) ??
        BuildFlags.defaultLeakProtection;
  }

  Future<void> setLeakProtection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(leakProtectionKey, value);
  }

  /// Whitelist entries: IPv4 CIDRs (applied) and/or domains (stored, future DNS).
  Future<List<String>> getWhitelistEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(whitelistEntriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setWhitelistEntries(List<String> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = entries
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await prefs.setString(whitelistEntriesKey, jsonEncode(cleaned));
  }
}
