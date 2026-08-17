import 'package:flutter/material.dart';
import '../../models/research_node.dart';
import '../../core/constants.dart';
import '../../core/ids.dart';
import '../channels.dart';

/// A saved TECH build: a name + the set of completed node ids. Applied by the
/// preset auto-buy to re-tech a build after a reset. Survives prestige resets.
class TechPreset {
  String name;
  final Set<String> nodeIds;
  TechPreset({required this.name, required this.nodeIds});

  Map<String, dynamic> toJson() => {'name': name, 'nodeIds': nodeIds.toList()};

  static TechPreset? fromJson(dynamic j) {
    if (j is! Map) return null;
    final name = j['name'];
    final ids = j['nodeIds'];
    if (name is! String || ids is! List) return null;
    return TechPreset(
      name: name,
      nodeIds: ids.whereType<String>().toSet(),
    );
  }
}

/// TECH doctrines. TRUNK (the shared cheap on-ramp) + META (never-lockable
/// utility) are always available. The other six form three OPPOSED PAIRS
/// (megaHash⟂leanRig, hodler⟂degenYield, degenLuck⟂coldStorage): committing one
/// (buying any of its nodes) LOCKS its sibling for the run, and you may commit at
/// most [ResearchManager.commitmentBudget] pairs. Keystones live at each
/// doctrine's capstone.
enum Doctrine {
  trunk,
  meta,
  megaHash,
  leanRig,
  hodler,
  degenYield,
  degenLuck,
  coldStorage,
}

/// The sibling doctrine within a pair (null for trunk/meta, which never lock).
Doctrine? doctrineSibling(Doctrine d) {
  switch (d) {
    case Doctrine.megaHash:
      return Doctrine.leanRig;
    case Doctrine.leanRig:
      return Doctrine.megaHash;
    case Doctrine.hodler:
      return Doctrine.degenYield;
    case Doctrine.degenYield:
      return Doctrine.hodler;
    case Doctrine.degenLuck:
      return Doctrine.coldStorage;
    case Doctrine.coldStorage:
      return Doctrine.degenLuck;
    case Doctrine.trunk:
    case Doctrine.meta:
      return null;
  }
}

