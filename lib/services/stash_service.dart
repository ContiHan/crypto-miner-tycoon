import 'dart:math';
import '../logic/channels.dart';

/// Six rarities (content plan). Order is ascending power; `.index` doubles as a
/// rank for sorting/coloring.
enum ArtifactRarity { common, uncommon, rare, epic, legendary, mythic }

enum BonusType {
  hashRate, // Global Hash Rate Multiplier
  rigCost, // Discount on Rigs
  clickPower, // Click Power Multiplier
  luck, // Luck: crit chance + SWEEP winnings (capped) + crate/anomaly odds
  vcInterval, // legacy, unused
  critPayout, // BLOCK REWARD attribute: crit PAYOUT via Channel.special
}

class Artifact {
  final String id;
  final String name;
  final String description;
  final ArtifactRarity rarity;
  final BonusType bonusType;
  final double baseBonus; // e.g. 0.05 for 5%

  const Artifact({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.bonusType,
    required this.baseBonus,
  });
}

/// The four crate tiers you buy with UTXO. Higher tiers cost more and shift the
/// whole drop table up (scrap = mostly Common; quantum = Epic floor). [weights]
/// is a rarity → relative-weight table (geometric ladder); a rarity absent from
/// the map can't drop from that crate.
enum CrateTier { scrap, standard, premium, quantum }

class CrateDef {
  final CrateTier tier;
  final String name;
  final int cost; // UTXO
  final String blurb; // odds summary shown on the card
  final Map<ArtifactRarity, double> weights;
  const CrateDef({
    required this.tier,
    required this.name,
    required this.cost,
    required this.blurb,
    required this.weights,
  });
}

const List<CrateDef> kCrates = [
  CrateDef(
    tier: CrateTier.scrap,
    name: 'SCRAP',
    cost: 5,
    blurb: 'Cheap gamble · mostly Common, ~8% Rare+',
    weights: {
      ArtifactRarity.common: 70,
      ArtifactRarity.uncommon: 22,
      ArtifactRarity.rare: 6,
      ArtifactRarity.epic: 1.7,
      ArtifactRarity.legendary: 0.3,
    },
  ),
  CrateDef(
    tier: CrateTier.standard,
    name: 'STANDARD',
    cost: 10,
    blurb: 'Common / Uncommon · 12% Rare, rare Epic+',
    weights: {
      ArtifactRarity.common: 55,
      ArtifactRarity.uncommon: 27,
      ArtifactRarity.rare: 12,
      ArtifactRarity.epic: 4.5,
      ArtifactRarity.legendary: 1.2,
      ArtifactRarity.mythic: 0.3,
    },
  ),
  CrateDef(
    tier: CrateTier.premium,
    name: 'PREMIUM',
    cost: 50,
    blurb: 'Rare floor · Epic 31% · Leg 14% · Myth 5%',
    weights: {
      ArtifactRarity.rare: 50,
      ArtifactRarity.epic: 31,
      ArtifactRarity.legendary: 14,
      ArtifactRarity.mythic: 5,
    },
  ),
  CrateDef(
    tier: CrateTier.quantum,
    name: 'QUANTUM',
    cost: 200,
    blurb: 'Epic floor · Leg 38% · Myth 17%',
    weights: {
      ArtifactRarity.epic: 45,
      ArtifactRarity.legendary: 38,
      ArtifactRarity.mythic: 17,
    },
  ),
];

/// The [CrateDef] for [tier].
CrateDef crateDef(CrateTier tier) => kCrates.firstWhere((c) => c.tier == tier);

