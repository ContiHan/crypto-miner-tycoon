import 'dart:math';
import '../core/constants.dart';
import '../models/rig.dart';
import '../core/ids.dart';

class EconomyService {
  // Perks: 10% bonus per token (Held + Spent)
  double calculatePrestigeMultiplier(int govTokens, int spentGovTokens) {
    return 1.0 + ((govTokens + spentGovTokens) * 0.10);
  }

  double calculateRigCost(
    Rig rig,
    Map<String, int> perks,
    bool isBetterCoolingResearched,
    double chaosCostMultiplier, {
    bool isSolarPowerResearched = false,
  }) {
    double discountFactor =
        1.0 - ((perks[PerkIds.rigCost] ?? 0) * 0.05); // Max 90% (0.1 left)
    if (discountFactor < 0.1) discountFactor = 0.1; // Perk Cap at 90%

    // Research Discount
    if (isBetterCoolingResearched) {
      discountFactor -= GameConstants.coolingDiscount; // Better Cooling: -10%
    }

    // Solar Power Discount
    if (isSolarPowerResearched) {
      discountFactor -= GameConstants.solarDiscount; // Solar Power: -15%
    }

    // Hard Cap: Minimum 5% cost (95% max total discount)
    if (discountFactor < 0.05) discountFactor = 0.05;

    double cost = rig.currentCost * discountFactor;

    // Chaos Cost Multiplier
    cost *= chaosCostMultiplier;

    return cost;
  }

  double calculateGlobalHashRate(
    List<Rig> rigs,
    Map<String, int> perks,
    bool isChipFabResearched,
    double researchHashMultiplier,
  ) {
    double total = 0;

    // Calculate per-rig hashrate with research bonuses
    for (var rig in rigs) {
      double rigRate = rig.totalHashRate;

      // Chip Fab bonus for CPU/GPU
      if (isChipFabResearched &&
          (rig.id == RigIds.cpuRig || rig.id == RigIds.gpuRig)) {
        rigRate *= 1.20;
      }

      total += rigRate;
    }

    // Global research multiplier
    total *= researchHashMultiplier;

    // Apply 'hash_bonus' perk (10% per level)
    double perkMultiplier =
        1.0 +
        ((perks[PerkIds.hashBonus] ?? 0) * GameConstants.perkHashBonusGrowth);
    return total * perkMultiplier;
  }

  double calculateClickPower(Map<String, int> perks) {
    return GameConstants.perkBaseClickPower +
        ((perks[PerkIds.clickPower] ?? 0) * GameConstants.perkClickPowerGrowth);
  }

  int calculatePendingGovTokens(double lifetimeEarnings) {
    if (lifetimeEarnings < 10000) return 0;
    // Formula: Sqrt(Earnings / 10000) - adjusted for 10x economy scale
    return (sqrt(lifetimeEarnings / 10000).floor());
  }

  int recalculateSpentTokens(Map<String, int> perks) {
    int total = 0;
    perks.forEach((key, level) {
      if (level > 0) {
        int base = 10;
        if (key == PerkIds.clickPower) base = 5;
        if (key == PerkIds.hashBonus) base = 15;

        // Sum of arithmetic progression: n/2 * (2a + (n-1)d)
        // d = 5
        double spent = (level / 2) * (2 * base + (level - 1) * 5);
        total += spent.toInt();
      }
    });
    return total;
  }
}
