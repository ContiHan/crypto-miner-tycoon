import 'dart:math';
import '../core/constants.dart';
import '../models/rig.dart';
import '../core/ids.dart';

class EconomyService {
  // +perTokenIncomeBonus income per GovToken (held + spent). This is the sole
  // cross-era power lever now (the exchange rate is neutralised); token accrual
  // is sub-linear and slow (see calculatePendingGovTokens) so the multiplier
  // grows steadily over weeks instead of exploding.
  double calculatePrestigeMultiplier(int govTokens, int spentGovTokens) {
    return 1.0 +
        ((govTokens + spentGovTokens) * GameConstants.perTokenIncomeBonus);
  }

  /// Rig cost after a total additive [costDiscount] (0.10 == 10% off), coming
  /// from the RIG_COST channel (perks + research + stash), clamped to a hard 95%
  /// max discount, then the chaos cost multiplier.
  double calculateRigCost(
    Rig rig,
    double costDiscount,
    double chaosCostMultiplier,
  ) {
    double factor = 1.0 - costDiscount;
    if (factor < 0.05) factor = 0.05; // hard cap: 95% max total discount
    return rig.currentCost * factor * chaosCostMultiplier;
  }

  /// Global hash rate: summed per-rig base (with the per-rig-type Chip Fab
  /// bonus) times the pre-computed HASH-channel multiplier (research + perks +
  /// stash, aggregated by GameLogic.buildChannels).
  double calculateGlobalHashRate(
    List<Rig> rigs,
    bool isChipFabResearched,
    double hashMultiplier,
  ) {
    double base = 0;
    for (var rig in rigs) {
      double rigRate = rig.totalHashRate;
      if (isChipFabResearched &&
          (rig.id == RigIds.cpuRig || rig.id == RigIds.gpuRig)) {
        rigRate *= (1.0 + GameConstants.chipFabBonus);
      }
      base += rigRate;
    }
    return base * hashMultiplier;
  }

  double calculateClickPower(Map<String, int> perks) {
    return GameConstants.perkBaseClickPower +
        ((perks[PerkIds.clickPower] ?? 0) * GameConstants.perkClickPowerGrowth);
  }

  int calculatePendingGovTokens(
    double lifetimeEarnings, {
    double gainMultiplier = 1.0,
  }) {
    if (lifetimeEarnings < GameConstants.govTokenDivisor) return 0;
    // Sub-linear (sqrt) in this era's earnings; the large divisor keeps early
    // eras to single-digit tokens and paces accrual to hundreds over weeks.
    // The tier-3 [gainMultiplier] scales the RAW root before flooring so partial
    // progress is preserved the same way Consensus (tier-1) preserves it.
    return (sqrt(lifetimeEarnings / GameConstants.govTokenDivisor) *
            gainMultiplier)
        .floor();
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
