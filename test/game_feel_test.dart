import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'fakes.dart';
import 'test_helper.dart';

void main() {
  group('Critical taps', () {
    test('a crit pays clickCritMultiplier x the estimate and flags isCrit',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;

      game.clickRng = AlwaysCritRandom();
      final est = game.estimatedClickValue; // non-crit expectation at this state
      final crit = game.clickMine();
      expect(crit.isCrit, true);
      expect(crit.sats,
          closeTo(est * GameConstants.clickCritMultiplier, est * 1e-6),
          reason: 'crit multiplies the click payout');
    });

    test('a non-crit tap pays the plain estimate', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;

      game.clickRng = NoCritRandom();
      final est = game.estimatedClickValue;
      final r = game.clickMine();
      expect(r.isCrit, false);
      expect(r.sats, closeTo(est, est * 1e-6));
    });

    test('the silent auto-clicker (playSound:false) never crits', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.clickRng = AlwaysCritRandom(); // would crit if it rolled
      final r = game.clickMine(playSound: false);
      expect(r.isCrit, false, reason: 'auto-clicker must not secretly pump');
    });

    test('a crit near the supply cap cannot overshoot maxSupplySats', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Sit one sat below the per-era cap so a full tap would blow past it.
      game.lifetimeEarnings = GameConstants.maxSupplySats - 1;
      game.clickRng = AlwaysCritRandom();
      final r = game.clickMine();
      // No overshoot: a crit must re-clamp to remaining supply, exactly like the
      // passive path. (Landing at the cap flips difficulty to Infinity — that is
      // documented existing at-cap behaviour, not what this test guards.)
      expect(game.lifetimeEarnings,
          lessThanOrEqualTo(GameConstants.maxSupplySats),
          reason: 'crit must re-clamp to remaining supply');
      expect(r.sats, lessThanOrEqualTo(1.0 + 1e-3));
    });

    test('estimatedClickValue is unaffected by crits (stays the base value)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;
      final before = game.estimatedClickValue;
      game.clickRng = AlwaysCritRandom();
      game.clickMine();
      // The readout must not itself jump 5x — it advertises a normal tap.
      expect(game.estimatedClickValue, closeTo(before, before * 1e-3));
    });
  });

  group('Haptics setting', () {
    test('defaults on and persists across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.hapticsEnabled, true);

      await game.toggleHaptics();
      expect(game.hapticsEnabled, false);

      await game.loadGame(); // same fake settings repo
      expect(game.hapticsEnabled, false, reason: 'toggle persists');
    });
  });
}
