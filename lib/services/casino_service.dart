import 'dart:math';
import '../core/constants.dart';

/// SIMULATED casino logic — pure, deterministic given a [Random]. No real money
/// or real-world value is ever involved: the only stake and prize is the in-game
/// Micro-Chip currency. Every game has a house edge (EV < 1) so it is a chip
/// sink, and the odds are disclosed in the UI for compliance.
class SlotOutcome {
  final String name;
  final List<String> symbols; // three reel symbol KEYS (mapped to icons in UI)
  final double multiplier; // amount returned per chip staked (0 = loss)
  final int weight; // relative probability weight
  const SlotOutcome(this.name, this.symbols, this.multiplier, this.weight);
}

class SlotSpin {
  final List<String> symbols;
  final double multiplier;
  final int bet;
  final double luckFactor; // >= 1, scales winnings; RTP stays < 1 (see below)
  const SlotSpin(this.symbols, this.multiplier, this.bet,
      {this.luckFactor = 1.0});

  int get payout => (bet * multiplier * luckFactor).floor();
  int get net => payout - bet;
  bool get isWin => payout > 0;
  bool get isJackpot => multiplier >= 25;
}

/// Result of a single Plinko drop. [path] is one L/R decision per peg row
/// (true = right); [slotIndex] is the landing bucket (== number of rights);
/// [multiplier] is that bucket's payout per chip staked.
class PlinkoDrop {
  final List<bool> path;
  final int slotIndex;
  final double multiplier;
  final int bet;
  final double luckFactor; // >= 1, scales winnings; RTP stays < 1
  const PlinkoDrop(this.path, this.slotIndex, this.multiplier, this.bet,
      {this.luckFactor = 1.0});

  int get payout => (bet * multiplier * luckFactor).floor();
  int get net => payout - bet;
  bool get isWin => payout > 0;
  bool get isJackpot => multiplier >= 10;
}

class CasinoService {
  // Weighted paytable. EV = sum(weight*multiplier)/sum(weight)
  //   = (1*25 + 3*10 + 8*5 + 20*3 + 120*1.5 + 220*0) / 372 = 335/372 ≈ 0.90.
  // So the house keeps ~10% over time — it's a chip sink with a jackpot thrill.
  // Symbol keys ('moon'/'rocket'/'diamond'/'coin'/'bolt') are mapped to real
  // outline icons in the UI (no emoji).
  static const List<SlotOutcome> slotTable = [
    SlotOutcome('JACKPOT', ['moon', 'moon', 'moon'], 25.0, 1),
    SlotOutcome('Rockets', ['rocket', 'rocket', 'rocket'], 10.0, 3),
    SlotOutcome('Diamonds', ['diamond', 'diamond', 'diamond'], 5.0, 8),
    SlotOutcome('Coins', ['coin', 'coin', 'coin'], 3.0, 20),
    SlotOutcome('Pair', ['bolt', 'bolt', 'coin'], 1.5, 120),
    SlotOutcome('Bust', ['bolt', 'coin', 'diamond'], 0.0, 220),
  ];

  /// All distinct reel symbol keys (for the spin animation).
  static const List<String> symbolKeys = [
    'moon',
    'rocket',
    'diamond',
    'coin',
    'bolt',
  ];

  static final int totalWeight =
      slotTable.fold(0, (sum, o) => sum + o.weight);

  /// Average return per chip staked on the slots (for the disclosed odds).
  static double get slotsReturnToPlayer =>
      slotTable.fold(0.0, (s, o) => s + o.weight * o.multiplier) / totalWeight;

  /// Double-or-Nothing base return: 48% chance to win 2x => 0.96.
  static double get flipReturnToPlayer =>
      GameConstants.casinoFlipWinChance * 2;

  /// Luck multiplier actually applied to winnings, clamped so the realized RTP
  /// (baseRtp * factor) never exceeds [GameConstants.casinoRtpCap] (< 1). Never
  /// reduces winnings (factor >= 1). This is the single compliance guardrail:
  /// even with maxed Luck the casino stays a negative-EV chip sink.
  static double effectiveLuck(double luck, double baseRtp) {
    if (luck <= 1.0 || baseRtp <= 0) return 1.0;
    final double maxFactor = GameConstants.casinoRtpCap / baseRtp;
    if (maxFactor <= 1.0) return 1.0; // base RTP already at/above the cap
    return luck < maxFactor ? luck : maxFactor;
  }

  /// Spin the slots for [bet] chips using [rng]. [luck] (>=1) scales winnings,
  /// clamped so RTP stays below the cap.
  SlotSpin spinSlots(int bet, Random rng, {double luck = 1.0}) {
    final double lf = effectiveLuck(luck, slotsReturnToPlayer);
    int roll = rng.nextInt(totalWeight);
    for (final o in slotTable) {
      if (roll < o.weight) {
        return SlotSpin(o.symbols, o.multiplier, bet, luckFactor: lf);
      }
      roll -= o.weight;
    }
    final last = slotTable.last;
    return SlotSpin(last.symbols, last.multiplier, bet, luckFactor: lf);
  }

  /// Double-or-Nothing: true = win (pays 2x). The sub-50% chance is the edge.
  bool flipWin(Random rng) =>
      rng.nextDouble() < GameConstants.casinoFlipWinChance;

  // ---- Plinko (SIMULATED — Micro-Chips only, EV < 1, odds disclosed) --------
  // A chip drops through [plinkoRows] rows of pegs, going left/right 50/50 at
  // each, and lands in one of (rows + 1) buckets. The landing bucket == the
  // number of "rights", so the distribution is binomial: the centre is common
  // (low payout) and the edges are rare (jackpot). The multipliers are symmetric
  // and tuned so the weighted average (EV) is ~0.90 — the same ~10% house edge
  // as the slots, i.e. a chip sink with an edge-jackpot thrill.
  static const int plinkoRows = 8;
  static const List<double> plinkoMultipliers = [
    12.0, 2.5, 1.2, 0.7, 0.3, 0.7, 1.2, 2.5, 12.0,
  ];

  /// n-choose-k (small n; used for the binomial slot probabilities).
  static double _binomial(int n, int k) {
    if (k < 0 || k > n) return 0;
    double c = 1;
    for (int i = 0; i < k; i++) {
      c = c * (n - i) / (i + 1);
    }
    return c;
  }

  /// Probability of the chip landing in [slot] (0..plinkoRows), binomial(0.5).
  static double plinkoSlotProbability(int slot) =>
      _binomial(plinkoRows, slot) / pow(2, plinkoRows);

  /// Average return per chip staked on Plinko (for the disclosed odds).
  static double get plinkoReturnToPlayer {
    double ev = 0;
    for (int k = 0; k <= plinkoRows; k++) {
      ev += plinkoSlotProbability(k) * plinkoMultipliers[k];
    }
    return ev;
  }

  /// Drop a chip through the pegs for [bet] chips using [rng]. [luck] (>=1)
  /// scales winnings, clamped so RTP stays below the cap.
  PlinkoDrop dropPlinko(int bet, Random rng, {double luck = 1.0}) {
    final double lf = effectiveLuck(luck, plinkoReturnToPlayer);
    final path = <bool>[];
    int slot = 0;
    for (int i = 0; i < plinkoRows; i++) {
      final right = rng.nextBool();
      path.add(right);
      if (right) slot++;
    }
    return PlinkoDrop(path, slot, plinkoMultipliers[slot], bet, luckFactor: lf);
  }
}
