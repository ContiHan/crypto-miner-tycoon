import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/utils/formatter.dart';

void main() {
  group('Economy V2 Tests', () {
    late GameLogic game;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      game = GameLogic(startTimers: false);
    });

    test('Income Balance Check', () {
      // Setup: Starter Rig (1 Hash), Base Difficulty (100), Reward (50 BTC)
      // Expectation: ~1 Sat per block/click (before perks)

      // Force values to be sure (though defaults should match)
      // We can't easily force private _miningDivisor, but we test the result.

      game.wallet = 0;
      game.clickMine();

      expect(
        game.wallet,
        closeTo(5.0, 0.1),
        reason: "Click (5 Power) should yield 5 Sats at 100 Diff",
      );

      // Test Rig (1 Hash)
      // 1 Hash / 100 Diff = 0.01.
      // 0.01 * 100 = 1 Sat.
      // We can't call _mine() directly publicly easily, but we can verify logic via calculation
      // OR we can rely on internal logic check if we had a public helper.
      // Let's rely on click check as proxy for math validation.
    });

    test('Difficulty Reset Check', () async {
      // Simulate progress
      game.lifetimeEarnings = 1000000; // Adds linear difficulty
      double diffBefore = game.networkDifficulty;
      expect(diffBefore, greaterThan(100.0));

      await game.resetGame();

      // Should be back to base 100
      expect(game.networkDifficulty, 100.0);
    });

    test('Symbol Formatting Check', () {
      expect(Formatter.formatBitcoin(500), '500 Ş');
      expect(Formatter.formatBitcoin(150000000), '1.5 ₿'); // 1.5 BTC
      expect(Formatter.formatBitcoin(0.005), '5.0 mŞ');
    });

    test('Rounding Logic Check', () {
      expect(Formatter.formatNumber(1400), '1.4k');
      expect(Formatter.formatNumber(1450), '1.4k'); // Strict truncation
      expect(Formatter.formatNumber(1499), '1.4k');
      expect(Formatter.formatNumber(1500), '1.5k');
    });
  });
}
