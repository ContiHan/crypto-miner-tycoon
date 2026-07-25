import 'package:flutter/material.dart';
import '../../core/ids.dart';
import '../channels.dart';
import 'class_manager.dart';

/// Data-driven SKILL node. Each node belongs to ONE class ([btcClass]) — or is
/// UNIVERSAL ([btcClass] == null, shown for every class) — and forms a tree via
/// [requires] (a node is buyable once every id it requires is at level >= 1).
/// Effects flow through the softcapped channel model (a null [channel] marks a
/// SPECIAL node, e.g. flat click power applied by EconomyService). Bought with
/// GovTokens; the whole tree resets each New Blockchain, like the run itself.
class PerkDef {
  final int baseCost;
  final Channel? channel;
  final double perLevel; // additive fraction into [channel] per level
  final int maxLevel; // 0 = unlimited
  final String name;
  final String description;
  final IconData icon;

  /// The class this node belongs to (null = universal, shown for all classes).
  final BtcClass? btcClass;

  /// Prerequisite node ids — this node is locked until each is at level >= 1.
  final List<String> requires;

  const PerkDef({
    required this.baseCost,
    this.channel,
    this.perLevel = 0,
    this.maxLevel = 0,
    this.name = '',
    this.description = '',
    this.icon = Icons.bolt,
    this.btcClass,
    this.requires = const [],
  });
}

