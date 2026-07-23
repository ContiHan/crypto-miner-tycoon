import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/content/achievement_defs.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/managers/achievement_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';
import 'test_helper.dart';

void main() {
  group('Achievements', () {
    test('reaching a milestone unlocks it, queues a toast, and adds Notoriety',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.isAchievementUnlocked('earn_1m'), false);

      game.lifetimeEarnings = 2e6; // >= 1e6 threshold
      game.clickMine(playSound: false); // triggers evaluation

      expect(game.isAchievementUnlocked('earn_1m'), true);
      expect(game.pendingAchievementToasts.any((a) => a.id == 'earn_1m'), true);
      expect(game.notorietyBonus, greaterThan(0));
    });

    test('Notoriety is applied to income EXACTLY once (+1% per achievement)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;
      final base = game.estimatedClickValue; // notoriety 1.0
      expect(game.notorietyMultiplier, 1.0);

      // rigs_10 grants +1% and does NOT touch click income (click is not
      // hash-rate based), isolating the notoriety effect.
      game.buyRigMax('cpu_rig', 10);
      expect(game.isAchievementUnlocked('rigs_10'), true);
      expect(game.notorietyMultiplier, closeTo(1.01, 1e-9));

      // A double-applied multiplier would read base*1.0201 and fail here.
      expect(game.estimatedClickValue, closeTo(base * 1.01, base * 1e-6),
          reason: 'income multiplier must be applied once, not compounded');
    });

    test('secret achievements grant NO Notoriety', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.lifetimeEarnings = 2e4; // crosses secret_pizza (1e4), not earn_1m (1e6)
      game.clickMine(playSound: false);

      expect(game.isAchievementUnlocked('secret_pizza'), true);
      expect(game.notorietyBonus, 0.0, reason: 'secret grants no bonus');
    });

    test('unlocked achievements persist across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('earn_1m'), true);

      await game.loadGame(); // same fake repo the save was written to
      expect(game.isAchievementUnlocked('earn_1m'), true);
    });

    test('action counters round-trip across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.lifetimeEarnings = 2e9; // enough for GovTokens
      game.hardFork(); // hardForkCount -> 1
      game.lifetimeEarnings = 1.6e10; // cbrt(8)=2 Consensus available
      game.softFork(); // softForkCount -> 1
      expect(game.hardForkCount, 1);
      expect(game.softForkCount, 1);

      await game.loadGame();
      expect(game.hardForkCount, 1, reason: 'hardForkCount persisted');
      expect(game.softForkCount, 1, reason: 'softForkCount persisted');
    });

    test('achievements survive prestige but a full wipe clears them', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('earn_1m'), true);

      game.lifetimeEarnings = 2e9;
      game.hardFork();
      expect(game.hardForkCount, 1);
      expect(game.isAchievementUnlocked('earn_1m'), true,
          reason: 'achievements persist across prestige');

      await game.resetGame();
      expect(game.isAchievementUnlocked('earn_1m'), false);
      expect(game.hardForkCount, 0);
      expect(game.notorietyBonus, 0.0);
    });

    test('first Hard Fork unlocks its achievement', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e9;
      game.hardFork();
      expect(game.isAchievementUnlocked('hard_first'), true);
    });

    test('loading a satisfied state grandfathers achievements SILENTLY', () async {
      // A save already past a milestone, with no achievements recorded (e.g. a
      // pre-Phase-6 save). Load must unlock it without a toast/sound flood.
      final repo = FakeGameRepository();
      repo.data['lifetimeEarnings'] = 2e6;
      final sound = FakeSoundService();
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: sound,
        startTimers: false,
        loadOnStart: false,
      );

      await game.loadGame();

      expect(game.isAchievementUnlocked('earn_1m'), true);
      expect(game.pendingAchievementToasts, isEmpty,
          reason: 'no toast flood on load');
      expect(sound.unlockCount, 0, reason: 'no unlock-sound spam on load');
    });
  });

  group('AchievementManager', () {
    test('Notoriety is bounded by the non-secret count; secrets are excluded',
        () {
      final m = AchievementManager();
      m.load(kAchievements.map((a) => a.id)); // unlock everything

      final nonSecret = kAchievements.where((a) => !a.secret).length;
      expect(m.unlockedCount, kAchievements.length);
      expect(m.notorietyBonus,
          closeTo(nonSecret * GameConstants.perAchievementNotoriety, 1e-9));
    });
  });
}
