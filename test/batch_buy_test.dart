import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

void main() {
  group('buyRigMax (hold-to-buy batch)', () {
    test('buys the whole batch when affordable', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000000;

      final bought = game.buyRigMax(RigIds.cpuRig, 10);

      expect(bought, 10);
      expect(game.rigs.firstWhere((r) => r.id == RigIds.cpuRig).amount, 10);
    });

    test('stops when funds run out and returns the count actually bought',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // CPU rig: 100 sats, then +15% each (100, 115, 132.25, ...).
      // 250 covers two (100 + 115 = 215) but not a third.
      game.wallet = 250;

      final bought = game.buyRigMax(RigIds.cpuRig, 100);

      expect(bought, 2);
      expect(game.rigs.firstWhere((r) => r.id == RigIds.cpuRig).amount, 2);
      expect(game.wallet, closeTo(35, 0.5));
    });

    test('requesting zero (or a negative) buys nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000;

      expect(game.buyRigMax(RigIds.cpuRig, 0), 0);
      expect(game.rigs.firstWhere((r) => r.id == RigIds.cpuRig).amount, 0);
      expect(game.wallet, 1000);
    });

    test('a single tap (buyRig) still buys exactly one', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000;

      game.buyRig(RigIds.cpuRig);

      expect(game.rigs.firstWhere((r) => r.id == RigIds.cpuRig).amount, 1);
    });
  });
}
