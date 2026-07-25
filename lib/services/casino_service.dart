import 'dart:math';
import '../core/constants.dart';

/// SIMULATED "SWEEP" minigame logic — pure, deterministic given a [Random]. No
/// real money or value is ever involved: the only stake and prize is the in-game
/// UTXO currency. Every game is deliberately PLAYER-FAVOURED (EV > 1) — sweeping
/// the chain pays out — and the outcome is decided purely by [Random] here, never
/// by any animation. It is bounded, not by a house edge, but by GameLogic's
/// per-window net-gain cap (the anti-farm guardrail).
/// The shared shape of every SWEEP result (slots / relay / flip). Lets GameLogic
/// commit an outcome uniformly, and lets the UI hold a RESOLVED-but-not-yet-
/// committed outcome while its animation plays, then commit it on landing (so a
/// payout / achievement / the net-cap never reveal before the animation ends).
abstract class SweepOutcome {
  int get payout;
  int get net;
  bool get isWin;
  bool get isJackpot;
}

class SlotOutcome {
  final String name;
  final List<String> symbols; // three reel symbol KEYS (mapped to icons in UI)
  final double multiplier; // amount returned per chip staked (0 = loss)
  final int weight; // relative probability weight
  const SlotOutcome(this.name, this.symbols, this.multiplier, this.weight);
}

class SlotSpin implements SweepOutcome {
  final List<String> symbols;
  final double multiplier;
  final int bet;
  final double luckFactor; // >= 1, scales winnings; RTP stays < 1 (see below)
  const SlotSpin(this.symbols, this.multiplier, this.bet,
      {this.luckFactor = 1.0});

  @override
  int get payout => (bet * multiplier * luckFactor).floor();
  @override
  int get net => payout - bet;
  @override
  bool get isWin => payout > 0;
  @override
  bool get isJackpot => multiplier >= 25;
}

/// Result of a single Plinko drop. [path] is one L/R decision per peg row
/// (true = right); [slotIndex] is the landing bucket (== number of rights);
/// [multiplier] is that bucket's payout per chip staked.
class PlinkoDrop implements SweepOutcome {
  final List<bool> path;
  final int slotIndex;
  final double multiplier;
  final int bet;
  final double luckFactor; // >= 1, scales winnings; RTP stays < 1
  const PlinkoDrop(this.path, this.slotIndex, this.multiplier, this.bet,
      {this.luckFactor = 1.0});

  @override
  int get payout => (bet * multiplier * luckFactor).floor();
  @override
  int get net => payout - bet;
  @override
  bool get isWin => payout > 0;
  @override
  bool get isJackpot => multiplier >= 10;
}

/// One weighted Hash Flip outcome — [zeros] leading zeros hit on the flipped
/// nonce, paying [multiplier]× the stake (0 = a stale share / bust).
class FlipOutcome {
  final int zeros;
  final double multiplier;
  final int weight;
  const FlipOutcome(this.zeros, this.multiplier, this.weight);
}

/// Result of a single Hash Flip (the HIGH-VARIANCE game): flip the nonce and
/// count the leading zeros of the resulting hash. Usually nothing (a stale
/// share, you lose the stake), but a rare multi-zero hit "mines a block" for a
/// big payout — up to 30×. EV matches the other games (~1.5); flip just trades
/// safety for swing.
class FlipResult implements SweepOutcome {
  final int zeros;
  final double multiplier;
  final int bet;
  final double luckFactor; // >= 1, scales winnings; bounded by the EV ceiling
  const FlipResult(this.zeros, this.multiplier, this.bet,
      {this.luckFactor = 1.0});

  @override
  int get payout => (bet * multiplier * luckFactor).floor();
  @override
  int get net => payout - bet;
  @override
  bool get isWin => payout > 0;
  @override
  bool get isJackpot => multiplier >= 30;
}

