import 'dart:math';
import '../../core/constants.dart';

class MiningManager {
  // State
  double blockReward = GameConstants.initialBlockReward;
  int blocksMined = 0;
  int nextHalvingThreshold = GameConstants.halvingFirstThreshold;
  // Neutralised in the Phase 1 redesign: kept at 1.0 for save compatibility.
  // Cross-era progression now comes from the prestige income multiplier, not a
  // compounding exchange rate (which overflowed to Infinity late-game).
  double bitcoinExchangeRate = 1.0;

  // Dependencies on GameLogic state (passed in or callbacks) could be tricky.
  // Instead, we return results of mining ticks.

  MiningManager();

  void reset() {
    blockReward = GameConstants.initialBlockReward;
    blocksMined = 0;
    nextHalvingThreshold = GameConstants.halvingFirstThreshold;
    bitcoinExchangeRate = 1.0;
  }

  void hardForkReset() {
    blocksMined = 0;
    blockReward = GameConstants.initialBlockReward;
    nextHalvingThreshold = GameConstants.halvingFirstThreshold;
    // Exchange rate stays 1.0 (neutralised). Cross-era power now comes from the
    // prestige income multiplier applied in GameLogic, not from this field.
  }

  // Calculate Network Difficulty
  double calculateNetworkDifficulty(double totalMined) {
    if (totalMined >= GameConstants.maxSupplySats) {
      // At the inviolable 21M/era cap the asymptote below divides by zero, so
      // the difficulty is ∞ (income has trickled to 0 — the era is fully mined).
      return double.infinity;
    }

    // 1. Asymptote
    double asymptote = 0.0;
    if (totalMined > 0) {
      asymptote =
          100.0 / pow(1.0 - (totalMined / GameConstants.maxSupplySats), 2) -
          100.0;
    }

    // 2. Linear Growth
    double linearGrowth = totalMined / 1000.0;

    return 100.0 + linearGrowth + asymptote;
  }

  // Returns the amount earned in this tick (or click).
  //
  // Phase 1 income model:
  //   income = hashRate * satPerHash * blockRewardFactor * prestige * chaos
  // No lifetime-difficulty divider (it collapsed income to ~0 within hours);
  // `difficulty` is retained in the signature as a display-only value and is
  // intentionally unused here.
  double calculateMiningIncome({
    required double hashRate,
    required double difficulty, // display-only; not used in the income math
    required double prestigeMultiplier,
    required double chaosMultiplier,
    required double lifetimeEarnings,
    double incomeMultiplier = 1.0, // INCOME channel (research/perks/stash)
  }) {
    if (hashRate <= 0) return 0;

    final double blockRewardFactor =
        blockReward / GameConstants.initialBlockReward; // 1.0 -> 0.5 -> ...
    double incomeSats = hashRate *
        GameConstants.satPerHash *
        blockRewardFactor *
        prestigeMultiplier *
        chaosMultiplier *
        incomeMultiplier;

    // Inviolable per-era 21M cap: income can never mine past the supply ceiling.
    final double room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) return 0;
    if (incomeSats > room) incomeSats = room;

    return incomeSats;
  }

  // Returns true if a halving occurred. The gap between halvings DOUBLES so
  // halvings are gentle pacing beats (an early ~hours-long era sees 0-1), not an
  // income killer — income grows until the rig-cost wall, then the next halving
  // tips it into the soft-wall that invites a prestige.
  bool checkHalving() {
    bool halved = false;
    while (blocksMined >= nextHalvingThreshold) {
      blockReward /= 2;
      nextHalvingThreshold *= 2;
      halved = true;
    }
    return halved;
  }

  void incrementBlocksMined() {
    blocksMined++;
  }
}
