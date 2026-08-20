// TECH V2 Slice 3 — bespoke branch-B synergy mechanics:
//   B6 GOLDEN NONCE PROTOCOL — a bounded pity timer: every Nth real tap is a
//      guaranteed golden nonce (crit) on top of the luck-driven roll.
//   B5 AI CO-PILOT — tightens the silent auto-tap interval (5 ticks -> 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'test_helper.dart';

void main() {
  group('B6 — Golden Nonce Protocol (guaranteed golden nonce pity timer)', () {
    test('every 12th real tap is a guaranteed crit; the taps before it are not',
        () async {
      // createTestGameLogic wires NoCritRandom, so a natural crit never fires —
      // any crit here is the pity timer.
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyRig(RigIds.cpuRig); // give a tap a base value
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.goldenNonceProtocol)
          .isCompleted = true;

      var crits = 0;
      for (var i = 1; i <= GameConstants.goldenNonceEvery; i++) {
        final crit = game.clickMine().isCrit;
        if (crit) crits++;
        if (i < GameConstants.goldenNonceEvery) {
          expect(crit, false,
              reason: 'tap $i: no natural crit and the pity timer is not due yet');
        }
      }
      expect(crits, 1, reason: 'exactly the 12th tap is the guaranteed golden nonce');

      // The counter reset — the next guaranteed crit is a full cycle later.
      for (var i = 1; i < GameConstants.goldenNonceEvery; i++) {
        expect(game.clickMine().isCrit, false);
      }
      expect(game.clickMine().isCrit, true, reason: 'pity timer re-armed');
    });

    test('without the node, NoCritRandom taps never crit', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyRig(RigIds.cpuRig);
      var crits = 0;
      for (var i = 0; i < 30; i++) {
        if (game.clickMine().isCrit) crits++;
      }
      expect(crits, 0, reason: 'no pity timer without Golden Nonce Protocol');
    });
  });

  group('B5 — AI Co-Pilot (faster auto-tap interval)', () {
    // With NO rigs, a tick does nothing but run the silent auto-clicker (the
    // mine path returns early on zero hash), so the wallet delta counts auto-taps.
    Future<GameLogic> withAuto({required bool coPilot}) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.aiManager)
          .isCompleted = true; // the base auto-clicker
      if (coPilot) {
        game.researchNodes
            .firstWhere((n) => n.id == ResearchIds.aiCoPilot)
            .isCompleted = true;
      }
      return game;
    }

    test('co-pilot fires more auto-taps over the same ticks', () async {
      final base = await withAuto(coPilot: false); // every 5 ticks
      final fast = await withAuto(coPilot: true); // every 3 ticks
      for (var i = 0; i < 15; i++) {
        base.debugTick();
        fast.debugTick();
      }
      // 15/5 = 3 base auto-taps vs 15/3 = 5 fast auto-taps.
      expect(base.wallet, greaterThan(0), reason: 'base auto-clicker fires');
      expect(fast.wallet, greaterThan(base.wallet),
          reason: 'a tighter interval means more auto-taps and more sats');
    });

    test('no auto-clicker at all before AI Manager is researched', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      for (var i = 0; i < 15; i++) {
        game.debugTick();
      }
      expect(game.wallet, 0, reason: 'no auto-taps without the AI Manager node');
    });
  });

  group('A7 — Reinvestment Engine (hash -> income synergy)', () {
    void own(GameLogic g, String id) =>
        g.researchNodes.firstWhere((n) => n.id == id).isCompleted = true;

    test('income gains a fraction of the hash bonus once the node is owned',
        () async {
      final game = createTestGameLogic(loadOnStart: false); // neutral, no racials
      await game.loadGame();

      // A hash node alone never touches the income channel.
      own(game, ResearchIds.basicOverclock); // hash +0.15
      expect(game.buildChannels().sum(Channel.income), closeTo(0.0, 1e-9));

      // Reinvestment Engine folds 20% of the hash sum (0.15) into income.
      own(game, ResearchIds.reinvestmentEngine);
      expect(game.buildChannels().sum(Channel.income),
          closeTo(GameConstants.reinvestFraction * 0.15, 1e-9));
    });

    test('the reinvested income scales with hash and stays under its cap',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      own(game, ResearchIds.reinvestmentEngine);

      own(game, ResearchIds.basicOverclock); // hash +0.15
      final one = game.buildChannels().sum(Channel.income);
      expect(one, closeTo(GameConstants.reinvestFraction * 0.15, 1e-9));

      own(game, ResearchIds.neuralNet); // hash +0.30 (sum 0.45)
      final two = game.buildChannels().sum(Channel.income);
      expect(two, greaterThan(one), reason: 'more hash → more reinvested income');
      expect(two, closeTo(GameConstants.reinvestFraction * 0.45, 1e-9));

      // Always bounded by the divergence rail.
      expect(game.buildChannels().sum(Channel.income),
          lessThanOrEqualTo(GameConstants.reinvestIncomeCap + 1e-9));
    });
  });

  group('Research-Point budget = base + active class level (cap 20)', () {
    final base = GameConstants.rpTechBaseBonus; // 2

    test('a fresh/class-less state has just the base RP', () async {
      final g = createTestGameLogic(loadOnStart: false);
      await g.loadGame();
      expect(g.rpBudget, base);
    });

    test('RP = base + active class level, capped at base + 18', () async {
      final g = createTestGameLogic(loadOnStart: false);
      await g.loadGame();
      g.debugSelectClass(BtcClass.soloMiner);
      g.debugSetClassLevel(BtcClass.soloMiner, 5);
      expect(g.rpBudget, base + 5);
      g.debugSetClassLevel(BtcClass.soloMiner, 18);
      expect(g.rpBudget, base + 18); // = 20, exactly 2 full branches
      g.debugSetClassLevel(BtcClass.soloMiner, 30); // level itself caps at 18
      expect(g.rpBudget, base + 18);
    });

    test('RP follows the ACTIVE class; switching loads that class\'s level',
        () async {
      final g = createTestGameLogic(loadOnStart: false);
      await g.loadGame();
      g.debugSetClassLevel(BtcClass.soloMiner, 3);
      g.debugSetClassLevel(BtcClass.corporation, 12);
      g.debugSelectClass(BtcClass.soloMiner);
      expect(g.rpBudget, base + 3);
      g.debugSelectClass(BtcClass.corporation);
      expect(g.rpBudget, base + 12, reason: 'switching loaded corp\'s own level');
    });
  });
}
