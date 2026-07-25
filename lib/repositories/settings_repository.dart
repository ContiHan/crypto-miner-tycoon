import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyHapticsEnabled = 'haptics_enabled';
  static const String _keyShowFiat = 'show_fiat_prices';
  static const String _keyOnboardingComplete = 'onboarding_complete';
  // Per-screen first-visit tips the player has dismissed (e.g. 'tab_skill').
  static const String _keySeenTips = 'seen_tips';

  Future<void> saveSettings({
    required bool soundEnabled,
    required bool showFiatPrices,
    bool hapticsEnabled = true,
    bool onboardingComplete = false,
    List<String> seenTips = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, soundEnabled);
    await prefs.setBool(_keyHapticsEnabled, hapticsEnabled);
    await prefs.setBool(_keyShowFiat, showFiatPrices);
    await prefs.setBool(_keyOnboardingComplete, onboardingComplete);
    await prefs.setStringList(_keySeenTips, seenTips);
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _keySoundEnabled: prefs.getBool(_keySoundEnabled) ?? true,
      _keyHapticsEnabled: prefs.getBool(_keyHapticsEnabled) ?? true,
      _keyShowFiat: prefs.getBool(_keyShowFiat) ?? false,
      _keyOnboardingComplete: prefs.getBool(_keyOnboardingComplete) ?? false,
      _keySeenTips: prefs.getStringList(_keySeenTips) ?? <String>[],
    };
  }
}
