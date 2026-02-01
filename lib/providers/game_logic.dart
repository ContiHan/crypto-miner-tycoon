import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../models/rig.dart';
import '../models/research_node.dart';
import '../models/news_event.dart';
import '../services/persistence_service.dart';
import '../services/economy_service.dart';
import '../services/stash_service.dart';

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;
  
  final _persistence = PersistenceService();
  final _economy = EconomyService();
  final _stash = StashService();
  
  StashService get stashService => _stash;

  List<Rig> rigs = [
    Rig(id: 'cpu_rig', name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1.0),
    Rig(id: 'gpu_rig', name: 'GPU Rack', baseCost: 1500, baseHashRate: 20.0),
    Rig(id: 'asic_rig', name: 'ASIC Miner', baseCost: 12000, baseHashRate: 250.0),
    Rig(id: 'quantum', name: 'Quantum Computer', baseCost: 150000, baseHashRate: 5000.0),
  ];

  int govTokens = 0;
  int chips = 0;
  int spentGovTokens = 0; // Track spent tokens

  
  // Perks: keys are 'click_power', 'rig_cost', 'hash_bonus'
  Map<String, int> perks = {
    'click_power': 0,
    'rig_cost': 0,
    'hash_bonus': 0,
  };
  

  
  bool soundEnabled = true;
  bool showFiatPrices = false; // Toggle for "Astronomical" Credit prices

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    await _saveGame();
    notifyListeners();
  }

  Future<void> toggleFiatDisplay() async {
    showFiatPrices = !showFiatPrices;
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
    chips = 0;
    soundEnabled = true;
    showFiatPrices = false; // Reset this too
    
    // Clear Stash
    _stash.ownedArtifacts.clear();
    
    // Clear Perks
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

    // Reset Economy 2.0
    blockReward = 50.0 * 100000000; // 50 BTC in Sats
    blocksMined = 0;
    nextHalvingThreshold = 5000;
    bitcoinExchangeRate = 1.0;
    
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
  // networkDifficulty is dynamic based on Total Mined.
  // Formula: Base + Linear (Simulated Growth) + Asymptote (Wall)
  double get networkDifficulty {
     double totalMined = lifetimeEarnings;
     if (totalMined >= _maxSupplySats) return double.infinity;
     
     // 1. Asymptote (The Wall at 21M)
     double asymptote = 0.0;
     if (totalMined > 0) {
        asymptote = 100.0 / pow(1.0 - (totalMined / _maxSupplySats), 2) - 100.0;
     }

     // 2. Linear Growth (Simulated Competition)
     // Adds difficulty based on progress to make early game feel alive.
     // e.g. every 1000 Sats mined adds +1 difficulty.
     double linearGrowth = totalMined / 1000.0; 
     
     // Base Difficulty 100.0 (User Request)
     return 100.0 + linearGrowth + asymptote;
  }
  
  // Mining Divisor to balance 50 BTC reward with 100 Difficulty.
  // 5B Sats / 50M = 100 Sats effective pool.
  // 1 Hash / 100 Diff * 100 Sats = 1 Sat Income.
  static const double _miningDivisor = 50000000.0;
  
  double blockReward = 50.0 * 100000000; // 50 BTC
  int blocksMined = 0;
  int nextHalvingThreshold = 5000;
  
  // Chaos Logic
  double chaosIncomeMultiplier = 1.0;
  double chaosCostMultiplier = 1.0;

  // Anomaly Logic
  bool isAnomalyActive = false;
  Offset anomalyPosition = Offset.zero;
  Timer? _anomalyTimer;

  Timer? _gameTimer;
  Timer? _chaosTimer;
  Timer? _autoSaveTimer;
  NewsEvent? currentNews;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _gameTimer?.cancel();
    _chaosTimer?.cancel();
    _anomalyTimer?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  GameLogic({bool startTimers = true}) {
    loadGame().then((_) {
      if (_isDisposed) return; // Prevent starting timers if already disposed
      if (startTimers) {
        _startGameLoop();
        _startChaosTimer();
        _startAnomalyTimer();
      }
    });
  }

  // Spawns anomalies randomly
  void _startAnomalyTimer() {
    // Check every 5 seconds, 5% chance to spawn (approx 1 per 100 sec)
    _anomalyTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isAnomalyActive && Random().nextDouble() < 0.05) { 
         // Spawn
         double dx = Random().nextDouble() * 300; // Simplified
         double dy = Random().nextDouble() * 500;
         anomalyPosition = Offset(dx, dy); 
         isAnomalyActive = true;
         notifyListeners();
         
         // Despawn after 4 seconds if not clicked
         Future.delayed(const Duration(seconds: 4), () {
            if (isAnomalyActive) {
              isAnomalyActive = false;
              notifyListeners();
            }
         });
      }
    });
  }

  void clickAnomaly() {
    if (!isAnomalyActive) return;
    
    isAnomalyActive = false;
    chips += 1; // +1 MicroChip
    notifyListeners();
    _saveGame();
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _mine();
    });
    
    // Auto-Save every 30 seconds
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
    double base = _economy.calculateGlobalHashRate(rigs, perks, isResearched('chip_fab'), _researchHashMultiplier);
    return base * _stash.getTotalHashBonus();
  }

  // ECONOMY 2.0 - Exchange Rate Model
  
  // Wallet is now in SATOSHIS. 
  // Max Supply = 21,000,000 BTC * 100,000,000 Sats = 2,100,000,000,000,000 Sats.
  static const double _maxSupplySats = 2100000000000000;
  
  // Exchange Rate: How many "Credits" is 1 Satoshi worth?
  // Starts at 1.0. Increases with HashRate/Progress.
  // Rig costs are in Credits.
  double bitcoinExchangeRate = 1.0; 
  
  // Mining Logic
  // Network Difficulty acts as the "Wall".
  // As mined supply approaches Max, Difficulty -> Infinity.
  void _mine() {
    double finalHashRate = globalHashRate; 
    
    // Auto Clicker
    if (isResearched('ai_manager')) {
       _autoClickCounter++;
       if (_autoClickCounter >= 5) { 
         clickMine();
         _autoClickCounter = 0;
       }
    }

    if (finalHashRate > 0) {
      double difficulty = networkDifficulty;
      if (difficulty.isInfinite) return;

      double baseReward = finalHashRate / difficulty;
      double adjustedReward = blockReward / _miningDivisor;
      double incomeSats = baseReward * adjustedReward * prestigeMultiplier * chaosIncomeMultiplier;
      
      if (lifetimeEarnings + incomeSats > _maxSupplySats) {
         incomeSats = _maxSupplySats - lifetimeEarnings;
      }
      
      wallet += incomeSats;
      lifetimeEarnings += incomeSats;
      
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

  void clickMine() {
    double clickPower = _economy.calculateClickPower(perks);
    clickPower *= _stash.getClickPowerMultiplier(); // Stash Bonus
    
    double difficulty = networkDifficulty;
    if (difficulty.isInfinite) return;

    double baseReward = clickPower / difficulty;
    double adjustedReward = blockReward / _miningDivisor;
    double clickSats = baseReward * adjustedReward * prestigeMultiplier * chaosIncomeMultiplier;
    
    if (lifetimeEarnings + clickSats > _maxSupplySats) {
        clickSats = _maxSupplySats - lifetimeEarnings;
    }
    
    wallet += clickSats;
    lifetimeEarnings += clickSats;
    notifyListeners();
  }
  
  // Public getter for UI estimation
  double get estimatedClickValue {
     double clickPower = _economy.calculateClickPower(perks) * _stash.getClickPowerMultiplier();
     if (networkDifficulty.isInfinite) return 0;
     double baseReward = clickPower / networkDifficulty;
     double adjustedReward = blockReward / _miningDivisor;
     return baseReward * adjustedReward * prestigeMultiplier * chaosIncomeMultiplier;
  }

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    govTokens += tokensToClaim;
    // Better: Rate *= (1 + tokensToClaim);
    bitcoinExchangeRate *= (1.0 + tokensToClaim);

    // Reset Progress
    wallet = 0;
    lifetimeEarnings = 0;
    blocksMined = 0;
    
    // Reset Rigs but keep Perma-Perks
    for (var rig in rigs) {
      rig.amount = 0;
    }
    
    for (var node in researchNodes) {
        node.isCompleted = false;
        node.isUnlocked = node.requirements.isEmpty; 
    }
     
    _saveGame();
    notifyListeners();
  }

  void buyRig(String rigId) {
    int index = rigs.indexWhere((r) => r.id == rigId);
    if (index != -1) {
      Rig rig = rigs[index];
      
      // Cost in SATOSHIS
      double costSats = getRigCostInSats(rig);
      
      if (wallet >= costSats) {
        wallet -= costSats;
        rig.amount++;
        
        // Slight Rate Boost for economic activity?
        // bitcoinExchangeRate *= 1.001; 
        
        notifyListeners();
        _saveGame();
      }
    }
  }


  // COST LOGIC (Deflationary)
  // 1. Calculate Credit Cost (Inflating Fiat Value)
  double getRigCostInCredits(Rig rig) {
     double base = _economy.calculateRigCost(rig, perks, isResearched('better_cooling'), chaosCostMultiplier);
     // Apply Stash Discount
     double discount = _stash.getMainCostDiscount();
     double finalMult = 1.0 - discount;
     if (finalMult < 0.05) finalMult = 0.05; 
     return base * finalMult;
  }
  
  // 2. Calculate BTC Cost (Deflating Real Cost)
  // BTC = Credits / Rate
  double getRigCost(Rig rig) {
     return getRigCostInCredits(rig) / bitcoinExchangeRate;
  }
  
  // Backward compatibility
  double getRigCostInSats(Rig rig) => getRigCost(rig);

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
  
  // === TRADING & CRATES ===
  void buyChipsWithTokens() {
     const int cost = 5000;
     if (govTokens >= cost) {
        govTokens -= cost;
        spentGovTokens += cost; 
        chips += 1;
        notifyListeners();
        _saveGame();
     }
  }
  
  void buyCrate(bool isPremium) {
     int cost = isPremium ? 50 : 10;
     if (chips >= cost) {
        chips -= cost;
        _stash.openCrate(isPremium: isPremium);
        notifyListeners();
        _saveGame();
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
      bitcoinExchangeRate: bitcoinExchangeRate,
      chips: chips,
      stash: _stash.saveStash(),
    );
  }

  Future<void> loadGame() async {
    final data = await _persistence.loadGame();
    
    wallet = data['wallet'];
    lifetimeEarnings = data['lifetimeEarnings'];
    govTokens = data['govTokens'];
    spentGovTokens = data['spentGovTokens'];
    soundEnabled = data['sound_enabled'];
    showFiatPrices = data['show_fiat_prices'] ?? false;
    chips = data['chips'] ?? 0;
    
    if (data.containsKey('stash')) {
       _stash.loadStash(Map<String, dynamic>.from(data['stash']));
    }
    
    // networkDifficulty is calculated
    blockReward = data['blockReward'];
    blocksMined = data['blocksMined'];
    nextHalvingThreshold = data['nextHalvingThreshold'];
    // Default to 1.0 (Low start) if missing.
    bitcoinExchangeRate = data['bitcoinExchangeRate'] ?? 1.0;
    if (bitcoinExchangeRate <= 0.0) bitcoinExchangeRate = 1.0;
    
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
           // double offline = _economy.calculatePrestigeMultiplier(govTokens, spentGovTokens); 
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




