// ignore_for_file: avoid_print
// BUILD-MATRIX BALANCE SIM (Slice 10) — drives the REAL GameLogic across a grid
// of (class x keystone) builds and measures how fast each mines one full 21M
// supply (THE LAST SATOSHI win = the Back-in-Time target). It validates that the
// whole Slice-1..9 depth stack (attributes, doctrines, keystones, upkeep, breach)
// integrates without breaking the economy, that class balance stays tight, and
// that no keystone lever produces a NaN/runaway or breaches the upkeep rail.
//
// WHAT THIS SIM DOES AND DOES NOT EXERCISE (read before adding assertions):
//   * It measures MINING THROUGHPUT to the win. It reinvests rigs + trunk/doctrine
//     research aggressively and taps a handful per tick.
//   * It runs offline-style (advanceForTest): chaosMultiplier is 1.0 with NO event
//     timer, and it never opens a crate or plays SWEEP. So keystones whose UPSIDE
//     lives in the loot/SWEEP/chaos/prestige loops show only their DOWNSIDE here:
//       - DEGENERATE GAMBLER (luck x2 for loot/SWEEP; sim sees only hash/income x0.5)
//       - SWEAT EQUITY / LASER EYES (click builds; the sim under-taps on purpose)
//       - PAPER HANDS / MARKET MAKER (prestige/chaos costs; not paid in a first-era
//         mining sprint, so they look strong here — safe early, pay later)
//       - COLD MINER / FORT KNOX (chaos immunity/steering; no chaos timer to steer)
//     This is the SAME documented limitation as the volatility note in
//     class_balance_sim_test.dart. The matrix is a throughput + health validator,
//     not a full build-power oracle. The heatmap artifact spells this out.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/keystone_system.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'test_helper.dart';

// The capstone node per branch — owning it unlocks that branch's keystones. We
// complete it directly (in isolation) so the cell measures the keystone LEVER's
// impact rather than the branch chain's cost.
const _branchCapstone = {
  'A': ResearchIds.centralBank,
  'B': ResearchIds.powerCapacitors,
  'C': ResearchIds.whalesEye,
};

// Keystones whose net effect in a PURE-MINING sim is a throughput LOSS because
// their upside is loot/SWEEP/click-driven (not exercised here). They are allowed
// to be slow — or to not finish within the cap — without failing the balance run.
const _upsideNotInSim = {'ks_degenerate_gambler'};

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

class _Cell {
  final String cls;
  final String keystone;
  final int winAt; // sim-seconds to mine one full supply, or -1 if not reached
  final bool won;
  final double progress;
  final double peakIncome;
  final double minNetKept;
  final bool bad;
  final bool equipped;
  _Cell(this.cls, this.keystone, this.winAt, this.won, this.progress,
      this.peakIncome, this.minNetKept, this.bad, this.equipped);
  Map<String, dynamic> toJson() => {
        'class': cls,
        'keystone': keystone,
        'winAt': winAt,
        'won': won,
        'progress': double.parse(progress.toStringAsFixed(4)),
        'peakIncome': peakIncome,
        'minNetKept': double.parse(minNetKept.toStringAsFixed(4)),
      };
}

const int _step = 120;
const int _maxDays = 8; // ample: the slowest FINISHING build wins in ~3.4 sim-days

Future<_Cell> _runBuild(BtcClass? cls, KeystoneDef? ks) async {
  final game = createTestGameLogic(startTimers: false, loadOnStart: false);
  await game.loadGame();
  if (cls != null) game.debugSelectClass(cls);
  game.wallet = 100;
  // RP now = the active class's level (cap 18). Mining a full 21M supply is a
  // LATE-game feat, so seed a mature class level (→ full RP budget) — the same
  // "measure the lever, not the grind" stance that free-grants the capstone below.
  // The class-less Prospector baseline (cls == null) legitimately has 0 RP.
  if (cls != null) game.debugSetClassLevel(cls, 18);
  if (ks != null) {
    game.researchNodes
        .firstWhere((n) => n.id == _branchCapstone[ks.branch]!)
        .isCompleted = true;
    game.toggleKeystone(ks.id);
  }

  final maxSteps = _maxDays * 86400 ~/ _step;
  int winAt = -1;
  double peakIncome = 0, minNetKept = 1.0;
  bool bad = false;
  for (int s = 1; s <= maxSteps; s++) {
    for (int c = 0; c < 15; c++) {
      game.clickMine(playSound: false);
    }
    final earned = game.advanceForTest(_step.toDouble());
    final perSec = earned / _step;
    if (perSec > peakIncome) peakIncome = perSec;
    if (game.netIncomeFraction < minNetKept) minNetKept = game.netIncomeFraction;
    if (game.wallet.isNaN ||
        game.wallet.isInfinite ||
        earned.isNaN ||
        earned.isInfinite ||
        game.globalHashRate.isNaN ||
        game.globalHashRate.isInfinite) {
      bad = true;
    }
    _buyResearch(game);
    _reinvestRigs(game, 400);
    if (game.hasWonGame) {
      winAt = s * _step;
      break;
    }
  }
  return _Cell(
    cls?.name ?? 'prospector',
    ks?.id ?? 'none',
    winAt,
    game.hasWonGame,
    game.supplyProgress,
    peakIncome,
    minNetKept,
    bad,
    ks == null ? true : game.isKeystoneEquipped(ks.id),
  );
}

