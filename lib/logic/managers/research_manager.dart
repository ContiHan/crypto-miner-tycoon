import 'package:flutter/material.dart';
import '../../models/research_node.dart';
import '../../core/constants.dart';
import '../../core/ids.dart';

class ResearchManager {
  List<ResearchNode> researchNodes = [
    ResearchNode(
      id: ResearchIds.basicOverclock,
      name: 'Basic Overclocking',
      description: '+5% Global Hash Rate',
      cost: 500,
      icon: Icons.speed,
      isUnlocked: true,
    ),
    ResearchNode(
      id: ResearchIds.betterCooling,
      name: 'Better Cooling',
      description: 'Rigs are 10% cheaper',
      cost: 2500,
      icon: Icons.ac_unit,
      requirements: [ResearchIds.basicOverclock],
    ),
    ResearchNode(
      id: ResearchIds.solarPower,
      name: 'Solar Power',
      description: 'Energy Efficiency: Rigs are 15% cheaper',
      cost: 10000,
      icon: Icons.sunny,
      requirements: [ResearchIds.betterCooling],
    ),
    ResearchNode(
      id: ResearchIds.chipFab,
      name: 'Chip Fabrication',
      description: '+20% CPU & GPU Hash Rate',
      cost: 50000,
      icon: Icons.memory,
      requirements: [ResearchIds.basicOverclock],
    ),
    ResearchNode(
      id: ResearchIds.aiManager,
      name: 'AI Management',
      description: 'Auto-clicks every 5 seconds',
      cost: 1000000,
      icon: Icons.psychology,
      requirements: [ResearchIds.chipFab],
    ),
  ];

  void reset() {
    for (var node in researchNodes) {
      node.isCompleted = false;
      node.isUnlocked = node.requirements.isEmpty;
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

  double getResearchHashMultiplier() {
    double mult = 1.0;
    if (isResearched(ResearchIds.basicOverclock)) {
      mult += GameConstants.researchHashBonus;
    }
    return mult;
  }
}
