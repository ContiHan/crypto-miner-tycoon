import 'package:flutter/material.dart';
import '../../core/ids.dart';
import '../channels.dart';

/// Data-driven perk definition. Adding a channel-effect perk is a one-line entry
/// in [PerkManager.defs]: declare its channel, per-level effect, display data and
/// the cumulative-GovTokens threshold at which it reveals. A null [channel] marks
/// a SPECIAL perk (e.g. flat click power) applied explicitly by EconomyService.
class PerkDef {
  final int baseCost;
  final Channel? channel;
  final double perLevel; // additive fraction into [channel] per level
  final int maxLevel; // 0 = unlimited
  final String name;
  final String description;
  final IconData icon;

  /// Reveals in the PERKS list once totalGovTokensEver reaches this — progressive
  /// discovery so the list grows as the player prestiges (0 = visible from start).
  final double unlockAtTokensEver;

  const PerkDef({
    required this.baseCost,
    this.channel,
    this.perLevel = 0,
    this.maxLevel = 0,
    this.name = '',
    this.description = '',
    this.icon = Icons.bolt,
    this.unlockAtTokensEver = 0,
  });
}

class PerkManager {
  // Ordered by unlock threshold. Effects flow through the channel model
  // (additive within a channel) so stacking a dozen perks never explodes.
  static const Map<String, PerkDef> defs = {
    // --- Tier 0: available from the first GovTokens ---
    PerkIds.clickPower: PerkDef(
      baseCost: 5,
      name: 'CYBERNETIC FINGERS',
      description: '+2 manual click power per level.',
      icon: Icons.touch_app,
    ), // SPECIAL: flat click power, applied in EconomyService.calculateClickPower
    PerkIds.rigCost: PerkDef(
      baseCost: 10,
      channel: Channel.rigCost,
      perLevel: 0.05,
      maxLevel: 18,
      name: 'EFFICIENT BIOS',
      description: 'Rigs 5% cheaper per level (max 90%).',
      icon: Icons.price_check,
    ),
    PerkIds.hashBonus: PerkDef(
      baseCost: 15,
      channel: Channel.hash,
      perLevel: 0.10,
      name: 'NEURAL OVERCLOCK',
      description: '+10% global hash rate per level.',
      icon: Icons.psychology,
    ),
    // --- Progressive unlocks ---
    PerkIds.clickBoost: PerkDef(
      baseCost: 20,
      channel: Channel.click,
      perLevel: 0.15,
      unlockAtTokensEver: 3,
      name: 'REFLEX BOOSTER',
      description: '+15% click power per level.',
      icon: Icons.ads_click,
    ),
    PerkIds.incomeBoost: PerkDef(
      baseCost: 25,
      channel: Channel.income,
      perLevel: 0.08,
      unlockAtTokensEver: 5,
      name: 'YIELD OPTIMIZER',
      description: '+8% mining income per level.',
      icon: Icons.trending_up,
    ),
    PerkIds.hashSurge: PerkDef(
      baseCost: 40,
      channel: Channel.hash,
      perLevel: 0.20,
      unlockAtTokensEver: 15,
      name: 'QUANTUM THREADS',
      description: '+20% global hash rate per level.',
      icon: Icons.bolt,
    ),
    PerkIds.costCutter: PerkDef(
      baseCost: 60,
      channel: Channel.rigCost,
      perLevel: 0.03,
      maxLevel: 20,
      unlockAtTokensEver: 25,
      name: 'SUPPLY CHAIN AI',
      description: 'Rigs 3% cheaper per level (max 60%).',
      icon: Icons.inventory_2,
    ),
    PerkIds.clickSurge: PerkDef(
      baseCost: 80,
      channel: Channel.click,
      perLevel: 0.30,
      unlockAtTokensEver: 50,
      name: 'OVERCLOCKED REFLEXES',
      description: '+30% click power per level.',
      icon: Icons.speed,
    ),
    PerkIds.incomeSurge: PerkDef(
      baseCost: 120,
      channel: Channel.income,
      perLevel: 0.15,
      unlockAtTokensEver: 100,
      name: 'COMPOUND INTEREST',
      description: '+15% mining income per level.',
      icon: Icons.stacked_line_chart,
    ),
    PerkIds.megaHash: PerkDef(
      baseCost: 200,
      channel: Channel.hash,
      perLevel: 0.30,
      unlockAtTokensEver: 250,
      name: 'FUSION CORE TUNING',
      description: '+30% global hash rate per level.',
      icon: Icons.whatshot,
    ),
    PerkIds.deepDiscount: PerkDef(
      baseCost: 300,
      channel: Channel.rigCost,
      perLevel: 0.02,
      maxLevel: 25,
      unlockAtTokensEver: 500,
      name: 'VERTICAL INTEGRATION',
      description: 'Rigs 2% cheaper per level (max 50%).',
      icon: Icons.factory,
    ),
    PerkIds.megaIncome: PerkDef(
      baseCost: 500,
      channel: Channel.income,
      perLevel: 0.25,
      unlockAtTokensEver: 1500,
      name: 'YIELD SINGULARITY',
      description: '+25% mining income per level.',
      icon: Icons.auto_awesome,
    ),
    // --- Volume expansion 2 (deep endgame perks) ---
    PerkIds.hyperClick: PerkDef(
      baseCost: 150,
      channel: Channel.click,
      perLevel: 0.50,
      unlockAtTokensEver: 750,
      name: 'HYPERCLICK',
      description: '+50% click power per level.',
      icon: Icons.bolt,
    ),
    PerkIds.yieldEngine: PerkDef(
      baseCost: 400,
      channel: Channel.income,
      perLevel: 0.30,
      unlockAtTokensEver: 3000,
      name: 'YIELD ENGINE',
      description: '+30% mining income per level.',
      icon: Icons.trending_up,
    ),
    PerkIds.quantumCores: PerkDef(
      baseCost: 600,
      channel: Channel.hash,
      perLevel: 0.40,
      unlockAtTokensEver: 5000,
      name: 'QUANTUM CORES',
      description: '+40% global hash rate per level.',
      icon: Icons.memory,
    ),
    PerkIds.autoTrader: PerkDef(
      baseCost: 800,
      channel: Channel.income,
      perLevel: 0.40,
      unlockAtTokensEver: 7500,
      name: 'AUTO-TRADER',
      description: '+40% mining income per level.',
      icon: Icons.smart_toy,
    ),
    PerkIds.overclockArray: PerkDef(
      baseCost: 1000,
      channel: Channel.hash,
      perLevel: 0.50,
      unlockAtTokensEver: 10000,
      name: 'OVERCLOCK ARRAY',
      description: '+50% global hash rate per level.',
      icon: Icons.dns,
    ),
    PerkIds.bulkDiscount: PerkDef(
      baseCost: 1500,
      channel: Channel.rigCost,
      perLevel: 0.02,
      maxLevel: 25,
      unlockAtTokensEver: 15000,
      name: 'BULK DISCOUNT',
      description: 'Rigs 2% cheaper per level (max 50%).',
      icon: Icons.local_shipping,
    ),
    PerkIds.clickSingularity: PerkDef(
      baseCost: 3000,
      channel: Channel.click,
      perLevel: 0.75,
      unlockAtTokensEver: 25000,
      name: 'CLICK SINGULARITY',
      description: '+75% click power per level.',
      icon: Icons.ads_click,
    ),
    PerkIds.incomeSingularity: PerkDef(
      baseCost: 5000,
      channel: Channel.income,
      perLevel: 0.50,
      unlockAtTokensEver: 50000,
      name: 'INCOME SINGULARITY',
      description: '+50% mining income per level.',
      icon: Icons.auto_awesome_motion,
    ),
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

  /// Whether [perkId] has revealed yet (progressive discovery).
  bool isUnlocked(String perkId, double totalGovTokensEver) {
    final def = defs[perkId];
    return def != null && totalGovTokensEver >= def.unlockAtTokensEver;
  }

  bool isMaxed(String perkId) {
    final def = defs[perkId];
    return def != null && def.maxLevel > 0 && getLevel(perkId) >= def.maxLevel;
  }

  /// Human-readable current bonus for the given level (for the PERKS list).
  String bonusText(String perkId, int level) {
    final def = defs[perkId];
    if (def == null) return '';
    if (def.channel == null) {
      return '+${level * 2} Click Power'; // SPECIAL flat click perk
    }
    double frac = level * def.perLevel;
    if (def.maxLevel > 0) {
      frac = frac.clamp(0.0, def.maxLevel * def.perLevel);
    }
    final pct = (frac * 100).toStringAsFixed(0);
    switch (def.channel!) {
      case Channel.hash:
        return '+$pct% Hash Rate';
      case Channel.rigCost:
        return '-$pct% Rig Cost';
      case Channel.income:
        return '+$pct% Income';
      case Channel.click:
        return '+$pct% Click Power';
      default:
        return '+$pct%';
    }
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
