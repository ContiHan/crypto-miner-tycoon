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
  ];

  void reset() {
    for (var node in researchNodes) {
      node.isCompleted = false;
      node.isUnlocked = node.requirements.isEmpty;
    }
  }

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