class StashService {
  // === DATABASE OF ARTIFACTS ===
  // Data-driven: add rows here to grow content. baseBonus follows per-rarity
  // additive bands (common 1-3% ... mythic 200%+) so stacking never explodes.
  static const List<Artifact> allArtifacts = [
    // --- COMMON (+1-3%) ---
    Artifact(id: 'old_hdd', name: 'Old HDD', description: '+2% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.02),
    Artifact(id: 'usb_fan', name: 'USB Fan', description: '-1% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.01),
    Artifact(id: 'energy_drink', name: 'Energy Drink', description: '+3% Click Power', rarity: ArtifactRarity.common, bonusType: BonusType.clickPower, baseBonus: 0.03),
    Artifact(id: 'lucky_coin', name: 'Lucky Coin', description: '+2% Luck', rarity: ArtifactRarity.common, bonusType: BonusType.luck, baseBonus: 0.02),
    Artifact(id: 'cable_tie', name: 'Cable Tie', description: '-1% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.01),
    Artifact(id: 'dust_filter', name: 'Dust Filter', description: '+3% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.03),
    Artifact(id: 'rgb_strip', name: 'RGB Strip', description: '+2% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.02),
    Artifact(id: 'spare_ram', name: 'Spare RAM Stick', description: '+3% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.03),
    Artifact(id: 'zip_tie', name: 'Zip Tie', description: '-1% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.01),
    Artifact(id: 'thermal_pad', name: 'Thermal Pad', description: '-2% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.02),
    Artifact(id: 'sticker_pack', name: 'Hacker Sticker Pack', description: '+2% Click Power', rarity: ArtifactRarity.common, bonusType: BonusType.clickPower, baseBonus: 0.02),
    Artifact(id: 'ethernet_cable', name: 'Ethernet Cable', description: '+2% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.02),
    Artifact(id: 'old_gpu', name: 'Ancient GPU', description: '+3% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.03),
    Artifact(id: 'desk_fan', name: 'Desk Fan', description: '-2% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.02),
    Artifact(id: 'coffee_mug', name: 'Coffee Mug', description: '+3% Click Power', rarity: ArtifactRarity.common, bonusType: BonusType.clickPower, baseBonus: 0.03),

    // --- UNCOMMON (+4-8%) ---
    Artifact(id: 'overclock_bios', name: 'Overclock BIOS', description: '+6% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.06),
    Artifact(id: 'copper_heatsink', name: 'Copper Heatsink', description: '-4% Rig Cost', rarity: ArtifactRarity.uncommon, bonusType: BonusType.rigCost, baseBonus: 0.04),
    Artifact(id: 'gaming_mouse', name: 'Gaming Mouse', description: '+8% Click Power', rarity: ArtifactRarity.uncommon, bonusType: BonusType.clickPower, baseBonus: 0.08),
    Artifact(id: 'refurb_psu', name: 'Refurb PSU', description: '+5% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.05),
    Artifact(id: 'pcie_riser', name: 'PCIe Riser', description: '+7% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.07),
    Artifact(id: 'ssd_cache', name: 'SSD Cache', description: '+8% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.08),
    Artifact(id: 'laptop_cooler', name: 'Laptop Cooler', description: '-5% Rig Cost', rarity: ArtifactRarity.uncommon, bonusType: BonusType.rigCost, baseBonus: 0.05),
    Artifact(id: 'power_strip', name: 'Surge Power Strip', description: '-6% Rig Cost', rarity: ArtifactRarity.uncommon, bonusType: BonusType.rigCost, baseBonus: 0.06),
    Artifact(id: 'mech_keyboard', name: 'Mech Keyboard', description: '+6% Click Power', rarity: ArtifactRarity.uncommon, bonusType: BonusType.clickPower, baseBonus: 0.06),
    Artifact(id: 'noctua_fan', name: 'Noctua Fan', description: '-5% Rig Cost', rarity: ArtifactRarity.uncommon, bonusType: BonusType.rigCost, baseBonus: 0.05),
    Artifact(id: 'ram_upgrade', name: 'RAM Upgrade', description: '+6% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.06),
    Artifact(id: 'psu_gold', name: 'Gold-Rated PSU', description: '+8% Hash Rate', rarity: ArtifactRarity.uncommon, bonusType: BonusType.hashRate, baseBonus: 0.08),
    Artifact(id: 'gaming_chair', name: 'Gaming Chair', description: '+7% Click Power', rarity: ArtifactRarity.uncommon, bonusType: BonusType.clickPower, baseBonus: 0.07),

    // --- RARE (+10-20%) ---
    Artifact(id: 'liquid_cooling', name: 'Liquid Cooling Loop', description: '+10% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.10),
    Artifact(id: 'gold_thermal_paste', name: 'Gold Thermal Paste', description: '-10% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.10),
    Artifact(id: 'mechanical_switch', name: 'Mech Switch', description: '+20% Click Power', rarity: ArtifactRarity.rare, bonusType: BonusType.clickPower, baseBonus: 0.20),
    Artifact(id: 'server_rack', name: 'Pro Server Rack', description: '-8% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.08),
    Artifact(id: 'gpu_riser', name: 'GPU Riser Array', description: '+15% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.15),
    Artifact(id: 'water_block', name: 'CPU Water Block', description: '+12% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.12),
    Artifact(id: 'asic_fan', name: 'ASIC Blower Fan', description: '+18% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.18),
    Artifact(id: 'dual_psu', name: 'Dual PSU Rig', description: '-10% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.10),
    Artifact(id: 'bulk_contract', name: 'Bulk Contract', description: '-12% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.12),
    Artifact(id: 'macro_pad', name: 'Macro Pad', description: '+15% Click Power', rarity: ArtifactRarity.rare, bonusType: BonusType.clickPower, baseBonus: 0.15),
    Artifact(id: 'nvme_array', name: 'NVMe Array', description: '+14% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.14),
    Artifact(id: 'custom_loop', name: 'Custom Water Loop', description: '+16% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.16),
    Artifact(id: 'wholesale_deal', name: 'Wholesale Deal', description: '-12% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.12),
    Artifact(id: 'streamdeck', name: 'Stream Deck', description: '+18% Click Power', rarity: ArtifactRarity.rare, bonusType: BonusType.clickPower, baseBonus: 0.18),

    // --- EPIC (+25-50%) ---
    Artifact(id: 'immersion_tank', name: 'Immersion Tank', description: '+30% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.30),
    Artifact(id: 'fpga_board', name: 'FPGA Board', description: '+40% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.40),
    Artifact(id: 'procurement_ai', name: 'Procurement AI', description: '-15% Rig Cost', rarity: ArtifactRarity.epic, bonusType: BonusType.rigCost, baseBonus: 0.15),
    Artifact(id: 'haptic_deck', name: 'Haptic Deck', description: '+50% Click Power', rarity: ArtifactRarity.epic, bonusType: BonusType.clickPower, baseBonus: 0.50),
    Artifact(id: 'vapor_chamber', name: 'Vapor Chamber', description: '+35% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.35),
    Artifact(id: 'power_grid_tap', name: 'Power Grid Tap', description: '+45% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.45),
    Artifact(id: 'factory_deal', name: 'Factory-Direct Deal', description: '-18% Rig Cost', rarity: ArtifactRarity.epic, bonusType: BonusType.rigCost, baseBonus: 0.18),
    Artifact(id: 'turbo_clicker', name: 'Turbo Clicker', description: '+40% Click Power', rarity: ArtifactRarity.epic, bonusType: BonusType.clickPower, baseBonus: 0.40),
    Artifact(id: 'ln2_cooling', name: 'LN2 Cooling', description: '+38% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.38),
    Artifact(id: 'mining_pool', name: 'Private Mining Pool', description: '+42% Hash Rate', rarity: ArtifactRarity.epic, bonusType: BonusType.hashRate, baseBonus: 0.42),
    Artifact(id: 'tax_writeoff', name: 'Tax Write-Off', description: '-16% Rig Cost', rarity: ArtifactRarity.epic, bonusType: BonusType.rigCost, baseBonus: 0.16),
    Artifact(id: 'neural_glove', name: 'Neural Glove', description: '+45% Click Power', rarity: ArtifactRarity.epic, bonusType: BonusType.clickPower, baseBonus: 0.45),

    // --- LEGENDARY (+75-150%) ---
    Artifact(id: 'quantum_chip', name: 'Quantum Chip Prototype', description: '+75% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 0.75),
    Artifact(id: 'ai_optimiser', name: 'AI Cost Optimiser', description: '-20% Rig Cost', rarity: ArtifactRarity.legendary, bonusType: BonusType.rigCost, baseBonus: 0.20),
    Artifact(id: 'satoshi_whitepaper', name: 'The Whitepaper', description: '+100% Click Power', rarity: ArtifactRarity.legendary, bonusType: BonusType.clickPower, baseBonus: 1.0),
    Artifact(id: 'superconductor', name: 'Superconductor Coil', description: '+150% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 1.5),
    Artifact(id: 'fusion_cell', name: 'Fusion Cell', description: '+90% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 0.90),
    Artifact(id: 'photon_array', name: 'Photon Array', description: '+125% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 1.25),
    Artifact(id: 'vc_backing', name: 'VC Backing', description: '-25% Rig Cost', rarity: ArtifactRarity.legendary, bonusType: BonusType.rigCost, baseBonus: 0.25),
    Artifact(id: 'golden_keyboard', name: 'Golden Keyboard', description: '+125% Click Power', rarity: ArtifactRarity.legendary, bonusType: BonusType.clickPower, baseBonus: 1.25),
    Artifact(id: 'graphene_chip', name: 'Graphene Chip', description: '+100% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 1.0),
    Artifact(id: 'perpetual_motion', name: 'Perpetual Motion Rig', description: '+140% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 1.4),
    Artifact(id: 'offshore_account', name: 'Offshore Account', description: '-22% Rig Cost', rarity: ArtifactRarity.legendary, bonusType: BonusType.rigCost, baseBonus: 0.22),
    Artifact(id: 'exoskeleton', name: 'Clicking Exoskeleton', description: '+140% Click Power', rarity: ArtifactRarity.legendary, bonusType: BonusType.clickPower, baseBonus: 1.4),

    // --- MYTHIC (+200%+) ---
    Artifact(id: 'genesis_shard', name: 'Genesis Shard', description: '+200% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 2.0),
    Artifact(id: 'cold_wallet_vault', name: 'Cold Wallet Vault', description: '-30% Rig Cost', rarity: ArtifactRarity.mythic, bonusType: BonusType.rigCost, baseBonus: 0.30),
    Artifact(id: 'diamond_hands', name: 'Diamond Hands', description: '+300% Click Power', rarity: ArtifactRarity.mythic, bonusType: BonusType.clickPower, baseBonus: 3.0),
    Artifact(id: 'singularity_core', name: 'Singularity Core', description: '+250% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 2.5),
    Artifact(id: 'dyson_swarm', name: 'Dyson Swarm', description: '+300% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 3.0),
    Artifact(id: 'infinite_ledger', name: 'The Infinite Ledger', description: '+225% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 2.25),
    Artifact(id: 'black_hole_psu', name: 'Black Hole PSU', description: '-35% Rig Cost', rarity: ArtifactRarity.mythic, bonusType: BonusType.rigCost, baseBonus: 0.35),
    Artifact(id: 'midas_touch', name: 'Midas Touch', description: '+400% Click Power', rarity: ArtifactRarity.mythic, bonusType: BonusType.clickPower, baseBonus: 4.0),
    Artifact(id: 'halving_relic', name: 'Halving Relic', description: '+500% Click Power', rarity: ArtifactRarity.mythic, bonusType: BonusType.clickPower, baseBonus: 5.0),
    Artifact(id: 'antimatter_reactor', name: 'Antimatter Reactor', description: '+275% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 2.75),
    Artifact(id: 'time_machine', name: 'Time Machine', description: '+350% Hash Rate', rarity: ArtifactRarity.mythic, bonusType: BonusType.hashRate, baseBonus: 3.5),
    Artifact(id: 'philosophers_stone', name: "Philosopher's Stone", description: '+450% Click Power', rarity: ArtifactRarity.mythic, bonusType: BonusType.clickPower, baseBonus: 4.5),

    // --- BLOCK REWARD (crit payout, Channel.special) ---
    Artifact(id: 'lucky_nonce', name: 'Lucky Nonce', description: '+8% Block Reward', rarity: ArtifactRarity.uncommon, bonusType: BonusType.critPayout, baseBonus: 0.08),
    Artifact(id: 'golden_hash', name: 'Golden Hash', description: '+20% Block Reward', rarity: ArtifactRarity.rare, bonusType: BonusType.critPayout, baseBonus: 0.20),
    Artifact(id: 'jackpot_seed', name: 'Jackpot Seed', description: '+50% Block Reward', rarity: ArtifactRarity.epic, bonusType: BonusType.critPayout, baseBonus: 0.50),
    Artifact(id: 'genesis_coinbase', name: 'Genesis Coinbase', description: '+120% Block Reward', rarity: ArtifactRarity.legendary, bonusType: BonusType.critPayout, baseBonus: 1.20),
  ];


  // === STATE ===
  // Map<ArtifactId, Count/Level>
  Map<String, int> _ownedArtifacts = {};
  
  Map<String, int> get ownedArtifacts => _ownedArtifacts;

  void loadStash(Map<String, dynamic> data) {
    if (data.containsKey('artifacts')) {
      _ownedArtifacts = Map<String, int>.from(data['artifacts']);
    }
  }

  Map<String, dynamic> saveStash() {
    return {
      'artifacts': _ownedArtifacts,
    };
  }

  // === CALCULATORS ===
  
  // Returns multiplier (e.g. 1.25 for +25%)
  double getTotalHashBonus() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.hashRate) {
        total += artifact.baseBonus * count; // Linear stacking
      }
    });
    return 1.0 + total;
  }

  double getMainCostDiscount() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.rigCost) {
        total += artifact.baseBonus * count;
      }
    });
    // Cap at some reasonable simplified limit if needed, logic service handles final clamp
    return total; 
  }

  /// Raw additive click-power bonus from owned artifacts (0.20 == +20% click).
  /// Fed into [Channel.click] so it shares the click softcap with perks/TECH
  /// (BALANCE_AND_BOUNDS #19 — it must NOT be a raw 1+Σ multiplier outside the
  /// softcap, or a stack of mythic click artifacts becomes an uncapped lane).
  double getClickPowerBonus() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.clickPower) {
        total += artifact.baseBonus * count;
      }
    });
    return total;
  }

  /// Raw additive Luck bonus from owned artifacts (0.05 == +5% luck).
  double getTotalLuckBonus() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.luck) {
        total += artifact.baseBonus * count;
      }
    });
    return total;
  }

  /// Raw additive crit-PAYOUT bonus from owned artifacts, fed into the `special`
  /// channel (BLOCK REWARD attribute). 1.0 == +1 unit of Σspecial.
  double getTotalCritPayoutBonus() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.critPayout) {
        total += artifact.baseBonus * count;
      }
    });
    return total;
  }

  /// Adds owned-artifact hash, rig-cost, luck & click bonuses to the shared
  /// channel model — everything routes through the softcapped channels (no raw
  /// out-of-band multipliers).
  void contributeChannels(Channels ch) {
    ch.add(Channel.hash, getTotalHashBonus() - 1.0); // getTotalHashBonus = 1+sum
    ch.add(Channel.rigCost, getMainCostDiscount()); // already a raw sum
    ch.add(Channel.luck, getTotalLuckBonus()); // raw sum
    ch.add(Channel.click, getClickPowerBonus()); // raw sum, now softcapped (#19)
    ch.add(Channel.special, getTotalCritPayoutBonus()); // crit payout (BLOCK REWARD)
  }
  
  // === LOOT LOGIC ===
  
  Artifact? _getArtifact(String id) {
    try {
      return allArtifacts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Rolls a rarity from a crate's weighted table.
  ArtifactRarity _rollRarity(Random random, Map<ArtifactRarity, double> weights) {
    final total = weights.values.fold(0.0, (a, b) => a + b);
    double roll = random.nextDouble() * total;
    for (final entry in weights.entries) {
      if (roll < entry.value) return entry.key;
      roll -= entry.value;
    }
    return weights.keys.last;
  }

  // Returns the allocated Artifact.
  Artifact openCrate({required CrateTier tier}) {
    final random = Random();
    final electedRarity = _rollRarity(random, crateDef(tier).weights);

    // Draw from that rarity's pool only; fall back down the ladder if a rarity
    // has no items defined yet.
    List<Artifact> candidates =
        allArtifacts.where((a) => a.rarity == electedRarity).toList();
    for (int r = electedRarity.index - 1; candidates.isEmpty && r >= 0; r--) {
      candidates =
          allArtifacts.where((a) => a.rarity.index == r).toList();
    }
    if (candidates.isEmpty) candidates = allArtifacts.toList();

    final picked = candidates[random.nextInt(candidates.length)];
    addArtifact(picked.id);
    return picked;
  }
  
  void addArtifact(String id) {
    if (_ownedArtifacts.containsKey(id)) {
      _ownedArtifacts[id] = _ownedArtifacts[id]! + 1;
    } else {
      _ownedArtifacts[id] = 1;
    }
  }
}