class ResearchManager {
  // Data-driven LAB catalog. Most nodes declare an (effectChannel, effectValue)
  // applied generically via contributeChannels — adding a channel-effect node is
  // a one-line data edit. A null effectChannel marks a SPECIAL node (Chip Fab
  // per-rig-type bonus, AI auto-clicker) handled explicitly elsewhere.
  List<ResearchNode> researchNodes = [
    ResearchNode(
      id: ResearchIds.basicOverclock,
      name: 'Basic Overclocking',
      description: '+5% Global Hash Rate',
      cost: 500,
      icon: Icons.speed,
      isUnlocked: true,
      effectChannel: Channel.hash,
      effectValue: GameConstants.researchHashBonus, // 0.05
    ),
    ResearchNode(
      id: ResearchIds.betterCooling,
      name: 'Better Cooling',
      description: 'Rigs are 10% cheaper',
      cost: 2500,
      icon: Icons.ac_unit,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.rigCost,
      effectValue: GameConstants.coolingDiscount, // 0.10
    ),
    ResearchNode(
      id: ResearchIds.solarPower,
      name: 'Solar Power',
      description: 'Energy Efficiency: Rigs are 15% cheaper',
      cost: 10000,
      icon: Icons.sunny,
      requirements: [ResearchIds.betterCooling],
      effectChannel: Channel.rigCost,
      effectValue: GameConstants.solarDiscount, // 0.15
    ),
    ResearchNode(
      id: ResearchIds.chipFab,
      name: 'Chip Fabrication',
      description: '+20% CPU & GPU Hash Rate',
      cost: 50000,
      icon: Icons.memory,
      requirements: [ResearchIds.basicOverclock],
      // SPECIAL: per-rig-type bonus, not a global channel.
    ),
    ResearchNode(
      id: ResearchIds.aiManager,
      name: 'AI Management',
      description: 'Auto-clicks every 5 seconds',
      cost: 1000000,
      icon: Icons.psychology,
      requirements: [ResearchIds.chipFab],
      // SPECIAL: mechanic, no channel bonus.
    ),
    // --- New data-driven nodes (channel effects; no new code needed) ---
    ResearchNode(
      id: ResearchIds.advancedOverclock,
      name: 'Advanced Overclocking',
      description: '+15% Global Hash Rate',
      cost: 250000,
      icon: Icons.electric_bolt,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.15,
    ),
    ResearchNode(
      id: ResearchIds.bulkProcurement,
      name: 'Bulk Procurement',
      description: 'Rigs are 10% cheaper',
      cost: 500000,
      icon: Icons.local_shipping,
      requirements: [ResearchIds.solarPower],
      effectChannel: Channel.rigCost,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.neuralNet,
      name: 'Neural Net Miner',
      description: '+25% Global Hash Rate',
      cost: 5000000,
      icon: Icons.hub,
      requirements: [ResearchIds.advancedOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.25,
    ),

    // --- Volume expansion: HASH branch (deeper overclocking) ---
    ResearchNode(
      id: ResearchIds.distributedComputing,
      name: 'Distributed Computing',
      description: '+30% Global Hash Rate',
      cost: 750000,
      icon: Icons.dns,
      requirements: [ResearchIds.advancedOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.30,
    ),
    ResearchNode(
      id: ResearchIds.quantumEntanglement,
      name: 'Quantum Entanglement',
      description: '+50% Global Hash Rate',
      cost: 20000000,
      icon: Icons.blur_on,
      requirements: [ResearchIds.chipFab],
      effectChannel: Channel.hash,
      effectValue: 0.50,
    ),
    ResearchNode(
      id: ResearchIds.quantumOverclock,
      name: 'Quantum Overclocking',
      description: '+40% Global Hash Rate',
      cost: 15000000,
      icon: Icons.scatter_plot,
      requirements: [ResearchIds.neuralNet],
      effectChannel: Channel.hash,
      effectValue: 0.40,
    ),
    ResearchNode(
      id: ResearchIds.fusionOverclock,
      name: 'Fusion Overclocking',
      description: '+60% Global Hash Rate',
      cost: 75000000,
      icon: Icons.local_fire_department,
      requirements: [ResearchIds.quantumOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.60,
    ),

    // --- Volume expansion: RIG-COST branch (efficiency) ---
    ResearchNode(
      id: ResearchIds.geothermalCooling,
      name: 'Geothermal Cooling',
      description: 'Rigs are 12% cheaper',
      cost: 2000000,
      icon: Icons.thermostat,
      requirements: [ResearchIds.bulkProcurement],
      effectChannel: Channel.rigCost,
      effectValue: 0.12,
    ),
    ResearchNode(
      id: ResearchIds.nanofabrication,
      name: 'Nanofabrication',
      description: 'Rigs are 15% cheaper',
      cost: 20000000,
      icon: Icons.precision_manufacturing,
      requirements: [ResearchIds.geothermalCooling],
      effectChannel: Channel.rigCost,
      effectValue: 0.15,
    ),

    // --- Volume expansion: INCOME branch (yield engineering) ---
    ResearchNode(
      id: ResearchIds.marketAnalytics,
      name: 'Market Analytics',
      description: '+10% Mining Income',
      cost: 5000,
      icon: Icons.analytics,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.income,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.highFrequencyTrading,
      name: 'High-Frequency Trading',
      description: '+20% Mining Income',
      cost: 100000,
      icon: Icons.candlestick_chart,
      requirements: [ResearchIds.marketAnalytics],
      effectChannel: Channel.income,
      effectValue: 0.20,
    ),
    ResearchNode(
      id: ResearchIds.coldStorage,
      name: 'Cold Storage Vault',
      description: '+15% Mining Income',
      cost: 300000,
      icon: Icons.savings,
      requirements: [ResearchIds.solarPower],
      effectChannel: Channel.income,
      effectValue: 0.15,
    ),
    ResearchNode(
      id: ResearchIds.defiYield,
      name: 'DeFi Yield Farming',
      description: '+30% Mining Income',
      cost: 2000000,
      icon: Icons.account_balance,
      requirements: [ResearchIds.highFrequencyTrading],
      effectChannel: Channel.income,
      effectValue: 0.30,
    ),
    ResearchNode(
      id: ResearchIds.taxHaven,
      name: 'Offshore Tax Haven',
      description: '+25% Mining Income',
      cost: 10000000,
      icon: Icons.beach_access,
      requirements: [ResearchIds.defiYield],
      effectChannel: Channel.income,
      effectValue: 0.25,
    ),
    ResearchNode(
      id: ResearchIds.liquidityMining,
      name: 'Liquidity Mining',
      description: '+40% Mining Income',
      cost: 40000000,
      icon: Icons.water_drop,
      requirements: [ResearchIds.defiYield],
      effectChannel: Channel.income,
      effectValue: 0.40,
    ),

    // --- Volume expansion: CLICK branch (manual power) ---
    ResearchNode(
      id: ResearchIds.ergonomicRig,
      name: 'Ergonomic Rig',
      description: '+25% Click Power',
      cost: 20000,
      icon: Icons.mouse,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.click,
      effectValue: 0.25,
    ),
    ResearchNode(
      id: ResearchIds.macroScripts,
      name: 'Macro Scripts',
      description: '+50% Click Power',
      cost: 400000,
      icon: Icons.code,
      requirements: [ResearchIds.ergonomicRig],
      effectChannel: Channel.click,
      effectValue: 0.50,
    ),

    // --- Volume expansion 2: deep tech tree ---
    ResearchNode(
      id: ResearchIds.plasmaOverclock,
      name: 'Plasma Overclocking',
      description: '+70% Global Hash Rate',
      cost: 200000000,
      icon: Icons.flare,
      requirements: [ResearchIds.fusionOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.70,
    ),
    ResearchNode(
      id: ResearchIds.antimatterCores,
      name: 'Antimatter Cores',
      description: '+80% Global Hash Rate',
      cost: 1000000000,
      icon: Icons.bubble_chart,
      requirements: [ResearchIds.plasmaOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.80,
    ),
    ResearchNode(
      id: ResearchIds.zeroPointHash,
      name: 'Zero-Point Hashing',
      description: '+100% Global Hash Rate',
      cost: 5000000000,
      icon: Icons.all_inclusive,
      requirements: [ResearchIds.antimatterCores],
      effectChannel: Channel.hash,
      effectValue: 1.0,
    ),
    ResearchNode(
      id: ResearchIds.orbitalLogistics,
      name: 'Orbital Logistics',
      description: 'Rigs are 10% cheaper',
      cost: 100000000,
      icon: Icons.satellite_alt,
      requirements: [ResearchIds.nanofabrication],
      effectChannel: Channel.rigCost,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.selfReplicatingRigs,
      name: 'Self-Replicating Rigs',
      description: 'Rigs are 10% cheaper',
      cost: 2000000000,
      icon: Icons.copy_all,
      requirements: [ResearchIds.orbitalLogistics],
      effectChannel: Channel.rigCost,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.algorithmicTrading,
      name: 'Algorithmic Trading',
      description: '+30% Mining Income',
      cost: 100000000,
      icon: Icons.query_stats,
      requirements: [ResearchIds.liquidityMining],
      effectChannel: Channel.income,
      effectValue: 0.30,
    ),
    ResearchNode(
      id: ResearchIds.hedgeFund,
      name: 'Hedge Fund',
      description: '+40% Mining Income',
      cost: 1000000000,
      icon: Icons.account_balance_wallet,
      requirements: [ResearchIds.algorithmicTrading],
      effectChannel: Channel.income,
      effectValue: 0.40,
    ),
    ResearchNode(
      id: ResearchIds.centralBank,
      name: 'Own The Central Bank',
      description: '+50% Mining Income',
      cost: 10000000000,
      icon: Icons.account_balance,
      requirements: [ResearchIds.hedgeFund],
      effectChannel: Channel.income,
      effectValue: 0.50,
    ),
    ResearchNode(
      id: ResearchIds.neuralInterface,
      name: 'Neural Interface',
      description: '+75% Click Power',
      cost: 2000000,
      icon: Icons.psychology_alt,
      requirements: [ResearchIds.macroScripts],
      effectChannel: Channel.click,
      effectValue: 0.75,
    ),
    ResearchNode(
      id: ResearchIds.quantumReflexes,
      name: 'Quantum Reflexes',
      description: '+100% Click Power',
      cost: 50000000,
      icon: Icons.touch_app,
      requirements: [ResearchIds.neuralInterface],
      effectChannel: Channel.click,
      effectValue: 1.0,
    ),

    // --- OFFLINE YIELD branch (Autonomous Daemons) ---
    // Raise the fraction of live income earned while the app is closed (base 70%).
    ResearchNode(
      id: ResearchIds.autonomousDaemons,
      name: 'Autonomous Daemons',
      description: '+15% Offline Earnings',
      cost: 1000000,
      icon: Icons.smart_toy,
      requirements: [ResearchIds.coldStorage],
      effectChannel: Channel.offline,
      effectValue: 0.15,
    ),
    ResearchNode(
      id: ResearchIds.miningDaemonSwarm,
      name: 'Mining Daemon Swarm',
      description: '+15% Offline Earnings',
      cost: 25000000,
      icon: Icons.hive,
      requirements: [ResearchIds.autonomousDaemons],
      effectChannel: Channel.offline,
      effectValue: 0.15,
    ),

    // --- BLOCK REWARD branch (crit payout, Channel.special) ---
    // Raises how much a critical tap pays (base 5x), concave + hard-capped.
    ResearchNode(
      id: ResearchIds.precisionHashing,
      name: 'Precision Hashing',
      description: '+50% Block Reward',
      cost: 2000000,
      icon: Icons.center_focus_strong,
      requirements: [ResearchIds.ergonomicRig],
      effectChannel: Channel.special,
      effectValue: 0.50,
    ),

    // --- CONSENSUS WEIGHT branch (prestige gain, Channel.prestige) ---
    // Multiplies Consensus + GovToken GAIN (softcapped, feedback-safe).
    ResearchNode(
      id: ResearchIds.consensusProtocol,
      name: 'Consensus Protocol',
      description: '+25% Prestige Gain',
      cost: 5000000,
      icon: Icons.how_to_vote,
      requirements: [ResearchIds.highFrequencyTrading],
      effectChannel: Channel.prestige,
      effectValue: 0.25,
    ),
    ResearchNode(
      id: ResearchIds.governanceCartel,
      name: 'Governance Cartel',
      description: '+50% Prestige Gain',
      cost: 200000000,
      icon: Icons.gavel,
      requirements: [ResearchIds.consensusProtocol],
      effectChannel: Channel.prestige,
      effectValue: 0.50,
    ),

    // --- PROSPECTOR'S EYE branch (crate drop-quality, Channel.fortune) ---
    // Chance to bump each crate roll up one rarity (hard-capped combined at 25%).
    ResearchNode(
      id: ResearchIds.assayLab,
      name: 'Assay Lab',
      description: '+10% Drop Quality',
      cost: 8000000,
      icon: Icons.biotech,
      requirements: [ResearchIds.chipFab],
      effectChannel: Channel.fortune,
      effectValue: 0.10,
    ),

    // --- LUCK-FACET branches (crit / SWEEP / anomaly luck; Phase 1 decouple) ---
    ResearchNode(
      id: ResearchIds.noncePrediction,
      name: 'Nonce Prediction',
      description: '+10% Crit Chance Luck',
      cost: 3000000,
      icon: Icons.casino,
      requirements: [ResearchIds.ergonomicRig],
      effectChannel: Channel.nonce,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.mempoolSniffer,
      name: 'Mempool Sniffer',
      description: '+10% SWEEP Luck',
      cost: 3000000,
      icon: Icons.travel_explore,
      requirements: [ResearchIds.marketAnalytics],
      effectChannel: Channel.sweepLuck,
      effectValue: 0.10,
    ),
    ResearchNode(
      id: ResearchIds.utxoMagnet,
      name: 'UTXO Magnet',
      description: '+10% Anomaly Luck',
      cost: 3000000,
      icon: Icons.explore,
      requirements: [ResearchIds.chipFab],
      effectChannel: Channel.magnetism,
      effectValue: 0.10,
    ),

    // --- IDLE CAPACITY branch (offline window, base 8h → cap 24h) ---
    ResearchNode(
      id: ResearchIds.batteryBank,
      name: 'Battery Bank',
      description: '+8h Idle Capacity',
      cost: 4000000,
      icon: Icons.battery_charging_full,
      requirements: [ResearchIds.solarPower],
      effectChannel: Channel.idle,
      effectValue: 8.0, // hours
    ),
    ResearchNode(
      id: ResearchIds.gridStorage,
      name: 'Grid Storage',
      description: '+8h Idle Capacity',
      cost: 60000000,
      icon: Icons.ev_station,
      requirements: [ResearchIds.batteryBank],
      effectChannel: Channel.idle,
      effectValue: 8.0, // hours (base 8 + 8 + 8 -> 24h cap)
    ),

    // --- RESISTANCE branch (Phase 2 — softens negative chaos, never immune) ---
    ResearchNode(
      id: ResearchIds.diamondHands,
      name: 'Diamond Hands',
      description: '+25% Crash Resistance',
      cost: 6000000,
      icon: Icons.diamond,
      requirements: [ResearchIds.coldStorage],
      effectChannel: Channel.crashResist,
      effectValue: 0.25,
    ),
    ResearchNode(
      id: ResearchIds.feeHedge,
      name: 'Fee Hedge',
      description: '+25% Cost-Spike Resistance',
      cost: 6000000,
      icon: Icons.shield,
      requirements: [ResearchIds.bulkProcurement],
      effectChannel: Channel.costResist,
      effectValue: 0.25,
    ),
    ResearchNode(
      id: ResearchIds.stockToFlow,
      name: 'Stock-to-Flow',
      description: '+30% Halving Resistance',
      cost: 40000000,
      icon: Icons.stacked_line_chart,
      requirements: [ResearchIds.diamondHands],
      effectChannel: Channel.halvingResist,
      effectValue: 0.30,
    ),
    ResearchNode(
      id: ResearchIds.steelNerves,
      name: 'Steel Nerves',
      description: '+30% Event Duration Cut',
      cost: 20000000,
      icon: Icons.self_improvement,
      requirements: [ResearchIds.diamondHands],
      effectChannel: Channel.durationResist,
      effectValue: 0.30,
    ),
    // COLD STORAGE — reduces THE BREACH's hot-wallet theft (Channel.theftResist).
    ResearchNode(
      id: ResearchIds.coldStorageVault,
      name: 'Cold Storage Vault',
      description: '+40% Breach Resistance',
      cost: 30000000,
      icon: Icons.lock,
      requirements: [ResearchIds.feeHedge],
      effectChannel: Channel.theftResist,
      effectValue: 0.40,
    ),
    // --- Ability enhancers (Slice 72b) — TRUNK, so any build can reach them ---
    // RIG COOLING: shortens ability cooldowns (Channel.haste, cap 0.40).
    ResearchNode(
      id: ResearchIds.immersionCooling,
      name: 'Immersion Cooling',
      description: 'RIG COOLING: ability cooldowns −20%',
      cost: 5000000,
      icon: Icons.ac_unit,
      requirements: [ResearchIds.betterCooling],
      effectChannel: Channel.haste,
      effectValue: 0.20,
    ),
    // OVERCHARGE: amplifies active ability BUFF magnitude + grant-seconds (cap 0.50).
    ResearchNode(
      id: ResearchIds.powerCapacitors,
      name: 'Power Capacitors',
      description: 'OVERCHARGE: ability buffs +25% stronger',
      cost: 8000000,
      icon: Icons.battery_charging_full,
      requirements: [ResearchIds.solarPower],
      effectChannel: Channel.overcharge,
      effectValue: 0.25,
    ),
    // BULL BIAS: tilts chaos events toward positives (never zeroes negatives).
    ResearchNode(
      id: ResearchIds.sentimentAnalysis,
      name: 'Sentiment Analysis',
      description: 'BULL BIAS: positive market events roll more often',
      cost: 12000000,
      icon: Icons.insights,
      requirements: [ResearchIds.marketAnalytics],
      effectChannel: Channel.bullBias,
      effectValue: 1.0,
    ),
    // META: FIRMWARE BAY — a special node (no channel) that grants +1 Rig Firmware
    // socket while researched (see GameLogic.firmwareCapacity).
    ResearchNode(
      id: ResearchIds.firmwareBay,
      name: 'Firmware Bay',
      description: '+1 Rig Firmware socket',
      cost: 15000000,
      icon: Icons.developer_board,
      requirements: [ResearchIds.aiManager],
      // SPECIAL: grants a firmware slot, not a channel bonus.
    ),
  ];

  /// BLUEPRINTS: permanent per-node completion count. Survives every prestige
  /// reset (only a full Wipe Save clears it) and drives the re-tech discount.
  final Map<String, int> researchCount = {};

  /// Blueprint re-tech discount for a node id (0..blueprintMaxDiscount), concave
  /// in how many times it has been researched across all past runs.
  double blueprintDiscount(String id) {
    final n = researchCount[id] ?? 0;
    if (n <= 0) return 0.0;
    return GameConstants.blueprintMaxDiscount *
        (1 - 1 / (1 + n / GameConstants.blueprintDivisor));
  }

  /// Serialise blueprint counts for the save blob.
  Map<String, int> researchCountJson() => Map<String, int>.from(researchCount);

  /// Restore blueprint counts (tolerant of nulls / non-int values).
  void loadResearchCounts(dynamic data) {
    researchCount.clear();
    if (data is Map) {
      data.forEach((k, v) {
        if (k is String && v is num) researchCount[k] = v.toInt();
      });
    }
  }

  /// Full Wipe Save only: clears the permanent blueprint dividend.
  void wipeBlueprints() => researchCount.clear();

  // ---- Presets (Phase 3 QoL) ---------------------------------------------
  // A saved TECH build the player can one-tap re-apply after a reset. Presets
  // survive prestige resets (only a full Wipe clears them). Capped at 3 slots.

  final List<TechPreset> presets = [];
  int activePreset = -1; // index into [presets]; -1 = none
  bool autoApplyPresets = true; // owner: default ON, opt-out

  static const int maxPresets = 3;

  /// Themed auto-name from the dominant effect-channel of a completed set.
  String autoNameFor(Set<String> nodeIds) {
    final counts = <Channel, int>{};
    for (final id in nodeIds) {
      final node = researchNodes.firstWhere((n) => n.id == id,
          orElse: () => ResearchNode(id: ''));
      final ch = node.effectChannel;
      if (ch != null) counts[ch] = (counts[ch] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Custom Build';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case Channel.hash:
        return 'Hash Whale';
      case Channel.income:
        return 'Yield Farmer';
      case Channel.rigCost:
        return 'Lean Machine';
      case Channel.click:
        return 'Click Tapper';
      case Channel.prestige:
        return 'Prestige Farmer';
      case Channel.offline:
        return 'HODLer';
      case Channel.special:
        return 'Crit Tapper';
      case Channel.fortune:
        return 'Fortune Hunter';
      case Channel.nonce:
        return 'Sharp Shooter';
      case Channel.sweepLuck:
        return 'High Roller';
      case Channel.magnetism:
        return 'Anomaly Hunter';
      case Channel.idle:
        return 'Deep Sleeper';
      case Channel.crashResist:
      case Channel.costResist:
      case Channel.halvingResist:
      case Channel.durationResist:
      case Channel.theftResist:
        return 'Fortress';
      case Channel.haste:
      case Channel.overcharge:
        return 'Overclocker';
      case Channel.bullBias:
        return 'Bull Rider';
      case Channel.luck:
      case Channel.volatility:
        return 'Wildcard';
    }
  }

  /// Snapshot the currently-completed nodes into a new preset (auto-named),
  /// making it the active one. Capped at [maxPresets] (drops the oldest).
  /// No-op if nothing is completed. Returns the saved preset (or null).
  TechPreset? savePreset() {
    final ids = researchNodes
        .where((n) => n.isCompleted)
        .map((n) => n.id)
        .toSet();
    if (ids.isEmpty) return null;
    final preset = TechPreset(name: autoNameFor(ids), nodeIds: ids);
    presets.add(preset);
    while (presets.length > maxPresets) {
      presets.removeAt(0);
    }
    activePreset = presets.length - 1;
    return preset;
  }

  void renamePreset(int index, String name) {
    if (index >= 0 && index < presets.length && name.trim().isNotEmpty) {
      presets[index].name = name.trim();
    }
  }

  List<Map<String, dynamic>> presetsJson() =>
      presets.map((p) => p.toJson()).toList();

  void loadPresets(dynamic data, dynamic active, dynamic auto) {
    presets.clear();
    if (data is List) {
      for (final e in data) {
        final p = TechPreset.fromJson(e);
        if (p != null) presets.add(p);
      }
    }
    activePreset = (active is num) ? active.toInt() : -1;
    if (activePreset >= presets.length) activePreset = presets.length - 1;
    autoApplyPresets = auto is bool ? auto : true;
  }

  void wipePresets() {
    presets.clear();
    activePreset = -1;
    autoApplyPresets = true;
  }

  void reset() {
    for (var node in researchNodes) {
      node.isCompleted = false;
      node.isUnlocked = node.requirements.isEmpty;
    }
    // NOTE: researchCount (blueprints) is intentionally NOT cleared here — it is
    // permanent across prestige resets.
  }

  // ---- Doctrines / exclusivity (Phase 3) ---------------------------------
  // Owner: commitment budget = 2 pairs. Membership is a single central map so
  // the requirement graph stays self-consistent: every doctrine node's prereqs
  // are TRUNK (shared hubs) or same-doctrine, so committing a doctrine never
  // strands a reachable node.
  static const int commitmentBudget = 2;

  static const Map<String, Doctrine> _doctrineOf = {
    // META (never lockable)
    ResearchIds.aiManager: Doctrine.meta,
    ResearchIds.firmwareBay: Doctrine.meta,
    // MEGA-HASH
    ResearchIds.advancedOverclock: Doctrine.megaHash,
    ResearchIds.neuralNet: Doctrine.megaHash,
    ResearchIds.distributedComputing: Doctrine.megaHash,
    ResearchIds.quantumEntanglement: Doctrine.megaHash,
    ResearchIds.quantumOverclock: Doctrine.megaHash,
    ResearchIds.fusionOverclock: Doctrine.megaHash,
    ResearchIds.plasmaOverclock: Doctrine.megaHash,
    ResearchIds.antimatterCores: Doctrine.megaHash,
    ResearchIds.zeroPointHash: Doctrine.megaHash,
    // LEAN-RIG
    ResearchIds.geothermalCooling: Doctrine.leanRig,
    ResearchIds.nanofabrication: Doctrine.leanRig,
    ResearchIds.orbitalLogistics: Doctrine.leanRig,
    ResearchIds.selfReplicatingRigs: Doctrine.leanRig,
    ResearchIds.macroScripts: Doctrine.leanRig,
    ResearchIds.neuralInterface: Doctrine.leanRig,
    ResearchIds.quantumReflexes: Doctrine.leanRig,
    // DEGEN-YIELD
    ResearchIds.defiYield: Doctrine.degenYield,
    ResearchIds.taxHaven: Doctrine.degenYield,
    ResearchIds.liquidityMining: Doctrine.degenYield,
    ResearchIds.algorithmicTrading: Doctrine.degenYield,
    ResearchIds.hedgeFund: Doctrine.degenYield,
    ResearchIds.centralBank: Doctrine.degenYield,
    // HODLER
    ResearchIds.autonomousDaemons: Doctrine.hodler,
    ResearchIds.miningDaemonSwarm: Doctrine.hodler,
    ResearchIds.consensusProtocol: Doctrine.hodler,
    ResearchIds.governanceCartel: Doctrine.hodler,
    // DEGEN-LUCK
    ResearchIds.precisionHashing: Doctrine.degenLuck,
    ResearchIds.noncePrediction: Doctrine.degenLuck,
    ResearchIds.mempoolSniffer: Doctrine.degenLuck,
    ResearchIds.utxoMagnet: Doctrine.degenLuck,
    ResearchIds.assayLab: Doctrine.degenLuck,
    // COLD-STORAGE
    ResearchIds.diamondHands: Doctrine.coldStorage,
    ResearchIds.stockToFlow: Doctrine.coldStorage,
    ResearchIds.steelNerves: Doctrine.coldStorage,
    ResearchIds.coldStorageVault: Doctrine.coldStorage,
    ResearchIds.batteryBank: Doctrine.coldStorage,
    ResearchIds.gridStorage: Doctrine.coldStorage,
    // everything else (basicOverclock, chipFab, betterCooling, solarPower,
    // marketAnalytics, ergonomicRig, coldStorage(income), bulkProcurement,
    // highFrequencyTrading) is TRUNK by default.
  };

  Doctrine doctrineOf(String id) => _doctrineOf[id] ?? Doctrine.trunk;

  /// Doctrines the run has committed to (any completed node), excluding trunk/meta.
  Set<Doctrine> committedDoctrines() {
    final s = <Doctrine>{};
    for (final n in researchNodes) {
      if (!n.isCompleted) continue;
      final d = doctrineOf(n.id);
      if (d != Doctrine.trunk && d != Doctrine.meta) s.add(d);
    }
    return s;
  }

  /// How many opposed PAIRS have a committed doctrine (0..3).
  int committedPairCount() {
    final c = committedDoctrines();
    var pairs = 0;
    if (c.contains(Doctrine.megaHash) || c.contains(Doctrine.leanRig)) pairs++;
    if (c.contains(Doctrine.hodler) || c.contains(Doctrine.degenYield)) pairs++;
    if (c.contains(Doctrine.degenLuck) || c.contains(Doctrine.coldStorage)) {
      pairs++;
    }
    return pairs;
  }

  /// A node is doctrine-locked when its sibling doctrine is committed, or when
  /// entering its (not-yet-committed) pair would exceed the commitment budget.
  /// trunk/meta are never locked.
  bool isDoctrineLocked(String id) {
    final d = doctrineOf(id);
    if (d == Doctrine.trunk || d == Doctrine.meta) return false;
    final committed = committedDoctrines();
    if (committed.contains(d)) return false; // already in this doctrine
    final sib = doctrineSibling(d);
    if (sib != null && committed.contains(sib)) return true; // chose the other side
    if (committedPairCount() >= commitmentBudget) return true; // budget spent
    return false;
  }

  /// Re-derives unlock state from completed nodes. Called after loading a save so
  /// that nodes ADDED after that save was written (whose prerequisites are
  /// already completed) become purchasable instead of being stuck as locked
  /// "???" frontier teasers — otherwise a content update soft-locks the LAB.
  void refreshUnlocks() => _checkUnlocks();

  /// Adds every completed node's declared channel effect to [ch].
  void contributeChannels(Channels ch) {
    for (final node in researchNodes) {
      if (node.isCompleted && node.effectChannel != null) {
        ch.add(node.effectChannel!, node.effectValue);
      }
    }
  }

  // Returns cost if success (so caller can deduct wallet), 0 if failed
  double tryBuy(
    String researchId,
    double currentWallet,
    double bitcoinExchangeRate,
  ) {
    int index = researchNodes.indexWhere((r) => r.id == researchId);
    if (index == -1) return 0;

    ResearchNode node = researchNodes[index];
    if (node.isCompleted) return 0;
    // Exclusive doctrines: can't buy into a locked sibling / a 3rd pair.
    if (isDoctrineLocked(researchId)) return 0;

    double costSats = getCostInSats(node, bitcoinExchangeRate);

    if (currentWallet >= costSats) {
      node.isCompleted = true;
      // BLUEPRINTS: record the completion permanently (drives the re-tech discount
      // on every future run).
      researchCount[researchId] = (researchCount[researchId] ?? 0) + 1;
      _checkUnlocks();
      return costSats;
    }
    return 0;
  }

  double getCostInSats(ResearchNode node, double bitcoinExchangeRate) {
    final double base =
        bitcoinExchangeRate <= 0 ? node.cost : node.cost / bitcoinExchangeRate;
    // Combined discount (blueprint now; a future R&D doctrine adds here), with the
    // #3 FLOOR so stacked discounts can never drive the price below techCostFloor.
    final double totalDiscount = blueprintDiscount(node.id);
    double factor = 1.0 - totalDiscount;
    if (factor < GameConstants.techCostFloor) factor = GameConstants.techCostFloor;
    return base * factor;
  }

  void _checkUnlocks() {
    for (var node in researchNodes) {
      if (!node.isUnlocked && !node.isCompleted) {
        bool allMet = node.requirements.every((reqId) {
          var reqNode = researchNodes.firstWhere(
            (r) => r.id == reqId,
            orElse: () => ResearchNode(
              id: '',
              name: '',
              description: '',
              cost: 0,
              icon: Icons.error,
            ),
          );
          return reqNode.isCompleted;
        });
        if (allMet) node.isUnlocked = true;
      }
    }
  }

  bool isResearched(String id) {
    var node = researchNodes.firstWhere(
      (r) => r.id == id,
      orElse: () => ResearchNode(
        id: '',
        name: '',
        description: '',
        cost: 0,
        icon: Icons.error,
      ),
    );
    return node.isCompleted;
  }
}
