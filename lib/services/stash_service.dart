import 'dart:math';

enum ArtifactRarity { common, rare, legendary, unique }

enum BonusType {
  hashRate,   // Global Hash Rate Multiplier
  rigCost,    // Discount on Rigs
  clickPower, // Click Power Multiplier
  vcInterval, // Faster VC Funding (if implemented)
  criticalChance, // Crit Mining Chance
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

class StashService {
  // === DATABASE OF ARTIFACTS ===
  static const List<Artifact> allArtifacts = [
    // COMMON (10 items)
    Artifact(id: 'old_hdd', name: 'Old HDD', description: '+2% Hash Rate', rarity: ArtifactRarity.common, bonusType: BonusType.hashRate, baseBonus: 0.02),
    Artifact(id: 'usb_fan', name: 'USB Fan', description: '-1% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.01),
    Artifact(id: 'energy_drink', name: 'Energy Drink', description: '+5% Click Power', rarity: ArtifactRarity.common, bonusType: BonusType.clickPower, baseBonus: 0.05),
    Artifact(id: 'lucky_coin', name: 'Lucky Coin', description: '+1% Crit Chance', rarity: ArtifactRarity.common, bonusType: BonusType.criticalChance, baseBonus: 0.01),
    Artifact(id: 'cable_tie', name: 'Cable Tie', description: '-1% Rig Cost', rarity: ArtifactRarity.common, bonusType: BonusType.rigCost, baseBonus: 0.01),
    
    // RARE (5 items)
    Artifact(id: 'liquid_cooling', name: 'Liquid Cooling Loop', description: '+10% Hash Rate', rarity: ArtifactRarity.rare, bonusType: BonusType.hashRate, baseBonus: 0.10),
    Artifact(id: 'gold_thermal_paste', name: 'Gold Thermal Paste', description: '-5% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.05),
    Artifact(id: 'mechanical_switch', name: 'Mech Switch', description: '+20% Click Power', rarity: ArtifactRarity.rare, bonusType: BonusType.clickPower, baseBonus: 0.20),
    Artifact(id: 'server_rack', name: 'Pro Server Rack', description: '-5% Rig Cost', rarity: ArtifactRarity.rare, bonusType: BonusType.rigCost, baseBonus: 0.05),

    // LEGENDARY (3 items)
    Artifact(id: 'quantum_chip', name: 'Quantum Chip Prototype', description: '+50% Hash Rate', rarity: ArtifactRarity.legendary, bonusType: BonusType.hashRate, baseBonus: 0.50),
    Artifact(id: 'ai_optimiser', name: 'AI Cost Optimiser', description: '-15% Rig Cost', rarity: ArtifactRarity.legendary, bonusType: BonusType.rigCost, baseBonus: 0.15),
    Artifact(id: 'satoshi_whitepaper', name: 'The Whitepaper', description: '+100% Click Power', rarity: ArtifactRarity.legendary, bonusType: BonusType.clickPower, baseBonus: 1.0),
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

  double getClickPowerMultiplier() {
    double total = 0.0;
    _ownedArtifacts.forEach((id, count) {
      final artifact = _getArtifact(id);
      if (artifact != null && artifact.bonusType == BonusType.clickPower) {
        total += artifact.baseBonus * count;
      }
    });
    return 1.0 + total;
  }
  
  // === LOOT LOGIC ===
  
  Artifact? _getArtifact(String id) {
    try {
      return allArtifacts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  // Returns the allocated Artifact
  Artifact openCrate({required bool isPremium}) {
    final random = Random();
    double roll = random.nextDouble(); // 0.0 to 1.0
    
    ArtifactRarity electedRarity;
    
    if (isPremium) {
       // PREMIUM: Rare guaranteed, better leg chance
       // 0.0 - 0.80 = Rare (80%)
       // 0.80 - 0.98 = Legendary (18%)
       // 0.98 - 1.00 = Unique (2%) - Placeholder if added
       if (roll < 0.80) {
         electedRarity = ArtifactRarity.rare;
       } else {
         electedRarity = ArtifactRarity.legendary;
       }
    } else {
       // STANDARD: 
       // 0.0 - 0.70 = Common
       // 0.70 - 0.95 = Rare
       // 0.95 - 1.00 = Legendary
       if (roll < 0.70) {
         electedRarity = ArtifactRarity.common;
       } else if (roll < 0.95) {
         electedRarity = ArtifactRarity.rare;
       } else {
         electedRarity = ArtifactRarity.legendary;
       }
    }
    
    // Filter list by rarity
    List<Artifact> candidates = allArtifacts.where((a) => a.rarity == electedRarity).toList();
    
    // Fallback logic
    if (candidates.isEmpty) {
      candidates = allArtifacts.where((a) => a.rarity == ArtifactRarity.common).toList();
    }
    
    // Pick random item from candidates
    Artifact picked = candidates[random.nextInt(candidates.length)];
    
    // Add to stash
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
