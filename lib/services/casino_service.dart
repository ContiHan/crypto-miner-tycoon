import 'dart:math';
import '../core/constants.dart';

/// SIMULATED casino logic — pure, deterministic given a [Random]. No real money
/// or real-world value is ever involved: the only stake and prize is the in-game
/// Micro-Chip currency. Every game has a house edge (EV < 1) so it is a chip
/// sink, and the odds are disclosed in the UI for compliance.
class SlotOutcome {
  final String name;
  final List<String> symbols; // three reel symbols to display
  final double multiplier; // amount returned per chip staked (0 = loss)
  final int weight; // relative probability weight
  const SlotOutcome(this.name, this.symbols, this.multiplier, this.weight);
}

class SlotSpin {
  final List<String> symbols;
  final double multiplier;
  final int bet;
  const SlotSpin(this.symbols, this.multiplier, this.bet);

  int get payout => (bet * multiplier).floor();
  int get net => payout - bet;
  bool get isWin => payout > 0;
  bool get isJackpot => multiplier >= 25;
}

class CasinoService {
  // Weighted paytable. EV = sum(weight*multiplier)/sum(weight)
  //   = (1*25 + 3*10 + 8*5 + 20*3 + 120*1.5 + 220*0) / 372 = 335/372 ≈ 0.90.
  // So the house keeps ~10% over time — it's a chip sink with a jackpot thrill.
  static const List<SlotOutcome> slotTable = [
    SlotOutcome('JACKPOT', ['🌙', '🌙', '🌙'], 25.0, 1),
    SlotOutcome('Rockets', ['🚀', '🚀', '🚀'], 10.0, 3),
    SlotOutcome('Diamonds', ['💎', '💎', '💎'], 5.0, 8),
    SlotOutcome('Coins', ['🪙', '🪙', '🪙'], 3.0, 20),
    SlotOutcome('Pair', ['⚡', '⚡', '🪙'], 1.5, 120),
    SlotOutcome('Bust', ['⚡', '🪙', '💎'], 0.0, 220),
  ];

  static final int totalWeight =
      slotTable.fold(0, (sum, o) => sum + o.weight);

  /// Average return per chip staked on the slots (for the disclosed odds).
  static double get slotsReturnToPlayer =>
      slotTable.fold(0.0, (s, o) => s + o.weight * o.multiplier) / totalWeight;

  /// Spin the slots for [bet] chips using [rng].
  SlotSpin spinSlots(int bet, Random rng) {
    int roll = rng.nextInt(totalWeight);
    for (final o in slotTable) {
      if (roll < o.weight) return SlotSpin(o.symbols, o.multiplier, bet);
      roll -= o.weight;
    }
    final last = slotTable.last;
    return SlotSpin(last.symbols, last.multiplier, bet);
  }

  /// Double-or-Nothing: true = win (pays 2x). The sub-50% chance is the edge.
  bool flipWin(Random rng) =>
      rng.nextDouble() < GameConstants.casinoFlipWinChance;
}
