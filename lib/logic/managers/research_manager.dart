import 'package:flutter/material.dart';
import '../../models/research_node.dart';
import '../../core/constants.dart';
import '../../core/ids.dart';
import '../channels.dart';

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
  ];

  void reset() {
    for (var node in researchNodes) {
      node.isCompleted = false;
      node.isUnlocked = node.requirements.isEmpty;
    }
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

    double costSats = getCostInSats(node, bitcoinExchangeRate);

    if (currentWallet >= costSats) {
      node.isCompleted = true;
      _checkUnlocks();
      return costSats;
    }
    return 0;
  }

  double getCostInSats(ResearchNode node, double bitcoinExchangeRate) {
    if (bitcoinExchangeRate <= 0) return node.cost; // Fallback
    return node.cost / bitcoinExchangeRate;
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
