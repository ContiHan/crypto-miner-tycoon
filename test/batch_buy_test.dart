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

  group('data-driven rigs unlock progressively', () {
    test('higher rig tiers reveal as lifetime earnings grow', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.lifetimeEarnings = 0;
      var ids = game.visibleRigs.map((r) => r.id).toList();
      expect(ids.contains(RigIds.cpuRig), true);
      expect(ids.contains(RigIds.fusionRig), false, reason: 'fusion gated at 1e6');
      expect(ids.contains(RigIds.datacenterRig), false);

      game.lifetimeEarnings = 2e6;
      ids = game.visibleRigs.map((r) => r.id).toList();
      expect(ids.contains(RigIds.fusionRig), true);
      expect(ids.contains(RigIds.datacenterRig), false, reason: 'datacenter 1e9');

      game.lifetimeEarnings = 2e9;
      ids = game.visibleRigs.map((r) => r.id).toList();
      expect(ids.contains(RigIds.datacenterRig), true);
    });

    test('an owned rig stays visible even below its unlock threshold', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.wallet = 1e12;
      game.buyRig(RigIds.fusionRig); // now owned
      game.lifetimeEarnings = 0; // drop below the gate (e.g. after a reset)
      expect(
        game.visibleRigs.map((r) => r.id).contains(RigIds.fusionRig),
        true,
      );
    });
  });
}
