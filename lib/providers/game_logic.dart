import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rig.dart';
import '../models/research_node.dart';

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;
  
  List<Rig> rigs = [
    Rig(id: 'cpu_rig', name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1.0),
    Rig(id: 'gpu_rig', name: 'GPU Rack', baseCost: 1500, baseHashRate: 20.0),
    Rig(id: 'asic_rig', name: 'ASIC Miner', baseCost: 12000, baseHashRate: 250.0),
    Rig(id: 'quantum', name: 'Quantum Computer', baseCost: 150000, baseHashRate: 5000.0),
  ];

  int govTokens = 0;
  
  // Perks: keys are 'click_power', 'rig_cost', 'hash_bonus'
  Map<String, int> perks = {
    'click_power': 0,
    'rig_cost': 0,
    'hash_bonus': 0,
  };

  // Perk Config
  final Map<String, int> perkCosts = {
    'click_power': 5,
    'rig_cost': 10,
    'hash_bonus': 15,
  };
  
  // RESEARCH SYSTEM
  List<ResearchNode> researchNodes = [
    ResearchNode(
      id: 'basic_overclock',
      name: 'Basic Overclocking',
      description: '+5% Global Hash Rate',
      cost: 500,
      icon: Icons.speed,
      isUnlocked: true,
    ),
    ResearchNode(
      id: 'better_cooling',
      name: 'Better Cooling',
      description: 'Rigs are 10% cheaper',
      cost: 2500,
      icon: Icons.ac_unit,
      requirements: ['basic_overclock'],
    ),
    ResearchNode(
      id: 'solar_power',
      name: 'Solar Power',
      description: 'Unlocks Energy Efficiency (Coming Soon)',
      cost: 10000,
      icon: Icons.sunny,
      requirements: ['better_cooling'],
    ),
     ResearchNode(
      id: 'chip_fab',
      name: 'Chip Fabrication',
      description: '+20% CPU & GPU Hash Rate',
      cost: 50000,
      icon: Icons.memory,
      requirements: ['basic_overclock'],
    ),
     ResearchNode(
      id: 'ai_manager',
      name: 'AI Management',
      description: 'Auto-clicks every 5 seconds',
      cost: 1000000,
      icon: Icons.psychology,
      requirements: ['chip_fab'],
    ),
  ];
  
  int _autoClickCounter = 0;

  void buyResearch(String researchId) {
    int index = researchNodes.indexWhere((r) => r.id == researchId);
    if (index == -1) return;

    ResearchNode node = researchNodes[index];
    if (node.isCompleted) return;
    
    if (wallet >= node.cost) {
      wallet -= node.cost;
      node.isCompleted = true;
      _checkUnlocks();
      notifyListeners();
      _saveGame();
    }
  }

  void _checkUnlocks() {
    for (var node in researchNodes) {
      if (!node.isUnlocked && !node.isCompleted) {
         bool allMet = node.requirements.every((reqId) {
            var reqNode = researchNodes.firstWhere((r) => r.id == reqId, orElse: () => ResearchNode(id: '', name: '', description: '', cost: 0, icon: Icons.error));
            return reqNode.isCompleted;
         });
         if (allMet) node.isUnlocked = true;
      }
    }
  }

  bool isResearched(String id) {
     return researchNodes.firstWhere((r) => r.id == id, orElse: () => ResearchNode(id: '', name: '', description: '', cost: 0, icon: Icons.error)).isCompleted;
  }
  
  double get _researchHashMultiplier {
    double mult = 1.0;
    if (isResearched('basic_overclock')) mult += 0.05;
    return mult;
  }
  
  // 10% bonus per token
  double get prestigeMultiplier => 1.0 + (govTokens * 0.10);

  Timer? _gameTimer;

  GameLogic() {
    loadGame().then((_) {
      _startGameLoop();
    });
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _mine();
    });
    
    // Auto-Save every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveGame();
      debugPrint('Auto-Saved Game');
    });
  }

  double get globalHashRate {
    double total = 0;
    
    // Calculate per-rig hashrate with research bonuses
    for (var rig in rigs) {
      double rigRate = rig.totalHashRate;
      
      // Chip Fab bonus for CPU/GPU
      if (isResearched('chip_fab') && (rig.id == 'cpu_rig' || rig.id == 'gpu_rig')) {
        rigRate *= 1.20; 
      }
      
      total += rigRate;
    }
    
    // Global multiplier
    total *= _researchHashMultiplier;
    
    // Apply 'hash_bonus' perk (10% per level)
    double perkMultiplier = 1.0 + (perks['hash_bonus']! * 0.10);
    return total * perkMultiplier;
  }

  void _mine() {
    double finalHashRate = globalHashRate;
    
    // AI Manager Auto-Click logic
    if (isResearched('ai_manager')) {
       _autoClickCounter++;
       if (_autoClickCounter >= 5) { 
         clickMine();
         _autoClickCounter = 0;
       }
    }

    if (finalHashRate > 0) {
      double income = finalHashRate * prestigeMultiplier;
      wallet += income;
      lifetimeEarnings += income;
      notifyListeners();
    }
  }
  
  // Calculate tokens available to claim based on run earnings
  int get pendingGovTokens {
    if (lifetimeEarnings < 10000) return 0;
    // Formula: Sqrt(Earnings / 10000) - adjusted for 10x economy scale
    return (sqrt(lifetimeEarnings / 10000).floor());
  }

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    govTokens += tokensToClaim;
    
    // Reset Progress
    wallet = 0;
    lifetimeEarnings = 0;
    // Note: We do NOT reset perks. They are permanent.
    for (var rig in rigs) {
      rig.amount = 0;
    }
     
    _saveGame();
    
    notifyListeners();
  }

  void clickMine() {
    // Base 5 + (2 * level) - Clicking should feel impactful
    double clickValue = (5.0 + (perks['click_power']! * 2)) * prestigeMultiplier;
    wallet += clickValue;
    lifetimeEarnings += clickValue;
    notifyListeners();
  }

  void buyRig(String rigId) {
    int index = rigs.indexWhere((r) => r.id == rigId);
    if (index != -1) {
      Rig rig = rigs[index];
      
      // Calculate discounted cost
      double discountFactor = 1.0 - (perks['rig_cost']! * 0.05);
      if (discountFactor < 0.1) discountFactor = 0.1; // Cap at 90% discount
      
      double finalCost = rig.currentCost * discountFactor;
      
      if (wallet >= finalCost) {
        wallet -= finalCost;
        rig.amount++;
        notifyListeners();
        _saveGame();
      }
    }
  }
  
  double getRigCost(Rig rig) {
    double discountFactor = 1.0 - (perks['rig_cost']! * 0.05);
    if (discountFactor < 0.1) discountFactor = 0.1; 
    
    double cost = rig.currentCost * discountFactor;
    
    // Research Discount
    if (isResearched('better_cooling')) {
      cost *= 0.90;
    }
    
    return cost;
  }

  void buyPerk(String perkId) {
    if (perks.containsKey(perkId) && perkCosts.containsKey(perkId)) {
      int cost = perkCosts[perkId]!;
      if (govTokens >= cost) {
        govTokens -= cost;
        perks[perkId] = perks[perkId]! + 1;
        
        // Increase cost by +5 tokens per level
        perkCosts[perkId] = perkCosts[perkId]! + 5;
        
        _saveGame();
        notifyListeners();
      }
    }
  }

  // PERSISTENCE
  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallet', wallet);
    await prefs.setDouble('lifetimeEarnings', lifetimeEarnings);
    await prefs.setInt('govTokens', govTokens);
    
    // Save Perks
    await prefs.setString('perks', jsonEncode(perks));
    await prefs.setString('perkCosts', jsonEncode(perkCosts));
    
    // Serialize Rigs
    final rigsJson = jsonEncode(rigs.map((r) => r.toJson()).toList());
    await prefs.setString('rigs', rigsJson);
    
    // Serialize Research
    final researchJson = jsonEncode(researchNodes.map((r) => r.toJson()).toList());
    await prefs.setString('research', researchJson);
    
    // Save Timestamp
    await prefs.setInt('last_save_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    wallet = prefs.getDouble('wallet') ?? 0;
    lifetimeEarnings = prefs.getDouble('lifetimeEarnings') ?? 0;
    govTokens = prefs.getInt('govTokens') ?? 0;
    
    // Load Perks
    if (prefs.containsKey('perks')) {
      Map<String, dynamic> loadedPerks = jsonDecode(prefs.getString('perks')!);
      perks.addAll(loadedPerks.map((k, v) => MapEntry(k, v as int)));
    }
    if (prefs.containsKey('perkCosts')) {
      Map<String, dynamic> loadedCosts = jsonDecode(prefs.getString('perkCosts')!);
      perkCosts.addAll(loadedCosts.map((k, v) => MapEntry(k, v as int)));
    }

    final rigsString = prefs.getString('rigs');
    if (rigsString != null) {
      final List<dynamic> decoded = jsonDecode(rigsString);
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final amount = jsonItem['amount'];
        
        // Update local rig list
        final index = rigs.indexWhere((r) => r.id == id);
        if (index != -1) {
          rigs[index].amount = amount;
        }
      }
    }
    
    // Load Research
    final researchString = prefs.getString('research');
    if (researchString != null) {
      final List<dynamic> decoded = jsonDecode(researchString);
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final isUnlocked = jsonItem['isUnlocked'];
        final isCompleted = jsonItem['isCompleted'];
        
        final index = researchNodes.indexWhere((r) => r.id == id);
        if (index != -1) {
          researchNodes[index].isUnlocked = isUnlocked;
          researchNodes[index].isCompleted = isCompleted;
        }
      }
    }
    
    // Offline Earnings Logic
    final lastSaveTime = prefs.getInt('last_save_time');
    if (lastSaveTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (now - lastSaveTime) ~/ 1000;
      
      if (diffSeconds > 10) { // Only count if away for more than 10 seconds
        double totalHashRate = rigs.fold(0, (sum, rig) => sum + rig.totalHashRate);
        if (totalHashRate > 0) {
           double offlineEarnings = diffSeconds * totalHashRate * prestigeMultiplier;
           wallet += offlineEarnings;
           lifetimeEarnings += offlineEarnings;
           debugPrint('Offline for $diffSeconds s. Earned $offlineEarnings');
           // Note: We might want to expose this to UI to show a dialog
           offlineEarningsAmount = offlineEarnings;
        }
      }
    }
    
    notifyListeners();
  }
  
  // Temporary storage for UI dialog
  double? offlineEarningsAmount;
  
  void clearOfflineEarnings() {
    offlineEarningsAmount = null;
    notifyListeners();
  }
}