class PerkManager {
  // The SKILL nodes. One UNIVERSAL flat-click node (kept so EconomyService's
  // click-power special stays wired + every class has a base), then a BESPOKE
  // tree per class routed through the softcapped channel model so nothing can
  // explode. Node ids are raw strings (self-documenting); [requires] wires them
  // into a tree the SKILL tab draws left→right by depth.
  static const Map<String, PerkDef> defs = {
    // --- Universal ---
    PerkIds.clickPower: PerkDef(
      baseCost: 5,
      name: 'CYBERNETIC FINGERS',
      description: '+2 manual click power per level.',
      icon: Icons.touch_app,
    ), // SPECIAL: flat click power, applied in EconomyService.calculateClickPower

    // --- SOLO MINER: garage tinkerer — cheap rigs, strong clicks, lucky finds ---
    'solo_scrounger': PerkDef(
      baseCost: 5,
      channel: Channel.rigCost,
      perLevel: 0.04,
      maxLevel: 15,
      name: 'SCRAPYARD SCROUNGER',
      description: 'Rigs 4% cheaper per level (max 60%).',
      icon: Icons.handyman,
      btcClass: BtcClass.soloMiner,
    ),
    'solo_caffeine': PerkDef(
      baseCost: 12,
      channel: Channel.click,
      perLevel: 0.04,
      name: 'CAFFEINE PROTOCOL',
      description: '+4% click power per level.',
      icon: Icons.local_cafe,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_scrounger'],
    ),
    'solo_multimeter': PerkDef(
      baseCost: 12,
      channel: Channel.luck,
      perLevel: 0.03,
      name: 'LUCKY MULTIMETER',
      description: '+3% Luck per level.',
      icon: Icons.electrical_services,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_scrounger'],
    ),
    'solo_bios': PerkDef(
      baseCost: 25,
      channel: Channel.rigCost,
      perLevel: 0.03,
      maxLevel: 15,
      name: 'HAND-TUNED BIOS',
      description: 'Rigs 3% cheaper per level (max 45%).',
      icon: Icons.tune,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_caffeine'],
    ),
    'solo_thumbs': PerkDef(
      baseCost: 40,
      channel: Channel.click,
      perLevel: 0.05,
      name: 'OVERCLOCKED THUMBS',
      description: '+5% click power per level.',
      icon: Icons.ads_click,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_caffeine'],
    ),
    'solo_sniffer': PerkDef(
      baseCost: 40,
      channel: Channel.luck,
      perLevel: 0.04,
      name: 'SIGNAL SNIFFER',
      description: '+4% Luck per level.',
      icon: Icons.wifi_find,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_multimeter'],
    ),
    'solo_fusion': PerkDef(
      baseCost: 80,
      channel: Channel.hash,
      perLevel: 0.03,
      name: 'GARAGE FUSION',
      description: '+3% global hash rate per level.',
      icon: Icons.whatshot,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_bios'],
    ),
    'solo_datacenter': PerkDef(
      baseCost: 150,
      channel: Channel.hash,
      perLevel: 0.04,
      name: 'ONE-MAN DATACENTER',
      description: '+4% global hash rate per level.',
      icon: Icons.dns,
      btcClass: BtcClass.soloMiner,
      requires: ['solo_thumbs', 'solo_sniffer'],
    ),

    // --- CORPORATION: brute force — huge hash + income, buy at scale ---
    'corp_serverfarm': PerkDef(
      baseCost: 5,
      channel: Channel.hash,
      perLevel: 0.04,
      name: 'SERVER FARM',
      description: '+4% global hash rate per level.',
      icon: Icons.storage,
      btcClass: BtcClass.corporation,
    ),
    'corp_ppa': PerkDef(
      baseCost: 12,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'POWER PURCHASE AGREEMENT',
      description: '+4% mining income per level.',
      icon: Icons.bolt,
      btcClass: BtcClass.corporation,
      requires: ['corp_serverfarm'],
    ),
    'corp_immersion': PerkDef(
      baseCost: 25,
      channel: Channel.hash,
      perLevel: 0.04,
      name: 'IMMERSION COOLING',
      description: '+4% global hash rate per level.',
      icon: Icons.ac_unit,
      btcClass: BtcClass.corporation,
      requires: ['corp_serverfarm'],
    ),
    'corp_marketmaker': PerkDef(
      baseCost: 40,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'MARKET MAKER',
      description: '+4% mining income per level.',
      icon: Icons.candlestick_chart,
      btcClass: BtcClass.corporation,
      requires: ['corp_ppa'],
    ),
    'corp_acquisition': PerkDef(
      baseCost: 40,
      channel: Channel.rigCost,
      perLevel: 0.03,
      maxLevel: 15,
      name: 'ACQUISITION SPREE',
      description: 'Rigs 3% cheaper per level (max 45%).',
      icon: Icons.shopping_cart,
      btcClass: BtcClass.corporation,
      requires: ['corp_immersion'],
    ),
    'corp_takeover': PerkDef(
      baseCost: 80,
      channel: Channel.hash,
      perLevel: 0.05,
      name: 'HOSTILE TAKEOVER',
      description: '+5% global hash rate per level.',
      icon: Icons.gavel,
      btcClass: BtcClass.corporation,
      requires: ['corp_immersion'],
    ),
    'corp_earnings': PerkDef(
      baseCost: 120,
      channel: Channel.income,
      perLevel: 0.05,
      name: 'QUARTERLY EARNINGS',
      description: '+5% mining income per level.',
      icon: Icons.trending_up,
      btcClass: BtcClass.corporation,
      requires: ['corp_marketmaker'],
    ),
    'corp_hyperscale': PerkDef(
      baseCost: 200,
      channel: Channel.hash,
      perLevel: 0.06,
      name: 'HYPERSCALE',
      description: '+6% global hash rate per level.',
      icon: Icons.hub,
      btcClass: BtcClass.corporation,
      requires: ['corp_takeover', 'corp_earnings'],
    ),

    // --- BTC OG: chain sage — luck + steady income, a slow hash bloom ---
    'og_notes': PerkDef(
      baseCost: 5,
      channel: Channel.luck,
      perLevel: 0.03,
      name: "SATOSHI'S NOTES",
      description: '+3% Luck per level.',
      icon: Icons.menu_book,
      btcClass: BtcClass.btcOg,
    ),
    'og_coldstorage': PerkDef(
      baseCost: 12,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'COLD STORAGE',
      description: '+4% mining income per level.',
      icon: Icons.ac_unit,
      btcClass: BtcClass.btcOg,
      requires: ['og_notes'],
    ),
    'og_whale': PerkDef(
      baseCost: 25,
      channel: Channel.luck,
      perLevel: 0.04,
      name: 'WHALE WATCHING',
      description: '+4% Luck per level.',
      icon: Icons.visibility,
      btcClass: BtcClass.btcOg,
      requires: ['og_notes'],
    ),
    'og_diamond': PerkDef(
      baseCost: 40,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'DIAMOND HANDS',
      description: '+4% mining income per level.',
      icon: Icons.diamond,
      btcClass: BtcClass.btcOg,
      requires: ['og_coldstorage'],
    ),
    'og_oracle': PerkDef(
      baseCost: 40,
      channel: Channel.luck,
      perLevel: 0.04,
      name: 'CHAIN ORACLE',
      description: '+4% Luck per level.',
      icon: Icons.auto_awesome,
      btcClass: BtcClass.btcOg,
      requires: ['og_whale'],
    ),
    'og_timelock': PerkDef(
      baseCost: 80,
      channel: Channel.hash,
      perLevel: 0.03,
      name: 'TIME-LOCKED WISDOM',
      description: '+3% global hash rate per level.',
      icon: Icons.lock_clock,
      btcClass: BtcClass.btcOg,
      requires: ['og_diamond'],
    ),
    'og_forkwhisper': PerkDef(
      baseCost: 80,
      channel: Channel.income,
      perLevel: 0.05,
      name: 'FORK WHISPERER',
      description: '+5% mining income per level.',
      icon: Icons.call_split,
      btcClass: BtcClass.btcOg,
      requires: ['og_oracle'],
    ),
    'og_halvingsage': PerkDef(
      baseCost: 200,
      channel: Channel.luck,
      perLevel: 0.05,
      name: 'THE HALVING SAGE',
      description: '+5% Luck per level.',
      icon: Icons.workspace_premium,
      btcClass: BtcClass.btcOg,
      requires: ['og_timelock', 'og_forkwhisper'],
    ),

    // --- POOL MEMBER: co-op — steady balanced income + luck, reliable uptime ---
    'pool_collective': PerkDef(
      baseCost: 5,
      channel: Channel.income,
      perLevel: 0.03,
      name: 'THE COLLECTIVE',
      description: '+3% mining income per level.',
      icon: Icons.groups,
      btcClass: BtcClass.poolMember,
    ),
    'pool_shares': PerkDef(
      baseCost: 12,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'FAIR SHARES',
      description: '+4% mining income per level.',
      icon: Icons.pie_chart,
      btcClass: BtcClass.poolMember,
      requires: ['pool_collective'],
    ),
    'pool_uptime': PerkDef(
      baseCost: 25,
      channel: Channel.hash,
      perLevel: 0.03,
      name: 'FIVE-NINES UPTIME',
      description: '+3% global hash rate per level.',
      icon: Icons.health_and_safety,
      btcClass: BtcClass.poolMember,
      requires: ['pool_collective'],
    ),
    'pool_loadbalance': PerkDef(
      baseCost: 40,
      channel: Channel.luck,
      perLevel: 0.03,
      name: 'LOAD BALANCER',
      description: '+3% Luck per level.',
      icon: Icons.balance,
      btcClass: BtcClass.poolMember,
      requires: ['pool_shares'],
    ),
    'pool_redundancy': PerkDef(
      baseCost: 40,
      channel: Channel.rigCost,
      perLevel: 0.03,
      maxLevel: 15,
      name: 'REDUNDANT RIGS',
      description: 'Rigs 3% cheaper per level (max 45%).',
      icon: Icons.dynamic_feed,
      btcClass: BtcClass.poolMember,
      requires: ['pool_uptime'],
    ),
    'pool_steady': PerkDef(
      baseCost: 80,
      channel: Channel.income,
      perLevel: 0.04,
      name: 'STEADY HANDS',
      description: '+4% mining income per level.',
      icon: Icons.back_hand,
      btcClass: BtcClass.poolMember,
      requires: ['pool_shares'],
    ),
    'pool_consensus': PerkDef(
      baseCost: 80,
      channel: Channel.luck,
      perLevel: 0.04,
      name: 'CONSENSUS BONUS',
      description: '+4% Luck per level.',
      icon: Icons.how_to_vote,
      btcClass: BtcClass.poolMember,
      requires: ['pool_loadbalance'],
    ),
    'pool_hivemind': PerkDef(
      baseCost: 200,
      channel: Channel.income,
      perLevel: 0.05,
      name: 'HIVE MIND',
      description: '+5% mining income per level.',
      icon: Icons.hive,
      btcClass: BtcClass.poolMember,
      requires: ['pool_steady', 'pool_consensus'],
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

  /// Whether [id] belongs to the active class (or is universal).
  bool _belongsTo(PerkDef def, BtcClass activeClass) =>
      def.btcClass == null || def.btcClass == activeClass;

  /// Adds every ACTIVE-class (+ universal) node's channel effect (× level) to
  /// [ch]. Non-active nodes are level 0 after a reset anyway, but we gate by
  /// class defensively so a stray level can never leak across classes.
  void contributeChannels(Channels ch, BtcClass activeClass) {
    defs.forEach((id, def) {
      if (def.channel == null) return;
      if (!_belongsTo(def, activeClass)) return;
      final level = getLevel(id);
      if (level <= 0) return;
      double value = level * def.perLevel;
      if (def.maxLevel > 0) {
        value = value.clamp(0.0, def.maxLevel * def.perLevel);
      }
      ch.add(def.channel!, value);
    });
  }

  /// Whether [id] is BUYABLE now: it belongs to the active class (or is
  /// universal) AND every prerequisite is at level >= 1. Nodes shown but not yet
  /// available render as locked "???" teasers.
  bool isAvailable(String id, BtcClass activeClass) {
    final def = defs[id];
    if (def == null || !_belongsTo(def, activeClass)) return false;
    for (final req in def.requires) {
      if (getLevel(req) < 1) return false;
    }
    return true;
  }

  bool isMaxed(String perkId) {
    final def = defs[perkId];
    return def != null && def.maxLevel > 0 && getLevel(perkId) >= def.maxLevel;
  }

  /// Human-readable current bonus for the given level (for the node sheet).
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
      case Channel.luck:
        return '+$pct% Luck';
      default:
        return '+$pct%';
    }
  }

  /// Buy a level of [perkId] if the player can afford it AND it is available for
  /// [activeClass]. Returns the cost paid (to deduct GovTokens), 0 if it failed.
  int tryBuy(String perkId, int currentGovTokens, BtcClass activeClass) {
    final def = defs[perkId];
    if (def == null) return 0;
    if (!isAvailable(perkId, activeClass)) return 0;
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
