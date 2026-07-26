// ignore_for_file: avoid_print
// Full-economy simulation: drives the REAL GameLogic (mining tick + channel
// bonuses + research/perk purchases + all three prestige tiers) over weeks of
// simulated time, so it validates the WHOLE economy an engaged player actually
// experiences — not just the bare prestige loop. Complements
// prestige_loop_sim_test.dart (which omits research/perk/stash content).
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'test_helper.dart';

String _hms(int s) {
  if (s < 0) return 'never';
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  final p = <String>[];
  if (d > 0) p.add('${d}d');
  if (h > 0) p.add('${h}h');
  if (m > 0 || p.isEmpty) p.add('${m}m');
  return p.join(' ');
}

// Greedy: buy the best hash-per-sat rig that is unlocked & affordable, capped.
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
  // Spend spare GovTokens on the cheapest available perk upgrades.
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
  test('full-economy sim (real GameLogic, engaged player) stays healthy',
      () async {
    final game = createTestGameLogic(startTimers: false, loadOnStart: false);
    await game.loadGame();
    game.wallet = 100; // bootstrap: the player taps to afford the first CPU rig
    // An engaged player commits to a class early; its skill tree feeds the sim.
    game.debugSelectClass(BtcClass.corporation);

    const step = 120; // seconds per tick
    const days = 60;
    final totalSteps = days * 86400 ~/ step;

    int firstHardFork = -1, firstNewChain = -1, firstWin = -1;
    int softForks = 0, hardForks = 0, newChains = 0;
    int lastBuyStep = 0, lastForkStep = 0;
    bool sawBad = false;
    double peakIncome = 0;
    int maxResearched = 0;
    double maxHashX = 1.0;
    double maxMult = 1.0;
    final snaps = <String>[];
    final snapAtDays = {1, 3, 7, 14, 21, 30, 45, 60};

    bool bad(double v) => v.isNaN || v.isInfinite;

    for (int s = 1; s <= totalSteps; s++) {
      final t = s * step;

      // Active taps: a handful per tick. Negligible once rigs dominate, but they
      // bootstrap the first rig AND rebuild after a prestige wipes wallet+rigs
      // (exactly what a real player does — tap to get going again).
      for (int c = 0; c < 15; c++) {
        game.clickMine(playSound: false);
      }

      final earned = game.advanceForTest(step.toDouble());
      final perSec = earned / step;
      if (perSec > peakIncome) peakIncome = perSec;
      if (firstWin < 0 && game.hasWonGame) firstWin = t;

      if (bad(game.wallet) ||
          bad(game.globalHashRate) ||
          bad(game.prestigeMultiplier) ||
          bad(earned)) {
        sawBad = true;
      }

      // Re-tech (cheap first) before sinking the rest into rigs.
      _buyResearch(game);
      if (_reinvestRigs(game, 400) > 0) lastBuyStep = s;
      _buyPerks(game);

      final rc = game.researchNodes.where((n) => n.isCompleted).length;
      if (rc > maxResearched) maxResearched = rc;
      final hx = game.buildChannels().multiplier(Channel.hash);
      if (hx > maxHashX) maxHashX = hx;
      if (game.prestigeMultiplier > maxMult) maxMult = game.prestigeMultiplier;

      // Tier 1: soft fork when Consensus would at least double.
      if (game.pendingConsensus >= 1 && game.pendingConsensus >= game.consensus) {
        game.softFork();
        softForks++;
      }

      // Tiers 2/3 on a soft-wall stall.
      final stalled = (s - lastBuyStep) * step > 600 &&
          (s - lastForkStep) * step > 600;
      if (stalled) {
        if (game.pendingGenesis >= 1 &&
            game.pendingGenesis >= (game.genesisBlocks < 1 ? 1 : game.genesisBlocks)) {
          game.newBlockchain();
          newChains++;
          if (firstNewChain < 0) firstNewChain = t;
          lastBuyStep = s;
          lastForkStep = s;
        } else if (game.pendingGovTokens >= 1) {
          game.hardFork();
          hardForks++;
          if (firstHardFork < 0) firstHardFork = t;
          lastBuyStep = s;
          lastForkStep = s;
        }
      }

      if (snapAtDays.contains(t ~/ 86400) && t % 86400 < step) {
        final researched =
            game.researchNodes.where((n) => n.isCompleted).length;
        snaps.add(
          '${_hms(t).padRight(6)} | inc/s ${perSec.toStringAsFixed(0).padRight(10)}'
          ' | hashX ${game.buildChannels().multiplier(Channel.hash).toStringAsFixed(1).padRight(7)}'
          ' | mult ${game.prestigeMultiplier.toStringAsFixed(1).padRight(7)}'
          ' | GT ${game.govTokens.toString().padRight(5)}'
          ' | CX ${game.consensus.toString().padRight(4)}'
          ' | GB ${game.genesisBlocks.toString().padRight(3)}'
          ' | lab $researched/22'
          ' | SF/HF/NB $softForks/$hardForks/$newChains',
        );
      }
    }

    final hashX = game.buildChannels().multiplier(Channel.hash);
    final incomeX = game.buildChannels().multiplier(Channel.income);

    print('\n===== FULL-ECONOMY SIM ($days days, engaged player) =====');
    print('time   | income/s   | hashX   | mult    | GT    | CX   | GB '
        '| lab    | SoftFork/HardFork/NewChain');
    for (final s in snaps) {
      print(s);
    }
    print('First Hard Fork      : ${_hms(firstHardFork)}');
    print('First New Blockchain : ${_hms(firstNewChain)}');
    print('First Win (21M-ever) : ${_hms(firstWin)}');
    print('lifetimeEverSats     : ${game.lifetimeEverSats.toStringAsExponential(2)}');
    print('Totals               : $softForks SF / $hardForks HF / $newChains NB');
    print('Final hash channel   : x${hashX.toStringAsFixed(2)}');
    print('Final income channel : x${incomeX.toStringAsFixed(2)}');
    print('Genesis Blocks       : ${game.genesisBlocks}');
    print('Peak income/s        : ${peakIncome.toStringAsFixed(0)} sats');
    print('Prestige multiplier  : x${game.prestigeMultiplier.toStringAsFixed(2)}');
    print('=======================================================\n');

    // --- Invariants ---
    expect(sawBad, false, reason: 'no NaN/Infinity anywhere in the economy');
    expect(game.wallet, greaterThanOrEqualTo(0));
    // Concave multipliers keep the endgame bounded even after thousands of forks.
    expect(maxMult, lessThan(1e5),
        reason: 'prestige multiplier stayed bounded (no runaway)');
    // Content is actually bought and applied through the real tick.
    expect(maxResearched, greaterThan(10), reason: 'research gets bought & applied');
    expect(maxHashX, greaterThan(1.5),
        reason: 'hash channel content reaches the economy');
    expect(peakIncome, greaterThan(0), reason: 'the economy actually produces income');
    // Progression is reachable but not trivially instant even with content.
    expect(firstHardFork, greaterThan(0), reason: 'Hard Fork reachable');
    expect(firstNewChain, greaterThan(2 * 86400),
        reason: 'tier-3 must not be trivially fast even with content');
    expect(firstNewChain, lessThan(days * 86400), reason: 'tier-3 reachable in $days d');

    // Endgame (Phase 5): the ending is a ~1-YEAR goal (endgameTargetSats
    // 2.1e20), so a 60-day whale run must NOT reach it yet — this guards against
    // a regression that makes the ending trivially fast (as 2.1e17 was, ~14d).
    // The cumulative-ever counter must still be climbing steadily toward it.
    expect(firstWin, -1,
        reason: 'the ending is a ~1yr goal, not reachable in $days d');
    expect(game.hasWonGame, false);
    expect(game.lifetimeEverSats, greaterThan(1e18),
        reason: 'cumulative-ever climbs toward the target');
  });
}
