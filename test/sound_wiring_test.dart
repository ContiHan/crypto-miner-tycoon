import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

GameLogic _game(FakeSettingsRepository settings, FakeSoundService sound) =>
    GameLogic(
      gameRepository: FakeGameRepository(),
      settingsRepository: settings,
      economyService: EconomyService(),
      stashService: StashService(),
      soundService: sound,
      startTimers: false,
      loadOnStart: false,
    );

void main() {
  group('Sound settings wiring (bug #1 mute half)', () {
    test('a persisted "sound off" mutes the service on load', () async {
      final settings = FakeSettingsRepository();
      settings.data['sound_enabled'] = false;
      final sound = FakeSoundService();
      final game = _game(settings, sound);

      await game.loadGame();

      expect(
        sound.isMuted,
        true,
        reason: 'the persisted setting must reach SoundService, not just a flag',
      );
    });

    test('toggleSound propagates to the service and persists', () async {
      final settings = FakeSettingsRepository();
      final sound = FakeSoundService();
      final game = _game(settings, sound);
      await game.loadGame();
      expect(sound.isMuted, false, reason: 'sound defaults on');

      await game.toggleSound();

      expect(game.soundEnabled, false);
      expect(sound.isMuted, true);
      final saved = await settings.loadSettings();
      expect(saved['sound_enabled'], false);
    });

    test('a manual click plays; a silent (auto) click does not', () async {
      final sound = FakeSoundService();
      final game = _game(FakeSettingsRepository(), sound);
      await game.loadGame();

      game.clickMine(playSound: false); // AI auto-clicker path
      expect(sound.mineCount, 0, reason: 'auto-click must be silent');

      game.clickMine(); // real tap
      expect(sound.mineCount, 1);
    });
  });
}
