import 'dart:math';
import '../core/constants.dart';
import '../models/rig.dart';
import '../core/ids.dart';
import '../logic/managers/perk_manager.dart';

class EconomyService {
  // Cross-era income multiplier from GovTokens (held + spent). CONCAVE in the
  // token count (perTokenIncomeBonus * sqrt(tokens)) so that even when tokens
  // accumulate across thousands of hard forks the multiplier grows ~linearly in
  // time rather than exploding — a linear-per-token bonus turned the endgame
  // into a runaway once the new prestige tiers pumped income into the per-era
  // cap. Token accrual itself is also sub-linear (see calculatePendingGovTokens).
  double calculatePrestigeMultiplier(int govTokens, int spentGovTokens) {
    return 1.0 +
        GameConstants.perTokenIncomeBonus * sqrt(govTokens + spentGovTokens);
  }

  /// Rig cost after a total additive [costDiscount] (0.10 == 10% off), coming
  /// from the RIG_COST channel (perks + research + stash), clamped to a hard 95%
  /// max discount, then the chaos cost multiplier and any [abilityCostMultiplier]
  /// (e.g. HOSTILE TAKEOVER's ×0.5). The FINAL PRODUCT of every cost multiplier is
  /// floored at 0.05 (BALANCE_AND_BOUNDS #6): the channel discount alone is capped
  /// at 95% off, but 0.05 × CHEAP-ENERGY 0.7 × a future ability 0.5 would reach
  /// ~1.75% of base — so we clamp the whole product so a rig can never cost less
  /// than 5% of its sticker price no matter how the discounts stack.
  double calculateRigCost(
    Rig rig,
    double costDiscount,
    double chaosCostMultiplier, {
    double abilityCostMultiplier = 1.0,
  }) {
    double factor = 1.0 - costDiscount;
    if (factor < 0.05) factor = 0.05; // channel discount hard cap (95% max)
    double product = factor * chaosCostMultiplier * abilityCostMultiplier;
    if (product < 0.05) product = 0.05; // FINAL product floor (#6)
    return rig.currentCost * product;
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
        // Base cost comes from the perk definition (was hardcoded, which
        // under-counted the 9 progressive perks whose baseCost is 20-500).
        final int base = PerkManager.defs[key]?.baseCost ?? 10;

        // Sum of arithmetic progression: n/2 * (2a + (n-1)d), d = 5 (matches
        // the +5-per-level cost growth in PerkManager.tryBuy).
        double spent = (level / 2) * (2 * base + (level - 1) * 5);
        total += spent.toInt();
      }
    });
    return total;
  }
}
