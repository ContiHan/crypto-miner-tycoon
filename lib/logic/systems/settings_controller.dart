import 'package:flutter/services.dart';

import '../../repositories/settings_repository.dart';

/// Owns the user-preference layer — sound / haptics / fiat-display / onboarding
/// flags, the per-screen seen-tips set, and the typed haptic helpers — none of
/// which touch economy state. Persists through the injected [SettingsRepository];
/// the sound-mute bridge, the currency-toggle click, and notify are injected so
/// this stays free of the SoundService/Provider.
class SettingsController {
  SettingsController({
    required this.repo,
    required this.setMuted,
    required this.playClick,
    required this.notify,
  });

  final SettingsRepository repo;
  final void Function(bool muted) setMuted;
  final void Function() playClick;
  final void Function() notify;

  bool soundEnabled = true;
  bool hapticsEnabled = true; // Vibration feedback toggle (see _haptic)
  bool showFiatPrices = false; // Toggle for "Astronomical" Credit prices
  bool onboardingComplete = false; // first-run coach marks shown once

  // Per-screen first-visit tips already dismissed (e.g. 'tab_skill'). Persisted
  // like [onboardingComplete] so each screen's intro shows only once.
  final Set<String> _seenTips = {};
  bool hasSeenTip(String id) => _seenTips.contains(id);

  // Fire-and-forget haptics that never throw (no platform channel in tests) and
  // honour the user's haptics toggle. Typed by intensity so call sites read
  // clearly: light = taps/buys, medium = unlocks, heavy = prestige/jackpot/crit.
  void _haptic(Future<void> Function() f) {
    if (!hapticsEnabled) return;
    f().catchError((_) {});
  }

  void hapticLight() => _haptic(HapticFeedback.lightImpact);
  void hapticMedium() => _haptic(HapticFeedback.mediumImpact);
  void hapticHeavy() => _haptic(HapticFeedback.heavyImpact);

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    // Bridge the setting to the actual audio player; without this the toggle
    // was purely cosmetic (SoundService.setMuted had no call sites).
    setMuted(!soundEnabled);
    await _persist();
    notify();
  }

  Future<void> toggleHaptics() async {
    hapticsEnabled = !hapticsEnabled;
    if (hapticsEnabled) hapticLight(); // let the user feel it turn on
    await _persist();
    notify();
  }

  Future<void> toggleFiatDisplay() async {
    showFiatPrices = !showFiatPrices;
    playClick(); // light UI click on the currency toggle
    await _persist();
    notify();
  }

  /// Marks the first-run onboarding as seen so it never shows again.
  Future<void> completeOnboarding() async {
    if (onboardingComplete) return;
    onboardingComplete = true;
    await _persist();
    notify();
  }

  /// Marks a per-screen first-visit tip [id] as seen so it never shows again.
  Future<void> markTipSeen(String id) async {
    if (!_seenTips.add(id)) return; // already seen — no write, no rebuild
    await _persist();
    notify();
  }

  Future<void> _persist() => repo.saveSettings(
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
        showFiatPrices: showFiatPrices,
        onboardingComplete: onboardingComplete,
        seenTips: _seenTips.toList(),
      );

  /// Load persisted settings and apply the sound-mute bridge. Called from
  /// GameLogic.loadGame before the game state loads.
  Future<void> load() async {
    final settings = await repo.loadSettings();
    soundEnabled = settings['sound_enabled'] ?? true;
    hapticsEnabled = settings['haptics_enabled'] ?? true;
    showFiatPrices = settings['show_fiat_prices'] ?? false;
    onboardingComplete = settings['onboarding_complete'] ?? false;
    _seenTips
      ..clear()
      ..addAll((settings['seen_tips'] as List?)?.cast<String>() ?? const []);
    setMuted(!soundEnabled);
  }
}
