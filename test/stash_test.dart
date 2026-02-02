import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';

import 'test_helper.dart';

void main() {
  group('Stash System Tests', () {
    late GameLogic game;

    setUp(() {
      game = createTestGameLogic(startTimers: false);
    });

    test('Initial State Check', () {
      expect(game.chips, 0);
      expect(game.stashService.ownedArtifacts, isEmpty);
    });

    test('Trading Tokens for Chips', () {
      // Grant tokens
      game.govTokens = 10000;

      // Buy 1 Chip (Cost 5000)
      game.buyChipsWithTokens();

      expect(game.chips, 1);
      expect(game.govTokens, 5000);
      expect(game.spentGovTokens, 5000);

      // Buy another (Cost 5000)
      game.buyChipsWithTokens();
      expect(game.chips, 2);
      expect(game.govTokens, 0);

      // Try buying with insufficient funds
      game.buyChipsWithTokens();
      expect(game.chips, 2); // Should not change
    });

    test('Opening Crates', () {
      // Grant Chips
      game.chips = 60;

      // Buy Standard Crate (10 Chips)
      game.buyCrate(false);
      expect(game.chips, 50);
      expect(
        game.stashService.ownedArtifacts.values.fold(0, (a, b) => a + b),
        1,
      ); // 1 Item total

      // Buy Premium Crate (50 Chips)
      game.buyCrate(true);
      expect(game.chips, 0);
      expect(
        game.stashService.ownedArtifacts.values.fold(0, (a, b) => a + b),
        greaterThanOrEqualTo(2),
      ); // At least 2 items now

      // Try buying with insufficient funds
      game.buyCrate(false);
      expect(game.chips, 0); // No change
    });

    test('Artifact Bonuses Apply', () async {
      // Mock an artifact in stash
      // Since _ownedArtifacts is private but we have loadStash, we can inject via load

      // Force a specific artifact (id: 'old_hdd', bonus: hashRate)
      // StashService loadStash is async? No, Future<void> in GameLogic?
      // StashService.loadStash is Future<void>.
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 1},
      });

      // Check Bonus
      // Base Hash Rate Bonus for Old HDD is 0.02 (2%)
      // Total Bonus = 1.0 + (0.02 * 1) = 1.02
      expect(game.stashService.getTotalHashBonus(), 1.02);

      // Add another level
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 2},
      });
      expect(game.stashService.getTotalHashBonus(), 1.04);
    });

    test('Anomaly Logic', () {
      expect(game.isAnomalyActive, false);

      // Manually trigger click (simulation)
      game.isAnomalyActive = true;
      game.clickAnomaly();

      expect(game.isAnomalyActive, false);
      expect(game.chips, 1);
    });
  });
}
