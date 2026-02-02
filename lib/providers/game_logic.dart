import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/ids.dart';
import '../models/rig.dart';
import '../models/research_node.dart';
import '../models/news_event.dart';
import '../services/economy_service.dart';
import '../services/stash_service.dart';

// Repositories
import '../repositories/game_repository.dart';
import '../repositories/settings_repository.dart';

// Managers
import '../logic/managers/mining_manager.dart';
import '../logic/managers/research_manager.dart';
import '../logic/managers/perk_manager.dart';

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;

  final GameRepository _gameRepo;
  final SettingsRepository _settingsRepo;
  final EconomyService _economy;
  final StashService _stash;

  // Managers
  late final MiningManager _miningManager;
  late final ResearchManager _researchManager;
  late final PerkManager _perkManager;

  StashService get stashService => _stash;

  // Expose Managers for UI (if needed, or expose specific data)
  // Ideally expose data.
  List<ResearchNode> get researchNodes => _researchManager.researchNodes;
  Map<String, int> get perks => _perkManager.perks;
  Map<String, int> get perkCosts => _perkManager.perkCosts;

  // Mining Data Proxies
  double get blockReward => _miningManager.blockReward;
  set blockReward(double value) => _miningManager.blockReward = value;

  int get blocksMined => _miningManager.blocksMined;
  set blocksMined(int value) => _miningManager.blocksMined = value;

  int get nextHalvingThreshold => _miningManager.nextHalvingThreshold;
  set nextHalvingThreshold(int value) =>
      _miningManager.nextHalvingThreshold = value;

  double get bitcoinExchangeRate => _miningManager.bitcoinExchangeRate;
  set bitcoinExchangeRate(double value) =>
      _miningManager.bitcoinExchangeRate = value;

  List<Rig> rigs = [
    Rig(
      id: RigIds.cpuRig,
      name: 'Starter CPU Rig',
      baseCost: 100,
      baseHashRate: 1.0,
    ),
    Rig(
      id: RigIds.gpuRig,
      name: 'GPU Rack',
      baseCost: 1500,
      baseHashRate: 20.0,
    ),
    Rig(
      id: RigIds.asicRig,
      name: 'ASIC Miner',
      baseCost: 12000,
      baseHashRate: 250.0,
    ),
    Rig(
      id: RigIds.quantumRig,
      name: 'Quantum Computer',
      baseCost: 150000,
      baseHashRate: 5000.0,
    ),
  ];

  int govTokens = 0;
  int chips = 0;
  int spentGovTokens = 0; // Track spent tokens

  bool soundEnabled = true;
  bool showFiatPrices = false; // Toggle for "Astronomical" Credit prices

  // Offline Earnings (UI Display)
  double? offlineEarningsAmount;

  Future<void> clearOfflineEarnings() async {
    offlineEarningsAmount = null;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    await _settingsRepo.saveSettings(
      soundEnabled: soundEnabled,
      showFiatPrices: showFiatPrices,
    );
    notifyListeners();
  }

  Future<void> toggleFiatDisplay() async {
    showFiatPrices = !showFiatPrices;
    await _settingsRepo.saveSettings(
      soundEnabled: soundEnabled,
      showFiatPrices: showFiatPrices,
    );
    notifyListeners();
  }

  // Full Reset (Wipe Save)
  Future<void> resetGame() async {
    await _gameRepo.clearSave();

    // Reset Memory
    wallet = 0;
    lifetimeEarnings = 0;
    govTokens = 0;
    spentGovTokens = 0;
    chips = 0;
    // soundEnabled = true; // Keep settings? usually yes.
    // showFiatPrices = false;

    // Clear Stash
    _stash.ownedArtifacts.clear();

    // Reset Managers
    _perkManager.reset();
    _researchManager.reset();
    _miningManager.reset();

    for (var rig in rigs) {
      rig.amount = 0;
    }

    notifyListeners();
  }

  int _autoClickCounter = 0;

  void buyResearch(String researchId) {
    double cost = _researchManager.tryBuy(researchId, wallet);
    if (cost > 0) {
      wallet -= cost;
      notifyListeners();
      _saveGame();
    }
  }

  bool isResearched(String id) => _researchManager.isResearched(id);

  double get prestigeMultiplier =>
      _economy.calculatePrestigeMultiplier(govTokens, spentGovTokens);

  double get networkDifficulty =>
      _miningManager.calculateNetworkDifficulty(lifetimeEarnings);

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

  GameLogic({
    required GameRepository gameRepository,
    required SettingsRepository settingsRepository,
    required EconomyService economyService,
    required StashService stashService,
    bool startTimers = true,
    bool loadOnStart = true,
  }) : _gameRepo = gameRepository,
       _settingsRepo = settingsRepository,
       _economy = economyService,
       _stash = stashService {
    // Initialize Managers
    _miningManager = MiningManager();
    _researchManager = ResearchManager();
    _perkManager = PerkManager();

    if (loadOnStart) {
      loadGame().then((_) {
        if (_isDisposed) return;
        if (startTimers) {
          _startGameLoop();
          _startChaosTimer();
          _startAnomalyTimer();
        }
      });
    }
  }

  // Spawns anomalies randomly
  void _startAnomalyTimer() {
    _anomalyTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isAnomalyActive && Random().nextDouble() < 0.05) {
        double dx = Random().nextDouble() * 300;
        double dy = Random().nextDouble() * 500;
        anomalyPosition = Offset(dx, dy);
        isAnomalyActive = true;
        notifyListeners();

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
    chips += 1;
    notifyListeners();
    _saveGame();
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _mine();
    });

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveGame();
      debugPrint('Auto-Saved Game');
    });
  }

  void _startChaosTimer() {
    int nextInterval = 60 + Random().nextInt(240);
    _chaosTimer = Timer(Duration(seconds: nextInterval), () {
      _triggerRandomEvent();
      _startChaosTimer();
    });
  }

  void _triggerRandomEvent() {
    final random = Random();
    final type = EventType.values[random.nextInt(EventType.values.length)];

    chaosIncomeMultiplier = 1.0;
    chaosCostMultiplier = 1.0;

    String message = '';
    double value = 0;
    int duration = 30;
    Color color = Colors.white;

    switch (type) {
      case EventType.info:
        message = "Bitcoin adoption hits 90% globally!";
        color = Colors.blueAccent;
        duration = 60;
        break;
      case EventType.marketCrash:
        message = "MARKET CRASH: Panic sellers flooding the market.";
        chaosIncomeMultiplier = 0.5;
        value = -50;
        color = Colors.redAccent;
        duration = 90 + random.nextInt(60);
        break;
      case EventType.bullRun:
        message = "BULL RUN: Institutional investors entering!";
        chaosIncomeMultiplier = 2.0;
        value = 100;
        color = Colors.greenAccent;
        duration = 90 + random.nextInt(60);
        break;
      case EventType.hack:
        message = "SECURITY BREACH: Hot wallet compromised!";
        double loss = wallet * 0.15;
        wallet -= loss;
        value = -loss;
        color = Colors.red;
        duration = 45;
        break;
      case EventType.cheapEnergy:
        message = "Surplus Energy: Electricity costs drop significantly.";
        chaosCostMultiplier = 0.7;
        value = -30;
        color = Colors.cyanAccent;
        duration = 120;
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

    Future.delayed(Duration(seconds: duration), () {
      if (currentNews?.message == message) {
        currentNews = null;
        chaosIncomeMultiplier = 1.0;
        chaosCostMultiplier = 1.0;
        notifyListeners();
      }
    });
  }

  double get globalHashRate {
    // 1. Calculate Base Hash Rate
    double base = _economy.calculateGlobalHashRate(
      rigs,
      _perkManager.perks,
      _researchManager.isResearched(ResearchIds.chipFab),
      _researchManager.getResearchHashMultiplier(),
    );
    return base * _stash.getTotalHashBonus();
  }

  void _mine() {
    // Auto Clicker
    if (_researchManager.isResearched(ResearchIds.aiManager)) {
      _autoClickCounter++;
      if (_autoClickCounter >= 5) {
        clickMine();
        _autoClickCounter = 0;
      }
    }

    double finalHashRate = globalHashRate;
    if (finalHashRate > 0) {
      double diff = networkDifficulty;

      double incomeSats = _miningManager.calculateMiningIncome(
        hashRate: finalHashRate,
        difficulty: diff,
        prestigeMultiplier: prestigeMultiplier,
        chaosMultiplier: chaosIncomeMultiplier,
        lifetimeEarnings: lifetimeEarnings,
      );

      wallet += incomeSats;
      lifetimeEarnings += incomeSats;

      _miningManager.incrementBlocksMined();

      if (_miningManager.checkHalving()) {
        _triggerHalving();
      }
      notifyListeners();
    }
  }

  void _triggerHalving() {
    currentNews = NewsEvent(
      message: "BITCOIN HALVING: Block Reward Cut in Half!",
      type: EventType.info,
      durationSeconds: 15,
      color: Colors.purpleAccent,
      value: -50,
    );
    notifyListeners();
  }

  int get pendingGovTokens =>
      _economy.calculatePendingGovTokens(lifetimeEarnings);

  void clickMine() {
    double clickPower = _economy.calculateClickPower(_perkManager.perks);
    clickPower *= _stash.getClickPowerMultiplier();

    double diff = networkDifficulty;

    double clickSats = _miningManager.calculateMiningIncome(
      hashRate: clickPower,
      difficulty: diff,
      prestigeMultiplier: prestigeMultiplier,
      chaosMultiplier: chaosIncomeMultiplier,
      lifetimeEarnings: lifetimeEarnings,
    );

    wallet += clickSats;
    lifetimeEarnings += clickSats;
    notifyListeners();
  }

  double get estimatedClickValue {
    double clickPower =
        _economy.calculateClickPower(_perkManager.perks) *
        _stash.getClickPowerMultiplier();

    // We can reuse MiningManager logic passing dummy 'hashRate' = clickPower?
    // Yes, MiningManager.calculateMiningIncome handles the formula.
    // But we need to handle "Infinite difficulty" etc.

    if (networkDifficulty.isInfinite) return 0;

    return _miningManager.calculateMiningIncome(
      hashRate: clickPower,
      difficulty: networkDifficulty,
      prestigeMultiplier: prestigeMultiplier,
      chaosMultiplier: chaosIncomeMultiplier,
      lifetimeEarnings: lifetimeEarnings,
    );
  }

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    govTokens += tokensToClaim;
    _miningManager.bitcoinExchangeRate *= (1.0 + tokensToClaim);

    // Reset Progress
    wallet = 0;
    lifetimeEarnings = 0;

    // Reset Logic via Manager
    _miningManager.hardForkReset();

    // Reset Rigs
    for (var rig in rigs) {
      rig.amount = 0;
    }

    // Reset Research (ResearchManager)
    _researchManager.reset();

    _saveGame();
    notifyListeners();
  }

  void buyRig(String rigId) {
    int index = rigs.indexWhere((r) => r.id == rigId);
    if (index != -1) {
      Rig rig = rigs[index];
      double costSats = getRigCostInSats(rig);

      if (wallet >= costSats) {
        wallet -= costSats;
        rig.amount++;
        notifyListeners();
        _saveGame();
      }
    }
  }

  double getRigCostInCredits(Rig rig) {
    double base = _economy.calculateRigCost(
      rig,
      _perkManager.perks,
      _researchManager.isResearched(ResearchIds.betterCooling),
      chaosCostMultiplier,
      isSolarPowerResearched: _researchManager.isResearched(
        ResearchIds.solarPower,
      ),
    );
    double discount = _stash.getMainCostDiscount();
    double finalMult = 1.0 - discount;
    if (finalMult < 0.05) finalMult = 0.05;
    return base * finalMult;
  }

  double getRigCost(Rig rig) {
    return getRigCostInCredits(rig) / _miningManager.bitcoinExchangeRate;
  }

  double getRigCostInSats(Rig rig) => getRigCost(rig);

  void buyPerk(String perkId) {
    int cost = _perkManager.tryBuy(perkId, govTokens);
    if (cost > 0) {
      govTokens -= cost;
      spentGovTokens += cost;
      _saveGame();
      notifyListeners();
    }
  }

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
    await _gameRepo.saveGameState(
      wallet: wallet,
      lifetimeEarnings: lifetimeEarnings,
      govTokens: govTokens,
      spentGovTokens: spentGovTokens,
      perks: _perkManager.perks,
      perkCosts: _perkManager.perkCosts,
      rigs: rigs,
      researchNodes: _researchManager.researchNodes,
      // economy
      networkDifficulty: networkDifficulty,
      blockReward: _miningManager.blockReward,
      blocksMined: _miningManager.blocksMined,
      nextHalvingThreshold: _miningManager.nextHalvingThreshold,
      bitcoinExchangeRate: _miningManager.bitcoinExchangeRate,
      chips: chips,
      stash: _stash.saveStash(),
    );
  }

  Future<void> loadGame() async {
    final settings = await _settingsRepo.loadSettings();
    soundEnabled = settings['sound_enabled'];
    showFiatPrices = settings['show_fiat_prices'];

    final data = await _gameRepo.loadGameState();

    wallet = data['wallet'];
    lifetimeEarnings = data['lifetimeEarnings'];
    govTokens = data['govTokens'];
    spentGovTokens = data['spentGovTokens'];

    // chips was missing in loadGameState initial impl?
    // Wait, let's check GameRepository.loadGameState content provided previously.
    // Yes, data['chips'] was added.
    chips = data['chips'] ?? 0;

    if (data.containsKey('stash')) {
      _stash.loadStash(Map<String, dynamic>.from(data['stash']));
    }

    // Load Mining Manager Data
    _miningManager.blockReward = data['blockReward'];
    _miningManager.blocksMined = data['blocksMined'];
    _miningManager.nextHalvingThreshold = data['nextHalvingThreshold'];
    double rate = data['bitcoinExchangeRate'] ?? 1.0;
    if (rate <= 0.0) rate = 1.0;
    _miningManager.bitcoinExchangeRate = rate;

    // Load Perk Manager Data
    if (data.containsKey('perks')) {
      _perkManager.perks.addAll(data['perks'].cast<String, int>());
    }
    if (data.containsKey('perkCosts')) {
      _perkManager.perkCosts.addAll(data['perkCosts'].cast<String, int>());
    }

    // Load Rigs (Still local)
    if (data.containsKey('rigs')) {
      final List<dynamic> decoded = data['rigs'];
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final amount = jsonItem['amount'];
        final index = rigs.indexWhere((r) => r.id == id);
        if (index != -1) rigs[index].amount = amount;
      }
    }

    // Load Research Manager Data
    if (data.containsKey('research')) {
      final List<dynamic> decoded = data['research'];
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final isUnlocked = jsonItem['isUnlocked'];
        final isCompleted = jsonItem['isCompleted'];
        final index = _researchManager.researchNodes.indexWhere(
          (r) => r.id == id,
        );
        if (index != -1) {
          _researchManager.researchNodes[index].isUnlocked = isUnlocked;
          _researchManager.researchNodes[index].isCompleted = isCompleted;
        }
      }
    }

    // Offline Earnings
    final lastSaveTime = data['last_save_time'];
    if (lastSaveTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (now - lastSaveTime) ~/ 1000;

      if (diffSeconds > 10) {
        _simulateOfflineMining(diffSeconds);
      }
    }

    // Migration
    if (spentGovTokens == 0 && _perkManager.perks.values.any((v) => v > 0)) {
      spentGovTokens = _economy.recalculateSpentTokens(_perkManager.perks);
      _saveGame();
    }

    notifyListeners();
  }

  void _simulateOfflineMining(int totalSeconds) {
    if (totalSeconds <= 0) return;

    if (totalSeconds > 31536000) {
      totalSeconds = 31536000;
    }

    // Simplified Offline Mining:
    // We already have logic to execute.
    // Just run 1 loop? No, that's not enough.
    // The original code tried to run a loop or chunks.
    // Let's implement a simplified chunked simulation using MiningManager.

    // We need 'hashRate'. Ideally hashRate is constant during offline (no updates).
    double hashRate = globalHashRate; // Current state
    if (hashRate <= 0) return;

    // We can simulate tick by tick or in chunks.
    // Let's do huge chunks if possible.
    // Issue: Difficulty changes.
    // Current difficulty depends on lifetimeEarnings.
    // MiningManager calculates difficulty.

    // Let's simulate in 10-second chunks (or 10-block chunks?).
    // Refactored logic:
    double accrued = 0;

    // Use larger steps for performance.
    // To speed up:
    // This is run once on load.

    // Simplification:
    // Just add (Rate / Current Diff) * Seconds?
    // No, diff grows.

    // Let's use a simple loop, but maybe skipping if Steps is huge?
    // For now, let's keep it simple: 1 tick = 1 second.
    // If > 10000 seconds, maybe average it?
    // Let's stick to a safe loop.

    // Limit loop to 1000 iterations for performance?
    // If totalSeconds > 1000, we aggregate.
    double timePerTick = 1.0;
    int iterations = totalSeconds;

    if (totalSeconds > 5000) {
      iterations = 5000;
      timePerTick = totalSeconds / 5000.0;
    }

    for (int i = 0; i < iterations; i++) {
      // Difficulty at CURRENT lifetimeEarnings
      double diff = networkDifficulty;

      double income = _miningManager.calculateMiningIncome(
        hashRate: hashRate,
        difficulty: diff,
        prestigeMultiplier: prestigeMultiplier,
        chaosMultiplier: 1.0, // No chaos offline
        lifetimeEarnings: lifetimeEarnings,
      );

      income *= timePerTick; // Scale by time skipped

      if (lifetimeEarnings + income > GameConstants.maxSupplySats) {
        income = GameConstants.maxSupplySats - lifetimeEarnings;
      }

      wallet += income;
      lifetimeEarnings += income;
      accrued += income;

      // Update blocks?
      // MiningManager.incrementBlocksMined() is per TICK/Block.
      // Theoretically 1 sec = 1 block?
      // Original code: _mine() runs every 1 second.
      // So yes.
      _miningManager.blocksMined += timePerTick.toInt();
      if (_miningManager.checkHalving()) {
        // Halving happened?
        // _triggerHalving() is UI. Offline we just slash reward?
        // checkHalving() already slashes reward.
      }

      if (lifetimeEarnings >= GameConstants.maxSupplySats) break;
    }

    if (accrued > 0) {
      offlineEarningsAmount = accrued;
      _saveGame();
    }
  }
}
