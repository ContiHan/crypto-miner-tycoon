import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  group('Halving progress bar (bug #6)', () {
    test('resets to 0 at the start of each interval instead of sticking high',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // First interval: [0, 5000).
      game.blocksMined = 0;
      game.nextHalvingThreshold = 5000;
      expect(game.halvingProgress, 0.0);

      game.blocksMined = 2500;
      expect(game.halvingProgress, closeTo(0.5, 0.001));

      // Immediately after the first halving: 5000 mined, next threshold 15000.
      // The old formula (blocksMined / threshold) showed 33% here.
      game.blocksMined = 5000;
      game.nextHalvingThreshold = 15000;
      expect(
        game.halvingProgress,
        0.0,
        reason: 'bar must restart at 0 for the new interval',
      );

      game.blocksMined = 10000;
      expect(game.halvingProgress, closeTo(0.5, 0.001));
    });
  });

  group('Hard-fork multiplier preview (bug #6)', () {
    test('projected multiplier includes claimed and retained spent tokens',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.govTokens = 2;
      game.spentGovTokens = 10;
      game.lifetimeEarnings = 90000; // pending = floor(sqrt(90000/10000)) = 3

      expect(game.pendingGovTokens, 3);
      // After fork: 1 + (2 held + 3 claimed + 10 spent) * 0.1 = x2.5
      expect(game.prestigeMultiplierAfterHardFork, closeTo(2.5, 0.001));
      // The old dialog dropped spent tokens and could show a DECREASE.
      expect(
        game.prestigeMultiplierAfterHardFork,
        greaterThanOrEqualTo(game.prestigeMultiplier),
      );
    });
  });
}
