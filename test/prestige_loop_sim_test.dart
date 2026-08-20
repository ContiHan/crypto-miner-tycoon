// ignore_for_file: avoid_print
// Full 3-tier prestige endgame simulation (Phase 5 validation tool).
//
// The Phase 1 sim (economy_sim_test.dart) only drives the single hard-fork loop.
// This one drives the COMPLETE prestige progression through the REAL services:
//   Hard Fork (GovTokens)  ->  New Blockchain (Genesis)
// (Soft Fork / Consensus were removed in SKILL S2.)
// using EconomyService + MiningManager + PrestigeSystem + the real rig catalog,
// so we can empirically answer: is the endgame reachable, does each tier pay off,
// and does anything collapse / run away / overflow over weeks of play?
//
// It models one engaged player with an explicit, documented strategy (below).
// Output is a printed report; asserts only guard the critical invariants
// (no NaN/Infinity, income doesn't die permanently, tier-2 and tier-3 are
// actually reached within the run).
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
  int firstHardFork = -1;
  int firstNewBlockchain = -1;
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
      economy.calculatePrestigeMultiplier(govTokens, spentGovTokens);

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

    // --- Prestige only when the era has stalled at the soft-wall (income can
    //     no longer buy the next rig for a while). An engaged player then cashes
    //     the era in and rebuilds with a higher multiplier. ---
    final stalled = (t - lastBuySecond) > 600 && (t - lastHardForkSecond) > 600;
    if (stalled) {
      final pendGov = economy.calculatePendingGovTokens(
        lifetime,
        gainMultiplier: pr.genesisGainMultiplier,
      );
      if (pendGov >= 1) {
        // The ONE fork (SKILL S2). Genesis Blocks accrue PASSIVELY from the
        // cumulative GovTokens minted (recordGovTokensMinted feeds the derived
        // genesisBlocks) — there is no separate New-Blockchain deep reset.
        govTokens += pendGov;
        pr.recordGovTokensMinted(pendGov);
        report.hardForks++;
        if (report.firstHardFork < 0) report.firstHardFork = t;
        if (report.firstNewBlockchain < 0 && pr.genesisBlocks > 0) {
          report.firstNewBlockchain = t;
        }
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
    report.newBlockchains = pr.genesisBlocks; // passive Genesis count

    if (snapAt.contains(t)) {
      report.snapshots.add(
        '${_hms(t).padRight(10)}'
        '| hash ${Formatter.formatNumber(hash).padRight(9)}'
        '| inc/s ${Formatter.formatBitcoin(income).padRight(11)}'
        '| GT ${govTokens.toString().padRight(5)}'
        '| GB ${pr.genesisBlocks.toString().padRight(3)}'
        '| xMult ${mult.toStringAsFixed(1).padRight(8)}'
        '| HF/NB ${report.hardForks}/${report.newBlockchains}',
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

    print('\n===== PRESTIGE SIM ($days days, engaged player) =====');
    print('time      | hash      | income/s    | GT    | GB '
        '| mult     | HardFork/NewChain');
    print('----------+-----------+-------------+-------+----'
        '+----------+-------------------');
    for (final s in r.snapshots) {
      print(s);
    }
    print('');
    print('First Hard Fork      : ${_hms(r.firstHardFork)}');
    print('First New Blockchain : ${_hms(r.firstNewBlockchain)}');
    print('Totals over $days d  : '
        '${r.hardForks} hard / ${r.newBlockchains} new-chain');
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

    // Endgame PACING (SKILL S2): the Hard Fork is reachable, and Genesis Blocks
    // — now PASSIVE — actually accrue over the run. There is no longer a tiered
    // "New Blockchain" event with a pacing floor; Genesis grows on its own from
    // cumulative minted GovTokens, so we just assert it climbs and stays bounded.
    expect(r.firstHardFork, greaterThan(0), reason: 'Hard Fork must be reachable');
    expect(r.finalGenesis, greaterThan(0),
        reason: 'passive Genesis must accrue over a $days-day run');
    expect(r.finalGenesis, lessThan(10000),
        reason: 'fourth-root Genesis curve keeps the count tame (no runaway)');
  });
}
