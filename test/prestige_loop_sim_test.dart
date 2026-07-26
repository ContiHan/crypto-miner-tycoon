// ignore_for_file: avoid_print
// Full 3-tier prestige endgame simulation (Phase 5 validation tool).
//
// The Phase 1 sim (economy_sim_test.dart) only drives the single hard-fork loop.
// This one drives the COMPLETE prestige progression through the REAL services:
//   Soft Fork (Consensus)  ->  Hard Fork (GovTokens)  ->  New Blockchain (Genesis)
// using EconomyService + MiningManager + PrestigeSystem + the real rig catalog,
// so we can empirically answer: is the endgame reachable, does each tier pay off,
// and does anything collapse / run away / overflow over weeks of play?
//
// It models one engaged player with an explicit, documented strategy (below).
// Output is a printed report; asserts only guard the critical invariants
// (no NaN/Infinity, income doesn't die permanently, tier-2 and tier-3 are
// actually reached within the run).
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/content/rig_defs.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/logic/managers/mining_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/prestige_system.dart';
import 'package:crypto_miner_tycoon/utils/formatter.dart';

String _hms(int seconds) {
  if (seconds < 0) return 'never';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final parts = <String>[];
  if (d > 0) parts.add('${d}d');
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (parts.isEmpty || s > 0) parts.add('${s}s');
  return parts.join(' ');
}

class _SimReport {
  int firstSoftFork = -1;
  int firstHardFork = -1;
  int firstNewBlockchain = -1;
  int softForks = 0;
  int hardForks = 0;
  int newBlockchains = 0;
  int finalGenesis = 0;
  int finalGovTokens = 0;
  double finalPrestigeMult = 0;
  double finalIncomePerSec = 0;
  double peakIncomePerSec = 0;
  // Last sim-second at which income was > 0. The per-era supply cap forces
  // income to 0 for the ~stall window at the end of every maxed era, so a
  // single instantaneous sample (finalIncomePerSec) reads 0 most ticks by
  // construction — this measures income RECOVERY instead (see the asserts).
  int lastPositiveIncomeSecond = -1;
  bool sawNaNorInf = false;
  bool incomeDiedPermanently = false;
  final List<String> snapshots = [];
}