class CasinoService {
  // Weighted paytable — strongly PLAYER-favoured, tuned so the player mostly
  // RAISES (the per-window net cap is the only brake, not the odds).
  //   EV = (1*25 + 4*10 + 10*5 + 28*3 + 95*2 + 95*1 + 60*0) / 293 = 484/293 ≈ 1.65.
  //   ~80% of spins DON'T lose the stake: ~47% win (mult>=2), ~32% refund (1x,
  //   break-even), only ~20% bust (0x). Multipliers are INTEGERS so a bet of 1
  //   still pays a real win (floor never eats it). Symbol keys
  //   ('moon'/'rocket'/'diamond'/'coin'/'bolt') map to outline icons in the UI.
  static const List<SlotOutcome> slotTable = [
    SlotOutcome('JACKPOT', ['moon', 'moon', 'moon'], 25.0, 1),
    SlotOutcome('Rockets', ['rocket', 'rocket', 'rocket'], 10.0, 4),
    SlotOutcome('Diamonds', ['diamond', 'diamond', 'diamond'], 5.0, 10),
    SlotOutcome('Coins', ['coin', 'coin', 'coin'], 3.0, 28),
    SlotOutcome('Pair', ['bolt', 'bolt', 'coin'], 2.0, 95),
    SlotOutcome('Refund', ['coin', 'bolt', 'rocket'], 1.0, 95),
    SlotOutcome('Bust', ['bolt', 'coin', 'diamond'], 0.0, 60),
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

  // Hash Flip — the HIGH-VARIANCE game. Flip the nonce, count the resulting
  // hash's leading zeros: mostly a stale share (0×, the stake is lost), but the
  // rare multi-zero hit "mines a block" for a big payout. Integer multipliers so
  // a bet of 1 still pays cleanly (floor never eats a win).
  //   EV = (0*76 + 2*15 + 5*6 + 30*3) / 100 = 150/100 = 1.50 — matched to the
  //   other games (~1.5), so flip is not weaker in EV, only swingier: ~24% pay
  //   something and a 30× "block found" jackpot lands 3% of the time.
  static const List<FlipOutcome> flipTable = [
    FlipOutcome(0, 0.0, 76), // no leading zero — stale share (bust)
    FlipOutcome(1, 2.0, 15), // one leading zero
    FlipOutcome(2, 5.0, 6), // two leading zeros
    FlipOutcome(3, 30.0, 3), // three leading zeros — BLOCK FOUND (jackpot)
  ];

  static final int flipTotalWeight =
      flipTable.fold(0, (sum, o) => sum + o.weight);

  /// Average return per chip staked on Hash Flip (for the disclosed odds ≈ 1.5).
  static double get flipReturnToPlayer =>
      flipTable.fold(0.0, (s, o) => s + o.weight * o.multiplier) /
      flipTotalWeight;

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

  /// Spin the slots for [bet] UTXO using [rng]. [luck] (>=1) scales winnings,
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

  /// Flip the nonce for [bet] UTXO using [rng]. Returns the tiered outcome (0×
  /// bust up to a 30× jackpot). [luck] (>=1) scales winnings, clamped so the
  /// average return stays below the EV ceiling. The risky game: most flips bust.
  FlipResult flip(int bet, Random rng, {double luck = 1.0}) {
    final double lf = effectiveLuck(luck, flipReturnToPlayer);
    int roll = rng.nextInt(flipTotalWeight);
    for (final o in flipTable) {
      if (roll < o.weight) {
        return FlipResult(o.zeros, o.multiplier, bet, luckFactor: lf);
      }
      roll -= o.weight;
    }
    final last = flipTable.last;
    return FlipResult(last.zeros, last.multiplier, bet, luckFactor: lf);
  }

  // ---- Relay (SIMULATED — UTXO only, strongly player-favoured) --------------
  // A packet relays through [plinkoRows] rows of nodes, going left/right 50/50 at
  // each, and lands in one of (rows + 1) binomial buckets. This is the SAFE game:
  // the worst bucket refunds the stake (1x, never a total loss), the sides win,
  // and the rare edges pay a 20x jackpot. EV ≈ 398/256 ≈ 1.55. Integer multipliers
  // so a bet of 1 still pays cleanly.
  static const int plinkoRows = 8;
  static const List<double> plinkoMultipliers = [
    20.0, 4.0, 2.0, 1.0, 1.0, 1.0, 2.0, 4.0, 20.0,
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

  /// Relay a packet through the nodes for [bet] UTXO using [rng]. [luck] (>=1)
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
