import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';
import 'fakes.dart';

void main() {
  group('Progressive disclosure (locked nav tabs)', () {
    test('all gated tabs start locked on a fresh game', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.unlockedTech, false);
      expect(game.unlockedStash, false);
      expect(game.unlockedSkill, false);
    });

    test('reaching 10k sats mined unlocks TECH (with a toast)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;
      game.buyRig('cpu_rig'); // a rig alone no longer unlocks TECH
      expect(game.unlockedTech, false, reason: 'not just for owning a rig');
      game.lifetimeEarnings = 10000;
      game.clickMine(playSound: false); // triggers the unlock refresh
      expect(game.unlockedTech, true);
      expect(game.pendingTabUnlockToasts, contains('TECH'));
    });

    test('reaching 1M sats unlocks STASH', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false); // triggers the unlock refresh
      expect(game.unlockedStash, true);
    });

    test('the first Hard Fork unlocks SKILL', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e9; // sqrt(2e9/5e8)=2 GovTokens
      game.hardFork();
      expect(game.unlockedSkill, true);
    });

    test('unlocks are STICKY — an era reset never re-locks TECH', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 10000;
      game.clickMine(playSound: false);
      expect(game.unlockedTech, true);

      // Simulate a prestige wiping era earnings; a later refresh must NOT re-lock.
      game.lifetimeEarnings = 0;
      game.clickMine(playSound: false); // runs _refreshTabUnlocks again
      expect(game.unlockedTech, true, reason: 'sticky: never re-locks');
    });

    test('a full Wipe Save re-locks every gated tab', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.unlockedTech = true;
      game.unlockedStash = true;
      game.unlockedSkill = true;
      await game.resetGame();
      expect(game.unlockedTech, false);
      expect(game.unlockedStash, false);
      expect(game.unlockedSkill, false);
    });

    test('unlock flags survive a save/reload and grandfather silently',
        () async {
      final repo = FakeGameRepository();
      final settings = FakeSettingsRepository();
      GameLogic make() => GameLogic(
            gameRepository: repo,
            settingsRepository: settings,
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
          )..clickRng = NoCritRandom();

      final g1 = make();
      await g1.loadGame();
      g1.lifetimeEarnings = 10000;
      g1.wallet = 1e6;
      g1.buyRig('cpu_rig'); // buy triggers a refresh (earnings gate met) + saves

      final g2 = make();
      await g2.loadGame();
      expect(g2.unlockedTech, true);
      // Grandfathered silently on load — no toast spam for a returning player.
      expect(g2.pendingTabUnlockToasts, isEmpty);
    });
  });
}
