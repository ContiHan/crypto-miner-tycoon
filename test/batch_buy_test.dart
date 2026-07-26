import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/content/rig_defs.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
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
    test('start with only the first rig; the GPU reveals after owning the CPU '
        'rig, but the ASIC needs its own (own-15-rigs) condition', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      game.wallet = 1e12;

      expect(game.visibleRigs.map((r) => r.id).toList(), [RigIds.cpuRig],
          reason: 'a fresh game shows only the first rig');

      game.buyRig(RigIds.cpuRig); // GPU condition = own your first rig
      final ids = game.visibleRigs.map((r) => r.id).toList();
      expect(ids.contains(RigIds.gpuRig), true);
      expect(ids.contains(RigIds.asicRig), false,
          reason: 'ASIC has its OWN condition (own 15 rigs), not "own the GPU"');
    });

    test('varied conditions: ASIC needs 15 rigs, QUANTUM needs a crate opened '
        '(ordered)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      game.wallet = 1e12;

      game.buyRigMax(RigIds.cpuRig, 15); // own 15 rigs total
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.asicRig), true,
          reason: 'ASIC reveals at 15 rigs owned');
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.quantumRig), false,
          reason: 'QUANTUM still needs a crate opened');

      game.chips = 100;
      game.buyCrate(CrateTier.scrap); // cratesOpened -> 1
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.quantumRig), true,
          reason: 'opening a crate reveals QUANTUM');
    });

    test('the lifetime-earnings fallback reveals rigs for a pure miner', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.gpuRig), false);

      // Reaching the GPU's earnings threshold reveals it with nothing owned.
      game.lifetimeEarnings = rigUnlockThreshold(RigIds.gpuRig);
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.gpuRig), true);
    });

    test('a rig unlocked by a TRANSIENT condition stays revealed after it passes '
        '(sticky latch)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      // Reveal up to fusion's predecessor via earnings, then satisfy fusion's
      // transient UTXO condition and let an evaluation latch it.
      game.lifetimeEarnings = rigUnlockThreshold(RigIds.quantumRig);
      game.chips = 30; // fusion condition = hold >= 25 UTXO (transient)
      game.clickMine(playSound: false); // triggers _evaluateAchievements -> latch
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.fusionRig), true);

      game.chips = 0; // spend it all — the reveal must persist
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.fusionRig), true,
          reason: 'a latched rig stays revealed after the transient condition ends');
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
