import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/rig.dart';
import '../models/research_node.dart';
import '../models/news_event.dart';
import '../services/persistence_service.dart';
import '../services/economy_service.dart';

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;
  
  final _persistence = PersistenceService();
  final _economy = EconomyService();

  List<Rig> rigs = [
    Rig(id: 'cpu_rig', name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1.0),
    Rig(id: 'gpu_rig', name: 'GPU Rack', baseCost: 1500, baseHashRate: 20.0),
    Rig(id: 'asic_rig', name: 'ASIC Miner', baseCost: 12000, baseHashRate: 250.0),
    Rig(id: 'quantum', name: 'Quantum Computer', baseCost: 150000, baseHashRate: 5000.0),
  ];

  int govTokens = 0;
  int spentGovTokens = 0; // Track spent tokens

  
  // Perks: keys are 'click_power', 'rig_cost', 'hash_bonus'
  Map<String, int> perks = {
    'click_power': 0,
    'rig_cost': 0,
    'hash_bonus': 0,
  };
  

  
  bool soundEnabled = true;

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    await _saveGame();
    notifyListeners();
  }

  // Full Reset (Wipe Save)
  Future<void> resetGame() async {
    await _persistence.resetGame();
    
    // Reset Memory
    wallet = 0;
    lifetimeEarnings = 0;
    govTokens = 0;
    spentGovTokens = 0;
    soundEnabled = true;
    
    perks.updateAll((key, value) => 0);
    // Reset costs
    perkCosts.updateAll((key, value) {
       switch(key) {
         case 'click_power': return 5;
         case 'rig_cost': return 10;
         case 'hash_bonus': return 15;
         default: return 10;
       }
    });

    for (var rig in rigs) {
      rig.amount = 0;
    }
    
    for (var node in researchNodes) {
        node.isCompleted = false;
        node.isUnlocked = node.requirements.isEmpty; // Basic ones unlock
    }

    notifyListeners();
  }

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
  // 10% bonus per token (Held + Spent)
  // 10% bonus per token (Held + Spent)
  double get prestigeMultiplier => _economy.calculatePrestigeMultiplier(govTokens, spentGovTokens);

  // ECONOMY 2.0
  double networkDifficulty = 100.0;
  double blockReward = 50.0;
  int blocksMined = 0;
  int nextHalvingThreshold = 5000;
  
  // Chaos Logic
  double chaosIncomeMultiplier = 1.0;
  double chaosCostMultiplier = 1.0;

  Timer? _gameTimer;
  Timer? _chaosTimer;
  NewsEvent? currentNews;

  @override
  void dispose() {
    _gameTimer?.cancel();
    _chaosTimer?.cancel();
    super.dispose();
  }

  GameLogic() {
    loadGame().then((_) {
      _startGameLoop();
      _startChaosTimer();
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
  
  void _startChaosTimer() {
    // Random event check.
    // 10% chance every 30 seconds? 
    // Or Guaranteed every X minutes?
    // Let's go with: Check every 10s, 5% chance. (= approx 1 event every 3.3 mins avg)
    _chaosTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (Random().nextDouble() < 0.05) {
        _triggerRandomEvent();
      }
    });
  }
  
  void _triggerRandomEvent() {
    final random = Random();
    final type = EventType.values[random.nextInt(EventType.values.length)];
    
    // Reset multipliers/temporary effects before applying new ones?
    // Or allow stacking? For simplicity: Reset first.
    chaosIncomeMultiplier = 1.0;
    chaosCostMultiplier = 1.0;
    
    String message = '';
    double value = 0;
    int duration = 30; // Default duration
    Color color = Colors.white;
    
    switch(type) {
      case EventType.info:
         message = "Bitcoin adoption hits 90% globally!";
         color = Colors.blueAccent;
         break;
      case EventType.marketCrash:
         message = "MARKET CRASH: Panic sellers flooding the market.";
         chaosIncomeMultiplier = 0.5; // -50% Income
         value = -50;
         color = Colors.redAccent;
         break;
      case EventType.bullRun:
         message = "BULL RUN: Institutional investors entering!";
         chaosIncomeMultiplier = 2.0; // +100% Income
         value = 100;
         color = Colors.greenAccent;
         break;
      case EventType.hack:
         message = "SECURITY BREACH: Hot wallet compromised!";
         // Immediate loss
         double loss = wallet * 0.15; // 15% Loss
         wallet -= loss;
         value = -loss;
         color = Colors.red;
         duration = 10; // Show for shorter time
         break;
      case EventType.cheapEnergy:
         message = "Surplus Energy: Electricity costs drop significantly.";
         chaosCostMultiplier = 0.7; // 30% Discount
         value = -30;
         color = Colors.cyanAccent;
         break;
    }
    
    currentNews = NewsEvent(
      message: message, 
      type: type, 
      value: value, 
      durationSeconds: duration,
      color: color,
    );
    notifyListeners();
    
    // Clear news and effects after duration
    Future.delayed(Duration(seconds: duration), () {
      // Only clear if it's still the same event (simple check)
      if (currentNews?.message == message) {
        currentNews = null;
        chaosIncomeMultiplier = 1.0;
        chaosCostMultiplier = 1.0;
        notifyListeners();
      }
    });
  }

  double get globalHashRate {
    return _economy.calculateGlobalHashRate(rigs, perks, isResearched('chip_fab'), _researchHashMultiplier);
  }

  void _mine() {
    double finalHashRate = globalHashRate; // Uses economy service internally now via getter

    
    // AI Manager
    if (isResearched('ai_manager')) {
       _autoClickCounter++;
       if (_autoClickCounter >= 5) { 
         clickMine();
         _autoClickCounter = 0;
       }
    }

    if (finalHashRate > 0) {
      // Formula: (Hash / Difficulty) * Reward * Prestige * Chaos
      double income = (finalHashRate / networkDifficulty) * blockReward * prestigeMultiplier * chaosIncomeMultiplier;
      
      wallet += income;
      lifetimeEarnings += income;
      
      networkDifficulty += 0.1;
      blocksMined++;
      
      if (blocksMined >= nextHalvingThreshold) {
        _triggerHalving();
      }
      notifyListeners();
    }
  }

  void _triggerHalving() {
    blockReward /= 2;
    nextHalvingThreshold += 10000; 
    
    // Announce Halving
    currentNews = NewsEvent(
      message: "BITCOIN HALVING: Block Reward Cut in Half!", 
      type: EventType.info,
      durationSeconds: 15,
      color: Colors.purpleAccent,
      value: -50
    );
    notifyListeners();
  }

  int get pendingGovTokens => _economy.calculatePendingGovTokens(lifetimeEarnings);

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    govTokens += tokensToClaim;
    
    // Reset Progress
    wallet = 0;
    lifetimeEarnings = 0;
    
    // Reset Economy 2.0 (New Chain)
    networkDifficulty = 100.0;
    blockReward = 50.0;
    blocksMined = 0;
    nextHalvingThreshold = 5000;
    
    // Note: We do NOT reset perks. They are permanent.
    for (var rig in rigs) {
      rig.amount = 0;
    }
    
    // Reset Research (Economy 2.0)
    for (var node in researchNodes) {
        node.isCompleted = false;
        node.isUnlocked = node.requirements.isEmpty; // Basic ones unlock
    }
     
    _saveGame();
    
    notifyListeners();
  }

  void clickMine() {
    double clickPower = _economy.calculateClickPower(perks);
    double clickValue = (clickPower / networkDifficulty) * blockReward * prestigeMultiplier * chaosIncomeMultiplier;
    
    wallet += clickValue;
    lifetimeEarnings += clickValue;
    notifyListeners();
  }

  void buyRig(String rigId) {
    int index = rigs.indexWhere((r) => r.id == rigId);
    if (index != -1) {
      Rig rig = rigs[index];
      
      double cost = getRigCost(rig); // Encapsulated logic
      
      if (wallet >= cost) {
        wallet -= cost;
        rig.amount++;
        notifyListeners();
        _saveGame();
      }
    }
  }

  double getRigCost(Rig rig) {
    return _economy.calculateRigCost(rig, perks, isResearched('better_cooling'), chaosCostMultiplier);
  }

  void buyPerk(String perkId) {
    if (perks.containsKey(perkId) && perkCosts.containsKey(perkId)) {
      int cost = perkCosts[perkId]!;

      
      // Check Max Level for Rig Cost
      if (perkId == 'rig_cost' && (perks[perkId] ?? 0) >= 18) {
         return; // Maxed out (90%)
      }

      if (govTokens >= cost) {
        govTokens -= cost;
        spentGovTokens += cost;
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
    await _persistence.saveGame(
      wallet: wallet,
      lifetimeEarnings: lifetimeEarnings,
      govTokens: govTokens,
      spentGovTokens: spentGovTokens,
      perks: perks,
      perkCosts: perkCosts,
      rigs: rigs,
      researchNodes: researchNodes,
      soundEnabled: soundEnabled,
      networkDifficulty: networkDifficulty,
      blockReward: blockReward,
      blocksMined: blocksMined,
      nextHalvingThreshold: nextHalvingThreshold,
    );
  }

  Future<void> loadGame() async {
    final data = await _persistence.loadGame();
    
    wallet = data['wallet'];
    lifetimeEarnings = data['lifetimeEarnings'];
    govTokens = data['govTokens'];
    spentGovTokens = data['spentGovTokens'];
    soundEnabled = data['sound_enabled'];
    
    networkDifficulty = data['networkDifficulty'];
    blockReward = data['blockReward'];
    blocksMined = data['blocksMined'];
    nextHalvingThreshold = data['nextHalvingThreshold'];
    
    if (data.containsKey('perks')) {
      perks.addAll(data['perks'].cast<String, int>());
    }
    if (data.containsKey('perkCosts')) {
      perkCosts.addAll(data['perkCosts'].cast<String, int>());
    }

    if (data.containsKey('rigs')) {
      final List<dynamic> decoded = data['rigs'];
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final amount = jsonItem['amount'];
        final index = rigs.indexWhere((r) => r.id == id);
        if (index != -1) rigs[index].amount = amount;
      }
    }
    
    if (data.containsKey('research')) {
      final List<dynamic> decoded = data['research'];
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

    // Offline Earnings
    final lastSaveTime = data['last_save_time'];
    if (lastSaveTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (now - lastSaveTime) ~/ 1000;
      
      if (diffSeconds > 10) { 
        double totalHashRate = rigs.fold(0, (sum, rig) => sum + rig.totalHashRate);
        if (totalHashRate > 0) {
           double offline = _economy.calculatePrestigeMultiplier(govTokens, spentGovTokens); // Reuse this for offline calc logic if needed or just use multiplier
           // Wait, economy service logic for offline earnings wasn't imported yet fully, calculating inline for now but using multiplier from logic
           double mult = prestigeMultiplier;
           double offlineEarnings = diffSeconds * totalHashRate * mult;
           
           wallet += offlineEarnings;
           lifetimeEarnings += offlineEarnings;
           offlineEarningsAmount = offlineEarnings;
        }
      }
    }
    
    // Migration
    if (spentGovTokens == 0 && perks.values.any((v) => v > 0)) {
       spentGovTokens = _economy.recalculateSpentTokens(perks);
       _saveGame();
    }
    
    notifyListeners();
  }

  double? offlineEarningsAmount;
  
  void clearOfflineEarnings() {
    offlineEarningsAmount = null;
    notifyListeners();
  }
}


