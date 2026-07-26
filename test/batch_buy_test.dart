import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
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

  group('progressive rig unlock (milestones since the last rig)', () {
    test('start with only the first rig; buying it (own +1) reveals the GPU, and '
        'each next rig is measured SINCE the last reveal (no cascade)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;

      expect(game.visibleRigs.map((r) => r.id).toList(), [RigIds.cpuRig],
          reason: 'a fresh game shows only the first rig');

      // Buy 4 rigs at once: the GPU (+1) reveals and re-baselines, so the ASIC
      // (+3 SINCE the GPU) still needs 3 more — a bulk buy can't skip ahead.
      game.buyRigMax(RigIds.cpuRig, 4);
      final ids = game.visibleRigs.map((r) => r.id);
      expect(ids.contains(RigIds.gpuRig), true);
      expect(ids.contains(RigIds.asicRig), false,
          reason: 'ASIC is +3 rigs SINCE the GPU snapshot, not an absolute total');

      game.buyRigMax(RigIds.cpuRig, 3); // 3 more since the GPU reveal
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.asicRig), true);
    });

    test('ordered: a later rig cannot reveal before its predecessor even if its '
        'own dimension is already satisfied (no pre-satisfaction)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.chips = 1000;

      game.buyCrate(CrateTier.scrap); // QUANTUM's dimension (a crate) satisfied early
      game.buyRig(RigIds.cpuRig); // reveals only the GPU

      final ids = game.visibleRigs.map((r) => r.id);
      expect(ids.contains(RigIds.gpuRig), true);
      expect(ids.contains(RigIds.quantumRig), false,
          reason: 'QUANTUM is ordered behind ASIC / Mining Farm — a crate opened '
              'early must not skip it');
    });

    test('a Hard Fork re-progresses rig reveals from the first rig', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyRigMax(RigIds.cpuRig, 20); // reveal several rigs
      expect(game.visibleRigs.length, greaterThan(1));

      game.lifetimeEarnings = 2e9; // enough to mint GovTokens
      game.hardFork();
      expect(game.visibleRigs.map((r) => r.id).toList(), [RigIds.cpuRig],
          reason: 'rigs reset on a Hard Fork, so progression restarts');
    });

    test('an owned rig always stays visible', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyRigMax(RigIds.cpuRig, 1); // reveals the GPU
      game.buyRig(RigIds.gpuRig); // own one
      expect(game.visibleRigs.map((r) => r.id).contains(RigIds.gpuRig), true);
    });
  });
}
