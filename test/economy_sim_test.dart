// Economy simulation harness (Phase 1 tuning tool).
//
// Drives the REAL EconomyService + MiningManager over simulated wall-clock time
// so we can measure the actual pacing curve and validate balance changes on
// elapsed time (not static ratios). Run: `flutter test test/economy_sim_test.dart`.
//
// It models one "engaged idle player" who greedily reinvests into the best
// hash-per-sat rig every tick. Output is a printed report; the asserts only
// sanity-check that the sim ran.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/logic/managers/mining_manager.dart';
import 'package:crypto_miner_tycoon/utils/formatter.dart';

class _SimResult {
  final Map<String, String> milestoneTimes = {}; // milestone -> human time
  final List<String> snapshots = [];
  bool hitCap = false;
  String capTime = 'not reached';
  int totalRigs = 0;
  double finalIncomePerSec = 0;
}

String _hms(int seconds) {
  if (seconds < 0) return 'n/a';
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

_SimResult _runSim({required int maxSeconds, required bool withPrestige}) {
  final economy = EconomyService();
  final mining = MiningManager();
  final result = _SimResult();

  final rigs = [
    Rig(id: RigIds.cpuRig, name: 'CPU', baseCost: 100, baseHashRate: 1.0),
    Rig(id: RigIds.gpuRig, name: 'GPU', baseCost: 1500, baseHashRate: 20.0),
    Rig(id: RigIds.asicRig, name: 'ASIC', baseCost: 12000, baseHashRate: 250.0),
    Rig(id: RigIds.quantumRig, name: 'Q', baseCost: 150000, baseHashRate: 5000.0),
  ];

  // Bootstrap: assume the player taps to afford the first CPU rig.
  double wallet = 100;
  double lifetime = 0; // resets each hard fork (this is what the cap tracks)
  double exchangeRate = 1.0;
  int govTokens = 0;
  int eras = 0;
  int lastBuySecond = 0;

  final milestones = <String, double>{
    '1e6': 1e6,
    '1e9': 1e9,
    '1e12': 1e12,
    '1e14': 1e14,
    'cap(2.1e15)': GameConstants.maxSupplySats,
  };
  final pending = Map<String, double>.from(milestones);

  final snapshotAt = <int>[60, 3600, 21600, 86400, 259200, 604800, 1209600, 2592000];
  final snapAtSet = snapshotAt.toSet();

  double hashOf() => economy.calculateGlobalHashRate(rigs, {}, false, 1.0);
  double rigCostSats(Rig r) =>
      economy.calculateRigCost(r, {}, false, 1.0) / exchangeRate;

  for (int t = 1; t <= maxSeconds; t++) {
    final hash = hashOf();
    final diff = mining.calculateNetworkDifficulty(lifetime);
    final prestigeMult = economy.calculatePrestigeMultiplier(govTokens, 0);
    final income = mining.calculateMiningIncome(
      hashRate: hash,
      difficulty: diff,
      prestigeMultiplier: prestigeMult,
      chaosMultiplier: 1.0,
      lifetimeEarnings: lifetime,
    );
    wallet += income;
    lifetime += income;
    mining.incrementBlocksMined();
    mining.checkHalving();

    // Greedy reinvest: buy the best hash-per-sat rig while affordable.
    int guard = 0;
    while (guard++ < 500) {
      Rig? best;
      double bestRoi = 0;
      double bestCost = 0;
      for (final r in rigs) {
        final cost = rigCostSats(r);
        if (cost <= wallet) {
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

    // Prestige (hard fork) when the era has stalled: no purchase for 10 min and
    // a worthwhile token payout is available.
    if (withPrestige) {
      final pendingTokens = economy.calculatePendingGovTokens(lifetime);
      final stalled = (t - lastBuySecond) > 600;
      if (stalled && pendingTokens > 0) {
        govTokens += pendingTokens;
        exchangeRate *= (1.0 + pendingTokens);
        eras++;
        // reset era
        wallet = 100;
        lifetime = 0;
        for (final r in rigs) {
          r.amount = 0;
        }
        mining.reset();
        lastBuySecond = t;
      }
    }

    // Record milestones (lifetime is per-era; track first time reached).
    pending.removeWhere((name, value) {
      if (lifetime >= value) {
        result.milestoneTimes[name] = _hms(t);
        if (name.startsWith('cap')) {
          result.hitCap = true;
          result.capTime = _hms(t);
        }
        return true;
      }
      return false;
    });

    if (snapAtSet.contains(t)) {
      result.snapshots.add(
        '${_hms(t).padRight(9)} | hash ${Formatter.formatNumber(hash).padRight(9)}'
        ' | income/s ${Formatter.formatBitcoin(income).padRight(11)}'
        ' | rate ${Formatter.formatNumber(exchangeRate).padRight(8)}'
        ' | tokens $govTokens | eras $eras',
      );
    }

    result.finalIncomePerSec = income;
    result.totalRigs = govTokens; // reuse field: total tokens as "progress"
    if (result.hitCap && !withPrestige) break;
  }

  return result;
}

void main() {
  test('economy sim — measurement (not a pass/fail gate)', () {
    final noPrestige = _runSim(maxSeconds: 30 * 86400, withPrestige: false);
    final withPrestige = _runSim(maxSeconds: 30 * 86400, withPrestige: true);

    // ignore: avoid_print
    print('\n============= ECONOMY SIM — single era, NO prestige =============');
    print('time      | hash      | income/s    | rate     | tokens/eras');
    print('----------+-----------+-------------+----------+------------');
    for (final s in noPrestige.snapshots) {
      print(s);
    }
    print('cap(2.1e15) reached: ${noPrestige.hitCap} (${noPrestige.capTime})');

    print('\n============= ECONOMY SIM — WITH hard-fork prestige loop =============');
    print('time      | hash      | income/s    | rate     | tokens/eras');
    print('----------+-----------+-------------+----------+------------');
    for (final s in withPrestige.snapshots) {
      print(s);
    }
    print('\nMilestones (per-era lifetime, with prestige):');
    for (final m in ['1e6', '1e9', '1e12', '1e14', 'cap(2.1e15)']) {
      print('  ${m.padRight(12)}-> ${withPrestige.milestoneTimes[m] ?? "never"}');
    }
    print('Total GovTokens after 30d: ${withPrestige.totalRigs}');
    print('=====================================================================\n');

    expect(noPrestige.snapshots, isNotEmpty);
    expect(withPrestige.snapshots, isNotEmpty);
  });
}
