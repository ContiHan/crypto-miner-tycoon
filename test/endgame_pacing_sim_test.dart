// ignore_for_file: avoid_print
// Long-horizon endgame-pacing sim. THE LAST SATOSHI win is the first era to mine
// a full 21,000,000-BTC supply (lifetimeEarnings reaching the per-era cap). This
// drives the REAL GameLogic whale over a long horizon (coarse step for speed)
// and reports WHEN that first win lands, plus how cumulative-ever climbs, so the
// win pacing can be sanity-checked against the intended multi-day milestone.
import 'package:flutter_test/flutter_test.dart';
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
    g.buyResearch(n.id); // TECH is RP-only; buyResearch enforces the RP budget
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
  test('MEASURE time-to-first-win + cumulative-ever pacing', () async {
    final game = createTestGameLogic(startTimers: false, loadOnStart: false);
    await game.loadGame();
    game.wallet = 100;
    // RP now = class level; an engaged endgame player has a class + full build.
    game.debugSelectClass(BtcClass.corporation);
    game.debugSetClassLevel(BtcClass.corporation, 18);

    const step = 3600; // 1 h/tick (coarse: fast + conservative for pacing)
    const days = 500;
    final totalSteps = days * 86400 ~/ step;

    // Cumulative-ever milestones to time (sats), for a general accrual curve.
    final targets = <double>[2.1e17, 1e18, 3e18, 1e19, 3e19, 1e20, 3e20, 1e21];
    final crossedDay = <double, double>{};
    double? firstWinDay; // when the first era mines a full 21M supply

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
      if (firstWinDay == null && game.hasWonGame) firstWinDay = t / 86400.0;
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
    print('THE LAST SATOSHI win  : ${d(firstWinDay)} '
        '(first era to mine the full 21M supply)');
    print('==========================================================\n');

    // Measurement tool only (no pacing assertion — pacing is play-pattern
    // dependent). Kept skipped; run explicitly when tuning the endgame.
    expect(game.lifetimeEverSats, greaterThan(0));
  }, skip: 'slow manual measurement — run explicitly when tuning the endgame');
}
