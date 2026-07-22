import '../../core/ids.dart';
import '../channels.dart';

/// Data-driven perk definition. Adding a channel-effect perk is a one-line entry
/// in [PerkManager.defs]. A null [channel] marks a SPECIAL perk (e.g. flat click
/// power) applied explicitly by EconomyService.
class PerkDef {
  final int baseCost;
  final Channel? channel;
  final double perLevel; // additive fraction into [channel] per level
  final int maxLevel; // 0 = unlimited

  const PerkDef({
    required this.baseCost,
    this.channel,
    this.perLevel = 0,
    this.maxLevel = 0,
  });
}

class PerkManager {
  static const Map<String, PerkDef> defs = {
    // Flat click power is applied in EconomyService.calculateClickPower (special).
    PerkIds.clickPower: PerkDef(baseCost: 5),
    PerkIds.rigCost:
        PerkDef(baseCost: 10, channel: Channel.rigCost, perLevel: 0.05, maxLevel: 18),
    PerkIds.hashBonus:
        PerkDef(baseCost: 15, channel: Channel.hash, perLevel: 0.10),
  };

  // Runtime state (levels + current cost), built from defs.
  Map<String, int> perks = {for (final id in defs.keys) id: 0};
  Map<String, int> perkCosts = {
    for (final e in defs.entries) e.key: e.value.baseCost,
  };

  void reset() {
    perks.updateAll((key, value) => 0);
    perkCosts = {for (final e in defs.entries) e.key: e.value.baseCost};
  }

  /// Adds every perk's declared channel effect (× level) to [ch].
  void contributeChannels(Channels ch) {
    defs.forEach((id, def) {
      if (def.channel == null) return;
      final level = getLevel(id);
      if (level <= 0) return;
      double value = level * def.perLevel;
      if (def.maxLevel > 0) {
        value = value.clamp(0.0, def.maxLevel * def.perLevel);
      }
      ch.add(def.channel!, value);
    });
  }

  // Returns cost if successful (to deduct from govTokens), 0 if failed
  int tryBuy(String perkId, int currentGovTokens) {
    final def = defs[perkId];
    if (def == null) return 0;

    if (def.maxLevel > 0 && getLevel(perkId) >= def.maxLevel) {
      return 0; // maxed out
    }

    final cost = perkCosts[perkId]!;
    if (currentGovTokens >= cost) {
      perks[perkId] = getLevel(perkId) + 1;
      perkCosts[perkId] = cost + 5; // +5 tokens per level
      return cost;
    }
    return 0;
  }

  int getLevel(String perkId) => perks[perkId] ?? 0;
}
