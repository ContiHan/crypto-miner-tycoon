import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/content/rig_defs.dart';
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
    test('you start with only the first rig; owning each one reveals the next '
        '(the ownership chain)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      game.wallet = 1e12;

      expect(game.visibleRigs.map((r) => r.id).toList(), [RigIds.cpuRig],
          reason: 'a fresh game shows only the first rig');

      game.buyRig(RigIds.cpuRig); // owning the CPU reveals the GPU
      var ids = game.visibleRigs.map((r) => r.id).toList();
      expect(ids.contains(RigIds.gpuRig), true);
      expect(ids.contains(RigIds.asicRig), false,
          reason: 'the ASIC only reveals once the GPU is owned');

      game.buyRig(RigIds.gpuRig); // owning the GPU reveals the ASIC
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.asicRig), true);
    });

    test('the lifetime-earnings fallback also reveals a rig without owning the '
        'previous', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.gpuRig), false);

      // Reaching the GPU's earnings threshold reveals it even with nothing owned.
      game.lifetimeEarnings = rigUnlockThreshold(RigIds.gpuRig);
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.gpuRig), true);
    });

    test('an owned rig stays visible even below its unlock threshold', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = rigUnlockThreshold(RigIds.fusionRig); // reveal it
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
