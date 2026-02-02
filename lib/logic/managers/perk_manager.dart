import '../../core/ids.dart';

class PerkManager {
  // Perks: keys are PerkIds
  Map<String, int> perks = {
    PerkIds.clickPower: 0,
    PerkIds.rigCost: 0,
    PerkIds.hashBonus: 0,
  };

  // Perk Config
  Map<String, int> perkCosts = {
    PerkIds.clickPower: 5,
    PerkIds.rigCost: 10,
    PerkIds.hashBonus: 15,
  };

  void reset() {
    perks.updateAll((key, value) => 0);
    // Reset costs
    perkCosts.updateAll((key, value) {
      switch (key) {
        case PerkIds.clickPower:
          return 5;
        case PerkIds.rigCost:
          return 10;
        case PerkIds.hashBonus:
          return 15;
        default:
          return 10;
      }
    });
  }

  // Returns cost if successful (to deduct from govTokens), 0 if failed
  int tryBuy(String perkId, int currentGovTokens) {
    if (perks.containsKey(perkId) && perkCosts.containsKey(perkId)) {
      int cost = perkCosts[perkId]!;

      // Check Max Level for Rig Cost
      if (perkId == PerkIds.rigCost && (perks[perkId] ?? 0) >= 18) {
        return 0; // Maxed out (90%)
      }

      if (currentGovTokens >= cost) {
        perks[perkId] = perks[perkId]! + 1;
        // Increase cost by +5 tokens per level
        perkCosts[perkId] = perkCosts[perkId]! + 5;
        return cost;
      }
    }
    return 0;
  }

  // Getters for Economy Service
  int getLevel(String perkId) => perks[perkId] ?? 0;
}
