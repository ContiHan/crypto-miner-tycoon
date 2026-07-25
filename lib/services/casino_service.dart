import 'dart:math';
import '../core/constants.dart';

/// SIMULATED "SWEEP" minigame logic — pure, deterministic given a [Random]. No
/// real money or value is ever involved: the only stake and prize is the in-game
/// DUST currency. Every game is deliberately PLAYER-FAVOURED (EV > 1) — sweeping
/// the chain pays out — and the outcome is decided purely by [Random] here, never
/// by any animation. It is bounded, not by a house edge, but by GameLogic's
/// per-window net-gain cap (the anti-farm guardrail).
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
  //   = (1*25 + 4*10 + 10*5 + 28*3 + 120*2 + 210*0) / 373 = 439/373 ≈ 1.18.
  // Player-favoured: a sweep returns ~+18% per stake on average, with a big
  // jackpot thrill. (The economy is bounded by GameLogic's per-window net cap.)
  // Symbol keys ('moon'/'rocket'/'diamond'/'coin'/'bolt') are mapped to real
  // outline icons in the UI (no emoji).
  static const List<SlotOutcome> slotTable = [
    SlotOutcome('JACKPOT', ['moon', 'moon', 'moon'], 25.0, 1),
    SlotOutcome('Rockets', ['rocket', 'rocket', 'rocket'], 10.0, 4),
    SlotOutcome('Diamonds', ['diamond', 'diamond', 'diamond'], 5.0, 10),
    SlotOutcome('Coins', ['coin', 'coin', 'coin'], 3.0, 28),
    SlotOutcome('Pair', ['bolt', 'bolt', 'coin'], 2.0, 120),
    SlotOutcome('Bust', ['bolt', 'coin', 'diamond'], 0.0, 210),
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

  /// Hash Flip (double-or-nothing) base return: 58% chance to win 2x => 1.16.
  static double get flipReturnToPlayer =>
      GameConstants.casinoFlipWinChance * 2;

  /// Luck multiplier actually applied to winnings, clamped so the realized
  /// average return (baseEv * factor) never exceeds [GameConstants.casinoEvCeiling].
  /// Never reduces winnings (factor >= 1). Luck makes a good thing better, but
  /// bounded — the per-window net cap in GameLogic is what stops farming.
  static double effectiveLuck(double luck, double baseEv) {
    if (luck <= 1.0 || baseEv <= 0) return 1.0;
    final double maxFactor = GameConstants.casinoEvCeiling / baseEv;
    if (maxFactor <= 1.0) return 1.0; // base EV already at/above the ceiling
    return luck < maxFactor ? luck : maxFactor;
  }

  /// Spin the slots for [bet] DUST using [rng]. [luck] (>=1) scales winnings,
  /// clamped so the average return stays below the EV ceiling.
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

  // ---- Relay (SIMULATED — DUST only, player-favoured EV > 1) ----------------
  // A packet relays through [plinkoRows] rows of nodes, going left/right 50/50 at
  // each, and lands in one of (rows + 1) buckets. The landing bucket == the
  // number of "rights", so the distribution is binomial: the centre is common
  // (low payout) and the edges are rare (jackpot). The multipliers are symmetric
  // and tuned so the weighted average (EV) is ~1.18 — the same player edge as the
  // slots, with an edge-jackpot thrill.
  static const int plinkoRows = 8;
  static const List<double> plinkoMultipliers = [
    15.0, 3.0, 1.5, 1.0, 0.4, 1.0, 1.5, 3.0, 15.0,
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

  /// Relay a packet through the nodes for [bet] DUST using [rng]. [luck] (>=1)
  /// scales winnings, clamped so the average return stays below the EV ceiling.
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
