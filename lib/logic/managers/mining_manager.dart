import 'dart:math';
import '../../core/constants.dart';

class MiningManager {
  // State
  double blockReward = GameConstants.initialBlockReward;
  int blocksMined = 0;
  int nextHalvingThreshold = GameConstants.halvingFirstThreshold;

  // Dependencies on GameLogic state (passed in or callbacks) could be tricky.
  // Instead, we return results of mining ticks.

  MiningManager();

  void reset() {
    blockReward = GameConstants.initialBlockReward;
    blocksMined = 0;
    nextHalvingThreshold = GameConstants.halvingFirstThreshold;
  }

  void hardForkReset() {
    blocksMined = 0;
    blockReward = GameConstants.initialBlockReward;
    nextHalvingThreshold = GameConstants.halvingFirstThreshold;
    // Cross-era power comes from the prestige income multiplier applied in
    // GameLogic (the old compounding exchange-rate mechanic was removed).
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
    double halvingResist = 0.0, // STOCK-TO-FLOW: softens the halving cut (<=0.60)
  }) {
    if (hashRate <= 0) return 0;

    // 1.0 -> 0.5 -> 0.25 ... STOCK-TO-FLOW lifts a halved factor back toward 1.0
    // (f' = f + R·(1−f)) but never cancels a halving (R capped < 1).
    double blockRewardFactor = blockReward / GameConstants.initialBlockReward;
    if (halvingResist > 0 && blockRewardFactor < 1.0) {
      blockRewardFactor += halvingResist * (1.0 - blockRewardFactor);
    }
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