_SimReport _runPrestigeSim({required int maxSeconds}) {
  final economy = EconomyService();
  final mining = MiningManager();
  final pr = PrestigeSystem();
  final report = _SimReport();

  // Real rig catalog (incl. fusion/datacenter and their lifetime unlocks).
  final rigs = createRigs();

  double wallet = 100; // player taps to afford the first CPU rig
  double lifetime = 0; // per-era; resets on hard fork / new blockchain
  const int spentGovTokens = 0; // sim buys no perks (conservative multiplier)
  int govTokens = 0;

  int lastBuySecond = 0;
  int lastHardForkSecond = 0;

  double prestigeMult() =>
      economy.calculatePrestigeMultiplier(govTokens, spentGovTokens) +
      pr.consensusBonus;

  double rigCostSats(Rig r) => economy.calculateRigCost(r, 0.0, 1.0);

  bool bad(double v) => v.isNaN || v.isInfinite;

  final snapAt = <int>{
    3600, 21600, 86400, 259200, 604800, 1209600, 1814400, 2592000, // ..30d
    3888000, 5184000, // 45d, 60d
  };

  for (int t = 1; t <= maxSeconds; t++) {
    final hash = economy.calculateGlobalHashRate(rigs, false, 1.0);
    final diff = mining.calculateNetworkDifficulty(lifetime);
    final mult = prestigeMult();
    final income = mining.calculateMiningIncome(
      hashRate: hash,
      difficulty: diff,
      prestigeMultiplier: mult,
      chaosMultiplier: 1.0,
      lifetimeEarnings: lifetime,
    );

    if (bad(hash) || bad(mult) || bad(income)) report.sawNaNorInf = true;
    if (hash > 0 && income <= 0 && lifetime < GameConstants.maxSupplySats) {
      report.incomeDiedPermanently = true;
    }

    wallet += income;
    lifetime += income;
    mining.incrementBlocksMined();
    mining.checkHalving();

    if (income > report.peakIncomePerSec) report.peakIncomePerSec = income;
    if (income > 0) report.lastPositiveIncomeSecond = t;

    // --- Greedy reinvest: buy the best marginal hash-per-sat rig that is both
    //     affordable and unlocked at the current per-era lifetime. ---
    int guard = 0;
    while (guard++ < 1000) {
      Rig? best;
      double bestRoi = 0;
      double bestCost = 0;
      for (final r in rigs) {
        final cost = rigCostSats(r);
        if (cost <= wallet && cost > 0) {
          final roi = r.baseHashRate / cost;
          if (roi > bestRoi) {
            bestRoi = roi;
            best = r;
            bestCost = cost;
          }
        }
      }
      if (best == null) break;
      wallet -= bestCost;
      best.amount++;
      lastBuySecond = t;
    }

    // --- Tier 1 (fast loop): Soft Fork whenever Consensus would at least
    //     double (cube-root is concave, so banking in bigger chunks is better
    //     than spamming). Costs only LAB progress (not modeled). ---
    final pendCx = pr.pendingConsensus(lifetime);
    if (pendCx >= 1 && pendCx >= pr.consensus) {
      pr.applySoftFork(lifetime);
      report.softForks++;
      if (report.firstSoftFork < 0) report.firstSoftFork = t;
    }

    // --- Slow loops only when the era has stalled at the soft-wall (income can
    //     no longer buy the next rig for a while). An engaged player then cashes
    //     the era in and rebuilds with a higher multiplier. ---
    final stalled = (t - lastBuySecond) > 600 && (t - lastHardForkSecond) > 600;
    if (stalled) {
      final pendGenesis = pr.pendingGenesis();
      final pendGov = economy.calculatePendingGovTokens(
        lifetime,
        gainMultiplier: pr.genesisGainMultiplier,
      );

      if (pendGenesis >= 1 && pendGenesis >= max(1, pr.genesisBlocks)) {
        // Tier 3: New Blockchain — deepest reset, keeps only Genesis.
        pr.applyNewBlockchain();
        report.newBlockchains++;
        report.finalGenesis = pr.genesisBlocks;
        if (report.firstNewBlockchain < 0) report.firstNewBlockchain = t;
        govTokens = 0;
        wallet = 100;
        lifetime = 0;
        for (final r in rigs) {
          r.amount = 0;
        }
        mining.hardForkReset();
        lastBuySecond = t;
        lastHardForkSecond = t;
      } else if (pendGov >= 1) {
        // Tier 2: Hard Fork — permanent GovToken multiplier, wipes CX era.
        // An engaged player cashes in every maxed era (each fork compounds the
        // permanent multiplier), not only when the % gain is large.
        govTokens += pendGov;
        pr.recordGovTokensMinted(pendGov);
        pr.onHardFork(); // wipes consensus era
        report.hardForks++;
        if (report.firstHardFork < 0) report.firstHardFork = t;
        wallet = 100;
        lifetime = 0;
        for (final r in rigs) {
          r.amount = 0;
        }
        mining.hardForkReset();
        lastBuySecond = t;
        lastHardForkSecond = t;
      }
    }

    if (snapAt.contains(t)) {
      report.snapshots.add(
        '${_hms(t).padRight(10)}'
        '| hash ${Formatter.formatNumber(hash).padRight(9)}'
        '| inc/s ${Formatter.formatBitcoin(income).padRight(11)}'
        '| GT ${govTokens.toString().padRight(5)}'
        '| CX ${pr.consensus.toString().padRight(4)}'
        '| GB ${pr.genesisBlocks.toString().padRight(3)}'
        '| xMult ${mult.toStringAsFixed(1).padRight(8)}'
        '| SF/HF/NB ${report.softForks}/${report.hardForks}/${report.newBlockchains}',
      );
    }

    report.finalIncomePerSec = income;
    report.finalGovTokens = govTokens;
    report.finalPrestigeMult = mult;
    report.finalGenesis = pr.genesisBlocks;
  }

  return report;
}