String _hms(int s) {
  if (s < 0) return 'DNF';
  final h = s ~/ 3600, m = (s % 3600) ~/ 60;
  return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}m';
}

void main() {
  // RP now = class level, so a class-less Prospector can't hold a real build
  // (it's the pre-class state, floored at a starter RP). The matrix therefore
  // measures the 4 REAL classes — each seeded to a full level-18 build.
  const classes = <BtcClass?>[
    BtcClass.soloMiner,
    BtcClass.corporation,
    BtcClass.btcOg,
    BtcClass.poolMember,
  ];
  final builds = <KeystoneDef?>[null, ...kKeystones];

  test('build-matrix: every (class x keystone) build stays healthy + bounded',
      () async {
    final grid = <_Cell>[];
    for (final cls in classes) {
      for (final ks in builds) {
        grid.add(await _runBuild(cls, ks));
      }
    }

    // ---- Human-readable matrix (win time; DNF = didn't mine a full supply) ----
    final keys = builds.map((b) => b?.id ?? 'none').toList();
    print('\n===== BUILD MATRIX — sim-time to mine one 21M supply =====');
    print('(DNF = upside not exercised by a pure-mining sim; see file header)');
    for (final cls in classes) {
      final name = (cls?.name ?? 'prospector').padRight(11);
      final row = keys.map((k) {
        final c = grid.firstWhere((e) => e.cls == (cls?.name ?? 'prospector') && e.keystone == k);
        return '${k.replaceFirst('ks_', '').split('_').first.padRight(6).substring(0, 6)}=${_hms(c.winAt).padLeft(5)}';
      }).join('  ');
      print('$name $row');
    }
    print('==========================================================\n');
    print('BUILD_MATRIX_JSON=${jsonEncode(grid.map((c) => c.toJson()).toList())}');

    // ---- Invariants that MUST hold for every cell ----
    for (final c in grid) {
      final where = '${c.cls}/${c.keystone}';
      expect(c.bad, false, reason: '$where: NaN/Infinity in the economy');
      expect(c.equipped, true, reason: '$where: keystone equipped as intended');
      // THE POWER BILL rail (#15): net kept is always in [0.90, 1.0]; FURNACE FARM
      // pins it to the 0.90 floor, nothing may push it below.
      expect(c.minNetKept, greaterThanOrEqualTo(0.90 - 1e-9),
          reason: '$where: upkeep never skims more than the 10% cap');
      expect(c.minNetKept, lessThanOrEqualTo(1.0 + 1e-9),
          reason: '$where: net kept never exceeds gross');
      // Every build produces a real, growing economy.
      expect(c.peakIncome, greaterThan(0), reason: '$where: economy is not dead');
      expect(c.progress, greaterThan(0.0), reason: '$where: makes real progress');

      // Reachability: every build mines a full supply within the cap EXCEPT the
      // documented pure-mining-weak keystones (their payoff is loot/SWEEP luck).
      if (_upsideNotInSim.contains(c.keystone)) {
        continue; // slow/DNF is acceptable & expected for these
      }
      expect(c.won, true,
          reason: '$where: should mine a full supply within $_maxDays sim-days');
    }
  });

  test('per-class Back-in-Time: the baseline speed-run stays balanced', () async {
    // The Back-in-Time speed-run target IS mining one full supply from a reset.
    // With no keystone equipped, this isolates the CLASS racials. All classes must
    // reach it, and the fastest-vs-slowest spread must stay tight (no class is a
    // trap, none is a runaway).
    final baselines = <String, int>{};
    for (final cls in classes) {
      final c = await _runBuild(cls, null);
      baselines[cls?.name ?? 'prospector'] = c.winAt;
      expect(c.won, true,
          reason: '${c.cls}: a class baseline must mine a full supply');
    }
    final times = baselines.values.toList();
    final fastest = times.reduce((a, b) => a < b ? a : b);
    final slowest = times.reduce((a, b) => a > b ? a : b);
    print('\nBACK-IN-TIME per class (baseline): $baselines');
    print('spread = ${(slowest / fastest).toStringAsFixed(2)}x '
        '(fastest ${_hms(fastest)}, slowest ${_hms(slowest)})\n');
    expect(slowest / fastest, lessThan(2.5),
        reason: 'class balance: no class is >2.5x slower than the best');
  });
}
