// ignore_for_file: avoid_print
// Per-class balance sim: drives the REAL GameLogic as EACH of the four classes
// over a few sim-weeks and asserts none runs away, dies, or NaNs. The main
// full_economy_sim only exercises Prospector; this guards the Phase-3 class
// weightings that flow through accrual (hash / income / rigCost / luck +
// prestige-gain). NOTE: the VOLATILITY weighting is NOT exercised here — it only
// scales chaos-event frequency, and advanceForTest runs with chaosMultiplier 1.0
// and no event timer, so volatility has no effect on this offline-style sim.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'test_helper.dart';

int _reinvestRigs(GameLogic g, int cap) {
  int bought = 0;
  while (bought < cap) {
    Rig? best;
    double bestRoi = 0;
    for (final r in g.rigs) {
      final cost = g.getRigCostInSats(r);
      if (cost > 0 && cost <= g.wallet) {
        final roi = r.baseHashRate / cost;
        if (roi > bestRoi) {
          bestRoi = roi;
          best = r;
        }
      }
    }
    if (best == null) break;
    g.buyRig(best.id);
    bought++;
  }
  return bought;
}

void _buyResearch(GameLogic g) {
  final buyable = g.researchNodes
      .where((n) => n.isUnlocked && !n.isCompleted)
      .toList()
    ..sort((a, b) => a.cost.compareTo(b.cost));
  for (final n in buyable) {
    if (g.wallet >= g.getResearchCost(n.id)) g.buyResearch(n.id);
  }
}

void _buyPerks(GameLogic g) {
  for (final id in g.perkDefs.keys) {
    if (!g.isPerkUnlocked(id) || g.isPerkMaxed(id)) continue;
    var guard = 0;
    while (guard++ < 50 && (g.perkCosts[id] ?? 1 << 30) <= g.govTokens) {
      g.buyPerk(id);
      if (g.isPerkMaxed(id)) break;
    }
  }
}

void main() {
  const classes = [
    BtcClass.soloMiner,
    BtcClass.corporation,
    BtcClass.btcOg,
    BtcClass.poolMember,
  ];

  for (final cls in classes) {
    test('class ${cls.name} stays balanced (bounded, alive, progresses)',
        () async {
      final game = createTestGameLogic(startTimers: false, loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(cls); // play the whole run as this class
      game.wallet = 100;

      const step = 240; // seconds/tick (coarser than full_economy_sim for speed)
      const days = 20;
      final totalSteps = days * 86400 ~/ step;

      bool sawBad = false;
      double peakIncome = 0;
      double maxMult = 1.0;
      int firstHardFork = -1;
      int softForks = 0, hardForks = 0;
      int lastBuyStep = 0, lastForkStep = 0;
      bool bad(double v) => v.isNaN || v.isInfinite;

      for (int s = 1; s <= totalSteps; s++) {
        final t = s * step;
        for (int c = 0; c < 10; c++) {
          game.clickMine(playSound: false);
        }
        final earned = game.advanceForTest(step.toDouble());
        final perSec = earned / step;
        if (perSec > peakIncome) peakIncome = perSec;
        if (bad(game.wallet) ||
            bad(game.globalHashRate) ||
            bad(game.prestigeMultiplier) ||
            bad(earned)) {
          sawBad = true;
        }
        _buyResearch(game);
        if (_reinvestRigs(game, 200) > 0) lastBuyStep = s;
        _buyPerks(game);
        if (game.prestigeMultiplier > maxMult) maxMult = game.prestigeMultiplier;

        if (game.pendingConsensus >= 1 &&
            game.pendingConsensus >= game.consensus) {
          game.softFork();
          softForks++;
        }
        final stalled = (s - lastBuyStep) * step > 600 &&
            (s - lastForkStep) * step > 600;
        if (stalled && game.pendingGovTokens >= 1) {
          game.hardFork();
          hardForks++;
          if (firstHardFork < 0) firstHardFork = t;
          lastForkStep = s;
          lastBuyStep = s;
        }
      }

      final hashX = game.buildChannels().multiplier(Channel.hash);
      print('CLASS ${cls.name}: HF=$hardForks SF=$softForks '
          'firstHF=${firstHardFork}s peakInc=${peakIncome.toStringAsExponential(2)} '
          'maxMult=${maxMult.toStringAsFixed(1)} hashX=${hashX.toStringAsFixed(2)}');

      expect(sawBad, false, reason: '${cls.name}: no NaN/Infinity');
      expect(game.wallet, greaterThanOrEqualTo(0));
      expect(maxMult, lessThan(1e5),
          reason: '${cls.name}: prestige multiplier stayed bounded (no runaway)');
      expect(peakIncome, greaterThan(0),
          reason: '${cls.name}: the economy produces income (not dead)');
      expect(firstHardFork, greaterThan(0),
          reason: '${cls.name}: reaches a Hard Fork within $days days');
    });
  }
}
