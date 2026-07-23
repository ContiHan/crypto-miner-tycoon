import 'package:flutter_test/flutter_test.dart';
import 'test_helper.dart';

void main() {
  group('Halving progress bar (bug #6)', () {
    test('resets to 0 at the start of each interval instead of sticking high',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // First interval: [0, 15000) (thresholds now double each halving).
      game.blocksMined = 0;
      game.nextHalvingThreshold = 15000;
      expect(game.halvingProgress, 0.0);

      game.blocksMined = 7500;
      expect(game.halvingProgress, closeTo(0.5, 0.001));

      // Immediately after the first halving: 15000 mined, threshold doubled to
      // 30000. The old formula (blocksMined / threshold) showed 50% here.
      game.blocksMined = 15000;
      game.nextHalvingThreshold = 30000;
      expect(
        game.halvingProgress,
        0.0,
        reason: 'bar must restart at 0 for the new interval',
      );

      game.blocksMined = 22500;
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
      game.lifetimeEarnings = 4.5e9; // pending = floor(sqrt(4.5e9 / 5e8)) = 3

      expect(game.pendingGovTokens, 3);
      // Concave: after fork 1 + 0.5*sqrt(2 held + 3 claimed + 10 spent)
      //          = 1 + 0.5*sqrt(15) = x2.9365
      expect(game.prestigeMultiplierAfterHardFork, closeTo(2.9365, 0.001));
      // The old dialog dropped spent tokens and could show a DECREASE.
      expect(
        game.prestigeMultiplierAfterHardFork,
        greaterThanOrEqualTo(game.prestigeMultiplier),
      );
    });
  });
}
