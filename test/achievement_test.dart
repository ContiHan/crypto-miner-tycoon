import 'package:flutter_test/flutter_test.dart';
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

    test('Notoriety is a bounded income multiplier (>1 once earned)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final base = game.estimatedClickValue;
      expect(game.notorietyMultiplier, 1.0);

      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);

      // earn_1m (normal, +1%) unlocked; secret_pizza (also crossed, secret) adds 0.
      expect(game.notorietyMultiplier, closeTo(1.01, 1e-9));
      expect(game.estimatedClickValue, greaterThan(base));
    });

    test('secret achievements grant NO Notoriety', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.lifetimeEarnings = 2e4; // crosses secret_pizza (1e4), not earn_1m (1e6)
      game.clickMine(playSound: false);

      expect(game.isAchievementUnlocked('secret_pizza'), true);
      expect(game.notorietyBonus, 0.0, reason: 'secret grants no bonus');
    });

    test('unlocked achievements and counters persist across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('earn_1m'), true);

      await game.loadGame(); // same fake repo the save was written to
      expect(game.isAchievementUnlocked('earn_1m'), true);
    });

    test('achievements survive prestige but a full wipe clears them', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('earn_1m'), true);

      // Hard fork: achievements are permanent (like the Stash).
      game.lifetimeEarnings = 2e9; // enough for GovTokens
      game.hardFork();
      expect(game.hardForkCount, 1);
      expect(game.isAchievementUnlocked('earn_1m'), true,
          reason: 'achievements persist across prestige');

      // Full wipe clears everything.
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
  });
}
