// ignore_for_file: avoid_print
// Long-horizon endgame-pacing sim. The full_economy_sim runs 60 days; the "own
// all Bitcoin" ending is meant to take ~1 YEAR of engaged play, which that
// window can't measure. This drives the REAL GameLogic whale far longer (coarse
// step for speed) and reports WHEN cumulative-ever crosses candidate win
// targets, so GameConstants.endgameTargetSats can be tuned to land ~1 year.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
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
  test('MEASURE cumulative-ever pacing over a long horizon', () async {
    final game = createTestGameLogic(startTimers: false, loadOnStart: false);
    await game.loadGame();
    game.wallet = 100;

    const step = 3600; // 1 h/tick (coarse: fast + conservative for pacing)
    const days = 500;
    final totalSteps = days * 86400 ~/ step;

    // Candidate win targets to time (sats).
    final targets = <double>[2.1e17, 1e18, 3e18, 1e19, 3e19, 1e20, 3e20, 1e21];
    final crossedDay = <double, double>{};

    int lastBuyStep = 0, lastForkStep = 0;

    for (int s = 1; s <= totalSteps; s++) {
      final t = s * step;
      for (int c = 0; c < 15; c++) {
        game.clickMine(playSound: false);
      }
      game.advanceForTest(step.toDouble());

      _buyResearch(game);
      if (_reinvestRigs(game, 400) > 0) lastBuyStep = s;
      _buyPerks(game);

      if (game.pendingConsensus >= 1 && game.pendingConsensus >= game.consensus) {
        game.softFork();
      }
      final stalled = (s - lastBuyStep) * step > 1200 &&
          (s - lastForkStep) * step > 1200;
      if (stalled) {
        if (game.pendingGenesis >= 1 &&
            game.pendingGenesis >=
                (game.genesisBlocks < 1 ? 1 : game.genesisBlocks)) {
          game.newBlockchain();
          lastBuyStep = s;
          lastForkStep = s;
        } else if (game.pendingGovTokens >= 1) {
          game.hardFork();
          lastBuyStep = s;
          lastForkStep = s;
        }
      }

      for (final target in targets) {
        if (!crossedDay.containsKey(target) &&
            game.lifetimeEverSats >= target) {
          crossedDay[target] = t / 86400.0;
        }
      }
    }

    String d(double? day) =>
        day == null ? 'never (>$days d)' : '${day.toStringAsFixed(1)} d';

    print('\n===== ENDGAME PACING (whale, $days d @ ${step}s step) =====');
    for (final target in targets) {
      print('${target.toStringAsExponential(1).padRight(9)} sats  '
          '(${(target / 1e8 / 21e6).toStringAsFixed(0)}x the 21M supply)'
          '  ->  ${d(crossedDay[target])}');
    }
    print('final cumulative-ever : ${game.lifetimeEverSats.toStringAsExponential(2)} sats');
    print('current target        : ${GameConstants.endgameTargetSats.toStringAsExponential(1)} '
        '-> crossed ${d(crossedDay[GameConstants.endgameTargetSats])}');
    print('==========================================================\n');

    // Measurement tool only (no pacing assertion — pacing is play-pattern
    // dependent; endgameTargetSats is a documented [TUNE]).
    expect(game.lifetimeEverSats, greaterThan(0));
  }, skip: 'slow manual measurement — run explicitly when tuning the endgame');
}
