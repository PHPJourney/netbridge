import 'package:shared_preferences/shared_preferences.dart';

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
}