void main() {
  test('3-tier prestige endgame sim — measurement + invariant guards', () {
    const days = 60;
    final r = _runPrestigeSim(maxSeconds: days * 86400);

    print('\n===== 3-TIER PRESTIGE SIM ($days days, engaged player) =====');
    print('time      | hash      | income/s    | GT    | CX   | GB '
        '| mult     | SoftFork/HardFork/NewChain');
    print('----------+-----------+-------------+-------+------+----'
        '+----------+---------------------------');
    for (final s in r.snapshots) {
      print(s);
    }
    print('');
    print('First Soft Fork      : ${_hms(r.firstSoftFork)}');
    print('First Hard Fork      : ${_hms(r.firstHardFork)}');
    print('First New Blockchain : ${_hms(r.firstNewBlockchain)}');
    print('Totals over $days d  : '
        '${r.softForks} soft / ${r.hardForks} hard / ${r.newBlockchains} new-chain');
    print('Final Genesis Blocks : ${r.finalGenesis}');
    print('Final GovTokens      : ${r.finalGovTokens}');
    print('Final income/s       : ${Formatter.formatBitcoin(r.finalIncomePerSec)}');
    print('Last positive inc @  : ${_hms(r.lastPositiveIncomeSecond)} '
        '(${days * 86400 - r.lastPositiveIncomeSecond}s before end)');
    print('Peak income/s        : ${Formatter.formatBitcoin(r.peakIncomePerSec)}');
    print('Final prestige mult  : x${r.finalPrestigeMult.toStringAsFixed(2)}');
    print('NaN/Infinity seen    : ${r.sawNaNorInf}');
    print('Income died forever  : ${r.incomeDiedPermanently}');
    print('=============================================================\n');

    // --- Critical invariants (regression guards) ---------------------------
    // These WOULD fail on the runaway/cap-pin the concave-multiplier retune
    // fixed: the pre-fix economy hit x420k–x2M multipliers within days and
    // pinned income at the per-era cap (income frozen at 0 for the rest of run).
    expect(r.sawNaNorInf, false, reason: 'no NaN/Infinity may reach the economy');
    // Income must RECOVER after each fork — the per-era supply cap is a transient
    // soft-wall (income is 0 only while an era idles at the cap waiting to fork),
    // NOT a permanent 0/s pin. A single instantaneous sample reads 0 most ticks
    // by construction, so we assert the whale earned SOMETHING in the final hour
    // (every functioning era does during its post-reset ramp). This still fails
    // hard on the real regression it guards: income dead for the rest of the run.
    expect(days * 86400 - r.lastPositiveIncomeSecond, lessThan(3600),
        reason: 'income must recover after each fork (per-era cap is a transient '
            'soft-wall, not a permanent 0/s pin at the end of the run)');
    expect(r.incomeDiedPermanently, false,
        reason: 'income must never die permanently');
    expect(r.finalPrestigeMult, lessThan(1e5),
        reason: 'concave multipliers must keep the endgame from running away '
            '(pre-fix reached x420k+ within a week)');
    expect(r.snapshots, isNotEmpty);

    // Endgame PACING: an engaged player reaches every tier, and tier-3 is a
    // multi-day milestone — not the ~20h it collapsed to under the 10-rig
    // rescale (top hash ~10,000x the old ladder saturates the per-era cap every
    // fork, minting max GovTokens). The Genesis gate (genesisDivisor) was raised
    // to restore this; the floor here matches the full-economy sim's >2-day
    // guard (this bare, content-free sim lands at ~2.5d).
    expect(r.firstHardFork, greaterThan(0), reason: 'Hard Fork must be reachable');
    expect(r.firstNewBlockchain, greaterThan(2 * 86400),
        reason: 'tier-3 must not be trivially fast (was ~20h pre-gate-raise)');
    expect(r.firstNewBlockchain, lessThan(days * 86400),
        reason: 'tier-3 (New Blockchain) must be reachable within $days days');
  });
}
