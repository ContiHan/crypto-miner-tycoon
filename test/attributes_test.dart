import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'test_helper.dart';

/// Phase-0 attribute foundation (ATTRIBUTES_AND_ABILITIES / BUILD_DEPTH):
/// OFFLINE YIELD, BLOCK REWARD (crit payout), CONSENSUS WEIGHT, PROSPECTOR'S EYE.
void main() {
  group('OFFLINE YIELD attribute', () {
    test('fresh Prospector earns the 0.70 base fraction offline', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.offlineFraction, closeTo(GameConstants.offlineBaseFraction, 1e-9));
      expect(game.offlineFraction, closeTo(0.70, 1e-9));
    });

    test('BTC OG racial adds +0.10 offline', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.btcOg);
      expect(game.offlineFraction, closeTo(0.80, 1e-9));
    });

    test('offline TECH nodes raise the fraction and it hard-caps at 1.0', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.autonomousDaemons)
          .isCompleted = true; // +0.15 -> 0.85
      expect(game.offlineFraction, closeTo(0.85, 1e-9));
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.miningDaemonSwarm)
          .isCompleted = true; // +0.15 -> 1.00
      expect(game.offlineFraction, closeTo(1.0, 1e-9));
      // OG on top would be 1.10 -> clamped to 1.0 (never out-earns live).
      game.debugSelectClass(BtcClass.btcOg);
      expect(game.offlineFraction, closeTo(1.0, 1e-9));
    });

    test('offline accrual is scaled by offlineFraction vs the live rate', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 100;

      // Live baseline (yieldFactor 1.0), then rewind the era so the second
      // accrual sees the same room/rate.
      final live = game.advanceForTest(10);
      game.lifetimeEarnings = 0;
      final offline = game.advanceForTest(10, yieldFactor: game.offlineFraction);

      expect(live, greaterThan(0));
      expect(offline, closeTo(live * game.offlineFraction, live * 1e-6));
      expect(game.offlineFraction, closeTo(0.70, 1e-9)); // Prospector base
    });
  });
}
