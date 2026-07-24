import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/ids.dart';
import '../content/rig_defs.dart';
import '../content/achievement_defs.dart';
import '../logic/channels.dart';
import '../models/rig.dart';
import '../models/research_node.dart';
import '../models/news_event.dart';
import '../services/economy_service.dart';
import '../services/stash_service.dart';
import '../services/casino_service.dart';

// Repositories
import '../repositories/game_repository.dart';
import '../repositories/settings_repository.dart';

// Services
import '../services/sound_service.dart';

// Managers
import '../logic/managers/mining_manager.dart';
import '../logic/managers/research_manager.dart';
import '../logic/managers/perk_manager.dart';
import '../logic/managers/achievement_manager.dart';
import '../logic/managers/class_manager.dart';
import '../logic/systems/anomaly_system.dart';
import '../logic/systems/chaos_event_system.dart';
import '../logic/systems/prestige_system.dart';

/// Outcome of a single mining tap — the sats gained and whether it was a crit.
/// Returned by [GameLogic.clickMine] so the UI can show the float text + juice.
class ClickResult {
  final double sats;
  final bool isCrit;
  const ClickResult(this.sats, this.isCrit);
}

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;

  final GameRepository _gameRepo;
  final SettingsRepository _settingsRepo;
  final EconomyService _economy;
  final StashService _stash;
  final SoundService _soundService;

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

  // Data-driven PERKS UI: the screen iterates these defs and reveals each perk
  // once its unlock threshold (totalGovTokensEver) is reached.
  Map<String, PerkDef> get perkDefs => PerkManager.defs;
  bool isPerkUnlocked(String id) =>
      _perkManager.isUnlocked(id, totalGovTokensEver);
  bool isPerkMaxed(String id) => _perkManager.isMaxed(id);
  String perkBonusText(String id) =>
      _perkManager.bonusText(id, _perkManager.getLevel(id));

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

  /// Cosmetic conversion of a sat value into the "astronomical fiat" display
  /// used by the $/₿ toggle. Purely visual — no gameplay effect.
  double toFiat(double sats) => sats * GameConstants.cosmeticUsdPerSat;

  // Runtime rigs are built from the data-driven catalog (lib/content/rig_defs).
  List<Rig> rigs = createRigs();

  /// Rigs the player should currently SEE: any already owned, plus any whose
  /// lifetime-earnings unlock threshold has been reached. Higher rigs reveal
  /// progressively as the player grows (content isn't all shown at once).
  List<Rig> get visibleRigs => rigs
      .where((r) => r.amount > 0 || lifetimeEarnings >= rigUnlockThreshold(r.id))
      .toList();

  /// The next still-locked rig, shown as a "???" silhouette teaser so the player
  /// always has a visible next goal (progressive discovery). Null if all revealed.
  Rig? get nextLockedRig {
    for (final r in rigs) {
      if (r.amount == 0 && lifetimeEarnings < rigUnlockThreshold(r.id)) return r;
    }
    return null;
  }

  /// Lifetime-earnings threshold that reveals [rigId].
  double unlockThresholdFor(String rigId) => rigUnlockThreshold(rigId);

  int govTokens = 0;
  int chips = 0;
  int spentGovTokens = 0; // Track spent tokens

  // Lifetime action counters (for achievements; persisted, never reset by prestige).
  int hardForkCount = 0;
  int softForkCount = 0;
  int newChainCount = 0;
  int cratesOpened = 0;
  int casinoSpins = 0;
  int casinoJackpots = 0;

  // SIMULATED casino (in-game Micro-Chips only; house edge EV<1).
  final CasinoService _casino = CasinoService();
  final Random _casinoRng; // injectable so tests can force deterministic spins

  /// Bet [bet] chips on the slots. Returns the spin (null if unaffordable).
  SlotSpin? playSlots(int bet) {
    if (bet <= 0 || chips < bet) return null;
    chips -= bet;
    final spin = _casino.spinSlots(bet, _casinoRng, luck: luckMultiplier);
    chips += spin.payout;
    casinoSpins++;
    if (spin.isJackpot) casinoJackpots++;
    _soundService.playBuy();
    if (spin.isJackpot) {
      _hapticHeavy();
    } else if (spin.isWin) {
      _hapticLight();
    }
    _evaluateAchievements();
    notifyListeners();
    _saveGame();
    return spin;
  }

  /// Double-or-Nothing on [bet] chips. Returns true=win, false=loss, null=unaffordable.
  bool? playDoubleOrNothing(int bet) {
    if (bet <= 0 || chips < bet) return null;
    chips -= bet;
    final win = _casino.flipWin(_casinoRng);
    if (win) {
      final lf = CasinoService.effectiveLuck(
          luckMultiplier, CasinoService.flipReturnToPlayer);
      chips += (bet * 2 * lf).floor();
    }
    casinoSpins++;
    _soundService.playBuy();
    _evaluateAchievements();
    notifyListeners();
    _saveGame();
    return win;
  }

  /// Drop a Plinko chip for [bet] chips. Returns the drop (null if unaffordable).
  PlinkoDrop? playPlinko(int bet) {
    if (bet <= 0 || chips < bet) return null;
    chips -= bet;
    final drop = _casino.dropPlinko(bet, _casinoRng, luck: luckMultiplier);
    chips += drop.payout;
    casinoSpins++;
    if (drop.isJackpot) casinoJackpots++;
    _soundService.playBuy();
    if (drop.isJackpot) {
      _hapticHeavy();
    } else if (drop.isWin) {
      _hapticLight();
    }
    _evaluateAchievements();
    notifyListeners();
    _saveGame();
    return drop;
  }

  // Achievements + Notoriety (permanent income bonus). Persists across all
  // prestige tiers like the Stash — only a full wipe clears it.
  final AchievementManager _achievements = AchievementManager();
  List<Achievement> get achievements => kAchievements;
  bool isAchievementUnlocked(String id) => _achievements.isUnlocked(id);
  bool isAchievementClaimed(String id) => _achievements.isClaimed(id);
  bool isAchievementClaimable(String id) => _achievements.isClaimable(id);
  int get achievementsUnlocked => _achievements.unlockedCount;
  int get achievementsTotal => _achievements.total;
  int get unclaimedAchievements => _achievements.unclaimedCount;
  double get notorietyBonus => _achievements.notorietyBonus;
  double get notorietyMultiplier => _achievements.notorietyMultiplier;

  /// Aggregate Luck factor (>=1, softcapped) from all channel sources. Scales
  /// crit chance and casino winnings (the latter clamped so casino RTP stays <1).
  double get luckMultiplier =>
      buildChannels().multiplier(Channel.luck, softStart: 1.5, power: 0.5);

  /// Aggregate Volatility factor (1.0 with no sources) — scales chaos-event
  /// frequency. Sources arrive with classes (Pool lowers it, others raise it).
  double get volatilityMultiplier =>
      buildChannels().multiplier(Channel.volatility, softStart: 1.5, power: 0.5);

  // Fire-and-forget haptics that never throw (no platform channel in tests) and
  // honour the user's haptics toggle. Typed by intensity so call sites read
  // clearly: light = taps/buys, medium = unlocks, heavy = prestige/jackpot/crit.
  void _haptic(Future<void> Function() f) {
    if (!hapticsEnabled) return;
    f().catchError((_) {});
  }

  void _hapticLight() => _haptic(HapticFeedback.lightImpact);
  void _hapticMedium() => _haptic(HapticFeedback.mediumImpact);
  void _hapticHeavy() => _haptic(HapticFeedback.heavyImpact);

  /// Claim an unlocked achievement — activates its Notoriety income bonus.
  bool claimAchievement(String id) {
    if (!_achievements.claim(id)) return false;
    _soundService.playUnlock();
    _hapticMedium();
    notifyListeners();
    _saveGame();
    return true;
  }

  /// Claim every claimable achievement at once. Returns how many were claimed.
  int claimAllAchievements() {
    final n = _achievements.claimAll();
    if (n > 0) {
      _soundService.playUnlock();
      _hapticMedium();
      notifyListeners();
      _saveGame();
    }
    return n;
  }

  /// Newly-unlocked achievements awaiting a non-blocking toast (drained by the UI).
  final List<Achievement> pendingAchievementToasts = [];
  void clearAchievementToasts() => pendingAchievementToasts.clear();

  bool soundEnabled = true;
  bool hapticsEnabled = true; // Vibration feedback toggle (see _haptic)
  bool showFiatPrices = false; // Toggle for "Astronomical" Credit prices
  bool onboardingComplete = false; // first-run coach marks shown once

  // Offline Earnings (UI Display)
  double? offlineEarningsAmount;

  Future<void> clearOfflineEarnings() async {
    offlineEarningsAmount = null;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    soundEnabled = !soundEnabled;
    // Bridge the setting to the actual audio player; without this the toggle
    // was purely cosmetic (SoundService.setMuted had no call sites).
    _soundService.setMuted(!soundEnabled);
    await _persistSettings();
    notifyListeners();
  }

  Future<void> toggleHaptics() async {
    hapticsEnabled = !hapticsEnabled;
    if (hapticsEnabled) _hapticLight(); // let the user feel it turn on
    await _persistSettings();
    notifyListeners();
  }

  Future<void> toggleFiatDisplay() async {
    showFiatPrices = !showFiatPrices;
    _soundService.playMine(); // light UI click on the currency toggle
    await _persistSettings();
    notifyListeners();
  }

  Future<void> _persistSettings() => _settingsRepo.saveSettings(
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
        showFiatPrices: showFiatPrices,
        onboardingComplete: onboardingComplete,
      );

  /// Marks the first-run onboarding as seen so it never shows again.
  Future<void> completeOnboarding() async {
    if (onboardingComplete) return;
    onboardingComplete = true;
    await _persistSettings();
    notifyListeners();
  }

  /// A light click for generic UI interactions (e.g. bottom-nav tab switches)
  /// that have no dedicated effect of their own.
  void playUiClick() => _soundService.playMine();

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
    _prestige.reset();
    _classManager.reset(); // full wipe: back to Prospector, no Mastery
    _achievements.reset(); // full wipe clears achievements + Notoriety

    hardForkCount = 0;
    softForkCount = 0;
    newChainCount = 0;
    cratesOpened = 0;
    casinoSpins = 0;
    casinoJackpots = 0;
    pendingAchievementToasts.clear();

    for (var rig in rigs) {
      rig.amount = 0;
    }

    notifyListeners();
  }

  int _autoClickCounter = 0;

  void buyResearch(String researchId) {
    double cost = _researchManager.tryBuy(
      researchId,
      wallet,
      _miningManager.bitcoinExchangeRate,
    );

    if (cost > 0) {
      wallet -= cost;
      _soundService.playUnlock();
      _evaluateAchievements();
      notifyListeners();
      _saveGame();
    }
  }

  bool isResearched(String id) => _researchManager.isResearched(id);

  double getResearchCost(String researchId) {
    var node = _researchManager.researchNodes.firstWhere(
      (r) => r.id == researchId,
      orElse: () => ResearchNode(
        id: '',
        name: '',
        description: '',
        cost: 0,
        icon: Icons.error,
      ),
    );
    if (node.id.isEmpty) return 0;
    return _researchManager.getCostInSats(
      node,
      _miningManager.bitcoinExchangeRate,
    );
  }

  // RPG class + Mastery (Phase 3). Prospector until the first New Blockchain.
  final ClassManager _classManager = ClassManager();
  BtcClass get currentClass => _classManager.current;
  ClassDef get currentClassDef => _classManager.currentDef;
  bool get hasChosenClass => _classManager.hasChosenClass;
  int masteryLevel(BtcClass c) => _classManager.masteryLevel(c);
  double masteryXp(BtcClass c) => _classManager.masteryXp[c] ?? 0;
  int get totalMasteryLevel => _classManager.totalMasteryLevel;

  /// Mastery level of the class currently being played (0 for Prospector).
  int get currentClassMasteryLevel =>
      _classManager.masteryLevel(_classManager.current);

  /// Test seams: set the active class / grant Mastery XP without needing to reach
  /// a New Blockchain first.
  @visibleForTesting
  void debugSelectClass(BtcClass c) => _classManager.select(c);
  @visibleForTesting
  void debugCreditMastery(BtcClass c, double xp) =>
      _classManager.creditMastery(c, xp);

  /// The current class's multiplier on Consensus + GovToken GAIN (1.0 neutral).
  double get classPrestigeGainMultiplier =>
      _classManager.prestigeGainMultiplier;

  // Tier-1 prestige (Soft Fork / Consensus). GovTokens/Hard Fork remain below.
  final PrestigeSystem _prestige = PrestigeSystem();
  int get consensus => _prestige.consensus;
  int get pendingConsensus => _prestige.pendingConsensus(
        lifetimeEarnings,
        gainMultiplier: classPrestigeGainMultiplier,
      );

  /// The Consensus income bonus actually folded into [prestigeMultiplier]
  /// (concave: 0.10*sqrt(consensus)). Exposed so the UI shows the true bonus.
  double get consensusBonus => _prestige.consensusBonus;

  // Tier-3 prestige (New Blockchain / Genesis Blocks). Genesis Blocks multiply
  // the GAIN of the two lower prestige currencies rather than adding raw income.
  int get genesisBlocks => _prestige.genesisBlocks;
  int get pendingGenesis => _prestige.pendingGenesis();
  double get genesisGainMultiplier => _prestige.genesisGainMultiplier;

  /// Gain multiplier the player would have right after a New Blockchain — the
  /// concave projection for the confirmation dialog (mirrors the applied value
  /// so the dialog never overstates the reward).
  double get genesisGainMultiplierAfterNewChain =>
      _prestige.genesisGainMultiplierWith(pendingGenesis);

  /// Cumulative GovTokens ever minted — the progression metric perks unlock
  /// against, so the perk list reveals gradually as the player prestiges.
  double get totalGovTokensEver => _prestige.totalGovTokensEver;

  // Income multiplier from prestige, both CONCAVE so the endgame can't run away:
  // GovTokens contribute 0.50*sqrt(govTokens+spent), Consensus 0.10*sqrt(CX).
  double get prestigeMultiplier =>
      _economy.calculatePrestigeMultiplier(govTokens, spentGovTokens) +
      _prestige.consensusBonus;

  /// Soft Fork: resets LAB only, banks Consensus, starts a new era. Frequent,
  /// low-stakes — no confirmation needed.
  void softFork() {
    if (pendingConsensus <= 0) return;
    _prestige.applySoftFork(
      lifetimeEarnings,
      gainMultiplier: classPrestigeGainMultiplier,
    );
    _researchManager.reset();
    softForkCount++;
    _soundService.playUnlock();
    _hapticHeavy();
    _evaluateAchievements();
    notifyListeners();
    _saveGame();
  }

  // Multiplier the player will have right after a hard fork. The hard-fork
  // dialog previously derived this by hand and dropped spentGovTokens, so it
  // could claim prestiging LOWERS the multiplier.
  double get prestigeMultiplierAfterHardFork => _economy
      .calculatePrestigeMultiplier(govTokens + pendingGovTokens, spentGovTokens);

  // Progress within the CURRENT halving interval (0..1). blocksMined is
  // cumulative and the threshold DOUBLES each halving (15000, 30000, 60000…),
  // so the previous interval start is threshold/2 (or 0 before the first).
  double get halvingProgress {
    final threshold = _miningManager.nextHalvingThreshold;
    final prev =
        threshold <= GameConstants.halvingFirstThreshold ? 0 : threshold ~/ 2;
    final span = threshold - prev;
    if (span <= 0) return 0;
    return ((_miningManager.blocksMined - prev) / span).clamp(0.0, 1.0);
  }

  double get networkDifficulty =>
      _miningManager.calculateNetworkDifficulty(lifetimeEarnings);

  // Chaos/news events — extracted into ChaosEventSystem (lib/logic/systems).
  late final ChaosEventSystem _events;
  double get chaosIncomeMultiplier => _events.incomeMultiplier;
  set chaosIncomeMultiplier(double v) => _events.incomeMultiplier = v;
  double get chaosCostMultiplier => _events.costMultiplier;
  set chaosCostMultiplier(double v) => _events.costMultiplier = v;
  NewsEvent? get currentNews => _events.currentNews;
  set currentNews(NewsEvent? v) => _events.currentNews = v;

  // Anomaly Logic — extracted into AnomalySystem (lib/logic/systems).
  late final AnomalySystem _anomaly;
  bool get isAnomalyActive => _anomaly.active;
  set isAnomalyActive(bool v) => _anomaly.active = v;
  Offset get anomalyPosition => _anomaly.position;
  set anomalyPosition(Offset v) => _anomaly.position = v;

  /// Feed the anomaly spawner the real viewport so anomalies stay on-screen.
  void setAnomalyViewport(double width, double height) =>
      _anomaly.setViewport(width, height);

  Timer? _gameTimer;
  Timer? _autoSaveTimer;

  bool _isDisposed = false;

  // Guards saves so a not-yet-loaded game can never overwrite a real save with
  // a blank default state (load/first-interaction race).
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Lifecycle: whether the game loop should be running, and whether it is.
  bool _autoStartTimers = true;
  bool _timersActive = false;

  // Below this gap (seconds) a resume reconciles income silently; above it we
  // surface the "welcome back" dialog.
  static const int _minAnnounceSeconds = 60;

  @override
  void dispose() {
    _isDisposed = true;
    _stopAllTimers();
    super.dispose();
  }

  GameLogic({
    required GameRepository gameRepository,

    required SettingsRepository settingsRepository,
    required EconomyService economyService,
    required StashService stashService,
    required SoundService soundService,
    bool startTimers = true,
    bool loadOnStart = true,
    Random? casinoRandom,
  }) : _gameRepo = gameRepository,
       _settingsRepo = settingsRepository,
       _economy = economyService,
       _stash = stashService,
       _soundService = soundService,
       _casinoRng = casinoRandom ?? Random() {
    // Initialize Managers
    _miningManager = MiningManager();
    _researchManager = ResearchManager();
    _perkManager = PerkManager();

    _anomaly = AnomalySystem(
      onChanged: notifyListeners,
      onCollect: () {
        chips += 1;
        _soundService.playUnlock();
        _evaluateAchievements();
        _saveGame();
      },
      luckFactor: () => luckMultiplier,
    );

    _events = ChaosEventSystem(
      onChanged: notifyListeners,
      onHackLoss: () {
        final loss = wallet * 0.15;
        wallet -= loss;
        return loss;
      },
      onEventSound: (good) =>
          good ? _soundService.playEventGood() : _soundService.playEventBad(),
      volatilityFactor: () => volatilityMultiplier,
    );

    _autoStartTimers = startTimers;

    if (loadOnStart) {
      loadGame().then((_) {
        if (_isDisposed) return;
        if (_autoStartTimers) _startAllTimers();
      });
    }
  }

  // Starts every game timer exactly once. Idempotent so pause/resume and the
  // initial load cannot double-start the loop.
  void _startAllTimers() {
    if (_timersActive || _isDisposed) return;
    _startGameLoop();
    _events.start();
    _anomaly.start();
    _timersActive = true;
  }

  void _stopAllTimers() {
    _gameTimer?.cancel();
    _autoSaveTimer?.cancel();
    _events.stop();
    _anomaly.stop();
    _timersActive = false;
  }

  // ---- App lifecycle ------------------------------------------------------
  // Wired from HomeScreen's WidgetsBindingObserver. Without this the game
  // simply froze in the background: the periodic timer stopped firing and no
  // offline reconciliation ran, so backgrounded time earned nothing.

  Future<void> onAppPaused() async {
    _stopAllTimers();
    if (_isLoaded) {
      // Persists last_save_time = now, so resume/cold-start can measure the gap.
      await _saveGame();
    }
  }

  Future<void> onAppResumed() async {
    // Only reconcile offline earnings if a real pause actually stopped the
    // timers. An inactive->resumed cycle (Control Center / notification shade /
    // incoming-call banner / permission dialog / app-switcher preview) never
    // fires onAppPaused, so the live 1s timer kept crediting income the whole
    // time — running the offline sim then would double-count that window.
    final bool wasPaused = !_timersActive;
    if (wasPaused && _isLoaded) {
      final lastSaveTime = await _gameRepo.readLastSaveTime();
      if (lastSaveTime != null) {
        final elapsed =
            (DateTime.now().millisecondsSinceEpoch - lastSaveTime) ~/ 1000;
        if (elapsed > 0) {
          _simulateOfflineMining(
            elapsed,
            announce: elapsed >= _minAnnounceSeconds,
          );
        }
      }
    }
    if (_autoStartTimers) _startAllTimers();
    notifyListeners();
  }

  /// Test seam: simulate whether the game timers are currently running, to
  /// exercise the inactive->resumed (no real pause) branch of [onAppResumed].
  @visibleForTesting
  set debugTimersActive(bool v) => _timersActive = v;

  // Spawns anomalies randomly
  void clickAnomaly() => _anomaly.collect();

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _mine();
    });

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveGame();
      debugPrint('Auto-Saved Game');
    });
  }

  /// Aggregates all channel bonuses (research + perks + stash) into one place —
  /// the single source of truth for the economy's multipliers (channel model).
  Channels buildChannels() {
    final ch = Channels();
    _researchManager.contributeChannels(ch);
    _perkManager.contributeChannels(ch);
    _stash.contributeChannels(ch);
    _classManager.contributeChannels(ch); // class weightings + permanent Mastery
    return ch;
  }

  double get globalHashRate {
    return _economy.calculateGlobalHashRate(
      rigs,
      _researchManager.isResearched(ResearchIds.chipFab),
      buildChannels().multiplier(
        Channel.hash,
        softStart: GameConstants.hashSoftStart,
        power: GameConstants.channelSoftPower,
      ),
    );
  }

  // Fractional block accumulator, shared by the live tick and offline catch-up.
  double _blockCarry = 0;

  /// Applies [seconds] of passive mining at the CURRENT hash rate and returns
  /// the income earned. Single source of truth for both the 1-second live tick
  /// and the chunked offline catch-up so the two can never diverge.
  double _accrueMining(double seconds, {required double chaosMultiplier}) {
    final hashRate = globalHashRate;
    if (hashRate <= 0) return 0;
    final perSecond = _miningManager.calculateMiningIncome(
      hashRate: hashRate,
      difficulty: networkDifficulty,
      prestigeMultiplier: prestigeMultiplier,
      chaosMultiplier: chaosMultiplier,
      lifetimeEarnings: lifetimeEarnings,
      incomeMultiplier: buildChannels().multiplier(
            Channel.income,
            softStart: GameConstants.incomeSoftStart,
            power: GameConstants.channelSoftPower,
          ) *
          notorietyMultiplier,
    );
    double income = perSecond * seconds;
    final room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) return 0;
    if (income > room) income = room;
    wallet += income;
    lifetimeEarnings += income;
    return income;
  }

  /// Advances the block counter by [seconds] (1 second == 1 block), carrying the
  /// fraction. Returns true if a halving occurred.
  bool _advanceBlocks(double seconds) {
    _blockCarry += seconds;
    final whole = _blockCarry.floor();
    if (whole <= 0) return false;
    _miningManager.blocksMined += whole;
    _blockCarry -= whole;
    return _miningManager.checkHalving();
  }

  void _mine() {
    // Auto Clicker
    if (_researchManager.isResearched(ResearchIds.aiManager)) {
      _autoClickCounter++;
      if (_autoClickCounter >= 5) {
        clickMine(playSound: false);
        _autoClickCounter = 0;
      }
    }

    if (globalHashRate <= 0) return;
    _accrueMining(1, chaosMultiplier: chaosIncomeMultiplier);
    if (_advanceBlocks(1)) {
      _triggerHalving();
      _soundService.playHalving();
      _hapticHeavy();
    }
    _evaluateAchievements();
    notifyListeners();
  }

  /// Test-only: advance [seconds] of real passive mining (full channel model +
  /// income multiplier + halving) without the 1-second timer. Lets the economy
  /// simulation drive the REAL accrual path — including research/perk/stash
  /// bonuses — in fast chunks. Returns income earned.
  @visibleForTesting
  double advanceForTest(double seconds) {
    final earned = _accrueMining(seconds, chaosMultiplier: 1.0);
    if (_advanceBlocks(seconds)) _triggerHalving();
    return earned;
  }

  // ---- Achievements ------------------------------------------------------

  /// Halvings survived THIS era, derived from the current block reward
  /// (reward = initial / 2^n), so no extra counter is needed.
  int get eraHalvings {
    final r = _miningManager.blockReward;
    if (r <= 0 || r >= GameConstants.initialBlockReward) return 0;
    return (log(GameConstants.initialBlockReward / r) / ln2).round().clamp(0, 64);
  }

  AchStats _buildAchStats() {
    int totalRigs = 0;
    int typesOwned = 0;
    for (final r in rigs) {
      totalRigs += r.amount;
      if (r.amount > 0) typesOwned++;
    }
    return AchStats(
      lifetimeEarnings: lifetimeEarnings,
      totalGovTokensEver: totalGovTokensEver,
      govTokens: govTokens,
      consensus: consensus,
      genesisBlocks: genesisBlocks,
      totalRigs: totalRigs,
      rigTypesOwned: typesOwned,
      rigTypesTotal: rigs.length,
      researchCompleted: researchNodes.where((n) => n.isCompleted).length,
      researchTotal: researchNodes.length,
      perkLevels: perks.values.fold(0, (a, b) => a + b),
      stashDiscovered: _stash.ownedArtifacts.length,
      stashTotal: StashService.allArtifacts.length,
      chips: chips,
      hardForkCount: hardForkCount,
      softForkCount: softForkCount,
      newChainCount: newChainCount,
      cratesOpened: cratesOpened,
      casinoSpins: casinoSpins,
      casinoJackpots: casinoJackpots,
      eraHalvings: eraHalvings,
      globalHashRate: globalHashRate,
      prestigeMultiplier: prestigeMultiplier,
      achievementsUnlocked: _achievements.unlockedCount,
      ownsArtifact: (id) => _stash.ownedArtifacts.containsKey(id),
    );
  }

  /// Evaluate achievements; queue toasts + save on any new unlock. Cheap enough
  /// to run every tick and after each discrete action.
  void _evaluateAchievements() {
    final newly = _achievements.evaluate(_buildAchStats());
    if (newly.isNotEmpty) {
      pendingAchievementToasts.addAll(newly);
      _soundService.playUnlock();
      _saveGame();
    }
  }

  void _triggerHalving() {
    // Routed through the event system's news banner (which auto-expires and
    // does NOT touch the chaos multiplier timer).
    _events.showNews(
      NewsEvent(
        message: "BITCOIN HALVING: Block Reward Cut in Half!",
        type: EventType.info,
        durationSeconds: 15,
        color: Colors.purpleAccent,
        value: -50,
      ),
    );
  }

  // Base GovToken accrual, scaled by the tier-3 Genesis gain multiplier (1.0
  // until the player has Genesis Blocks, so early play is unaffected) AND the
  // current class's prestige-gain multiplier (BTC OG boosts, Corporation
  // reduces). Both are applied to the raw root inside the economy service so
  // partial token progress is preserved, matching how Consensus (tier-1) scales.
  int get pendingGovTokens => _economy.calculatePendingGovTokens(
    lifetimeEarnings,
    gainMultiplier:
        _prestige.genesisGainMultiplier * classPrestigeGainMultiplier,
  );

  // Injectable so tests can force a crit / no-crit deterministically.
  Random _clickRng = Random();
  @visibleForTesting
  set clickRng(Random r) => _clickRng = r;

  /// Result of a single [clickMine] tap, for the UI (float text + juice).
  ClickResult clickMine({bool playSound = true}) {
    final ch = buildChannels();
    double clickPower = _economy.calculateClickPower(_perkManager.perks);
    clickPower *= _stash.getClickPowerMultiplier();
    clickPower *= ch.multiplier(
      // CLICK channel (perks/etc.), soft-capped past a generous threshold.
      Channel.click,
      softStart: GameConstants.clickSoftStart,
      power: GameConstants.channelSoftPower,
    );

    double diff = networkDifficulty;

    double clickSats = _miningManager.calculateMiningIncome(
      hashRate: clickPower,
      difficulty: diff,
      prestigeMultiplier: prestigeMultiplier,
      chaosMultiplier: chaosIncomeMultiplier,
      lifetimeEarnings: lifetimeEarnings,
      incomeMultiplier: ch.multiplier(
            Channel.income,
            softStart: GameConstants.incomeSoftStart,
            power: GameConstants.channelSoftPower,
          ) *
          notorietyMultiplier,
    );

    // Critical tap: rare multiplied payout (game feel). Only a *real* tap can
    // crit — the silent auto-clicker never rolls, so it can't secretly pump.
    // Luck scales the crit chance up to a hard cap.
    final double critChance = (GameConstants.clickCritChance *
            ch.multiplier(Channel.luck, softStart: 1.5, power: 0.5))
        .clamp(0.0, GameConstants.clickCritChanceCap);
    final bool isCrit = playSound && _clickRng.nextDouble() < critChance;
    if (isCrit) clickSats *= GameConstants.clickCritMultiplier;

    // Re-clamp to the per-era supply cap AFTER the crit multiply (mirrors
    // _accrueMining) so a crit near the cap can't push lifetimeEarnings over
    // maxSupplySats and flip networkDifficulty to Infinity.
    final double room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) {
      clickSats = 0;
    } else if (clickSats > room) {
      clickSats = room;
    }

    lifetimeEarnings += clickSats;
    wallet += clickSats;
    // Only a real tap makes the click sound; the AI auto-clicker stays silent
    // so it doesn't emit a click every 5 seconds on its own.
    if (playSound) {
      _soundService.playMine();
      if (isCrit) _hapticHeavy();
    }

    _evaluateAchievements();
    notifyListeners();
    return ClickResult(clickSats, isCrit);
  }

  double get estimatedClickValue {
    final ch = buildChannels();
    double clickPower =
        _economy.calculateClickPower(_perkManager.perks) *
        _stash.getClickPowerMultiplier() *
        ch.multiplier(
          Channel.click,
          softStart: GameConstants.clickSoftStart,
          power: GameConstants.channelSoftPower,
        );

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
      incomeMultiplier: ch.multiplier(
            Channel.income,
            softStart: GameConstants.incomeSoftStart,
            power: GameConstants.channelSoftPower,
          ) *
          notorietyMultiplier,
    );
  }

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    _soundService.playHalving(); // dramatic cue for the prestige reset
    _hapticHeavy();

    govTokens += tokensToClaim;
    // Feed tier-3 progress: every GovToken ever minted counts toward the next
    // New Blockchain / Genesis Block.
    _prestige.recordGovTokensMinted(tokensToClaim);
    // Exchange rate is neutralised (was: *= (1 + tokensToClaim), which overflowed
    // to Infinity late-game). Cross-era power is the prestige income multiplier,
    // which rises because govTokens rose.

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

    // Consensus is an era currency wiped by a Hard Fork.
    _prestige.onHardFork();

    hardForkCount++;
    _evaluateAchievements();
    _saveGame();
    notifyListeners();
  }

  /// New Blockchain (Tier-3): the deepest reset. Wipes the entire run —
  /// currency, GovTokens, chips, rigs, research, perks, Consensus and mining
  /// state — and keeps ONLY the permanent Stash collection plus the banked
  /// Genesis Blocks. Rare and high-stakes, so the UI gates it behind a
  /// confirmation dialog. Genesis Blocks permanently multiply future Consensus
  /// and GovToken gains.
  /// [chosenClass] is the class to play the NEXT chain as (the picker's choice).
  /// When null the current class carries over (used by sims/tests). Mastery for
  /// the chain just finished is credited to the class it was played as BEFORE the
  /// wipe, since the chain-GovToken baseline is reset by [applyNewBlockchain].
  void newBlockchain({BtcClass? chosenClass}) {
    if (pendingGenesis <= 0) return;

    _soundService.playHalving(); // dramatic cue for the deepest reset
    _hapticHeavy();

    // Credit Mastery to the class this chain was played as (GovTokens minted this
    // chain), BEFORE the baseline snapshot below zeroes the chain counter.
    _classManager.creditMastery(_classManager.current, _prestige.chainGovTokens());

    // Bank Genesis Blocks, snapshot the chain baseline, wipe Consensus.
    _prestige.applyNewBlockchain();

    // Lock in the class for the new chain (if the player picked one).
    if (chosenClass != null) _classManager.select(chosenClass);

    // Wipe the run. Stash artifacts are deliberately preserved (permanent
    // collection); Genesis Blocks were just banked above.
    wallet = 0;
    lifetimeEarnings = 0;
    govTokens = 0;
    spentGovTokens = 0;
    chips = 0;
    _miningManager.hardForkReset();
    for (var rig in rigs) {
      rig.amount = 0;
    }
    _researchManager.reset();
    _perkManager.reset();

    newChainCount++;
    _evaluateAchievements();
    _saveGame();
    notifyListeners();
  }

  void buyRig(String rigId) => buyRigMax(rigId, 1);

  /// Buys up to [maxCount] units of a rig, stopping early when the wallet can no
  /// longer afford the next (each unit costs 15% more than the last). Batches the
  /// sound/notify/save so holding-to-buy 100 units is one update, not 100.
  /// Returns how many were actually bought (0 if none were affordable).
  int buyRigMax(String rigId, int maxCount) {
    if (maxCount <= 0) return 0;
    final int index = rigs.indexWhere((r) => r.id == rigId);
    if (index == -1) return 0;
    final Rig rig = rigs[index];

    int bought = 0;
    while (bought < maxCount) {
      final double costSats = getRigCostInSats(rig);
      if (wallet < costSats) break;
      wallet -= costSats;
      rig.amount++;
      bought++;
    }

    if (bought > 0) {
      _soundService.playBuy();
      _hapticLight();
      _evaluateAchievements();
      notifyListeners();
      _saveGame();
    }
    return bought;
  }

  double getRigCostInCredits(Rig rig) {
    // Total rig-cost discount (perks + cooling/solar research + stash) comes
    // from the RIG_COST channel; calculateRigCost applies the 95% hard cap.
    return _economy.calculateRigCost(
      rig,
      buildChannels().sum(Channel.rigCost),
      chaosCostMultiplier,
    );
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
      _soundService.playUnlock();
      _evaluateAchievements();
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
      _soundService.playBuy();
      _evaluateAchievements();
      notifyListeners();
      _saveGame();
    }
  }

  /// Opens a crate and returns the artifact won (null if unaffordable), so the
  /// UI can show a reveal of exactly what dropped.
  Artifact? buyCrate(bool isPremium) {
    int cost = isPremium ? 50 : 10;
    if (chips < cost) return null;
    chips -= cost;
    final won = _stash.openCrate(isPremium: isPremium);
    cratesOpened++;
    _soundService.playUnlock();
    _evaluateAchievements();
    notifyListeners();
    _saveGame();
    return won;
  }

  // PERSISTENCE
  Future<void> _saveGame() async {
    // Never persist before the initial load finishes, or a corrupt/slow load
    // would let a blank default state clobber the real save on disk.
    if (!_isLoaded) return;
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
      consensus: _prestige.consensus,
      lifetimeAtLastSoftFork: _prestige.lifetimeAtLastSoftFork,
      genesisBlocks: _prestige.genesisBlocks,
      totalGovTokensEver: _prestige.totalGovTokensEver,
      govTokensEverAtLastNewChain: _prestige.govTokensEverAtLastNewChain,
      achievements: _achievements.save(),
      claimedAchievements: _achievements.saveClaimed(),
      hardForkCount: hardForkCount,
      softForkCount: softForkCount,
      newChainCount: newChainCount,
      cratesOpened: cratesOpened,
      casinoSpins: casinoSpins,
      casinoJackpots: casinoJackpots,
      currentClass: _classManager.current.name,
      mastery: _classManager.masteryJson(),
    );
  }

  Future<void> loadGame() async {
    try {
      final settings = await _settingsRepo.loadSettings();
      soundEnabled = settings['sound_enabled'] ?? true;
      hapticsEnabled = settings['haptics_enabled'] ?? true;
      showFiatPrices = settings['show_fiat_prices'] ?? false;
      onboardingComplete = settings['onboarding_complete'] ?? false;
      _soundService.setMuted(!soundEnabled);

      final data = await _gameRepo.loadGameState();

      // Numeric fields are coerced defensively: JSON does not distinguish int
      // from double, so a whole-number double round-trips as an int and a raw
      // assignment would throw "int is not a subtype of double".
      wallet = _toDouble(data['wallet']);
      lifetimeEarnings = _toDouble(data['lifetimeEarnings']);
      govTokens = _toInt(data['govTokens']);
      spentGovTokens = _toInt(data['spentGovTokens']);
      chips = _toInt(data['chips']);

      if (data.containsKey('stash') && data['stash'] != null) {
        _stash.loadStash(Map<String, dynamic>.from(data['stash']));
      }

      // Load Mining Manager Data
      _miningManager.blockReward = _toDouble(data['blockReward']);
      _miningManager.blocksMined = _toInt(data['blocksMined']);
      _miningManager.nextHalvingThreshold = _toInt(data['nextHalvingThreshold']);
      // Migration: force the (now neutralised) exchange rate to 1.0, ignoring any
      // large value saved by the old compounding mechanic.
      _miningManager.bitcoinExchangeRate = 1.0;

      // Prestige tier-1 (Soft Fork / Consensus)
      _prestige.consensus = _toInt(data['consensus']);
      _prestige.lifetimeAtLastSoftFork = _toDouble(
        data['lifetimeAtLastSoftFork'],
      );

      // Prestige tier-3 (New Blockchain / Genesis Blocks). The repository seeds
      // totalGovTokensEver from current tokens for saves predating the field.
      _prestige.genesisBlocks = _toInt(data['genesisBlocks']);
      _prestige.totalGovTokensEver = _toDouble(data['totalGovTokensEver']);
      _prestige.govTokensEverAtLastNewChain = _toDouble(
        data['govTokensEverAtLastNewChain'],
      );

      // RPG class + permanent Mastery (persist across all prestige tiers; only a
      // full wipe clears them). Tolerant of missing/unknown values (falls back to
      // Prospector / 0 XP for saves predating Phase 3).
      _classManager.loadFrom(data['currentClass'], data['mastery']);

      // Achievements + action counters (persist across all prestige tiers).
      hardForkCount = _toInt(data['hardForkCount']);
      softForkCount = _toInt(data['softForkCount']);
      newChainCount = _toInt(data['newChainCount']);
      cratesOpened = _toInt(data['cratesOpened']);
      casinoSpins = _toInt(data['casinoSpins']);
      casinoJackpots = _toInt(data['casinoJackpots']);
      if (data['achievements'] is List) {
        _achievements.load(
          (data['achievements'] as List).map((e) => e.toString()),
        );
      }
      if (data['claimedAchievements'] is List) {
        _achievements.loadClaimed(
          (data['claimedAchievements'] as List).map((e) => e.toString()),
        );
      } else if (data['achievements'] is List) {
        // Pre-claim save: everything already unlocked was auto-granted under the
        // old system, so treat it as claimed — no Notoriety income is lost.
        _achievements.claimAllUnlockedForMigration();
      }

      // Load Perk Manager Data
      if (data.containsKey('perks')) {
        _perkManager.perks.addAll(
          Map<String, dynamic>.from(data['perks']).map(
            (k, v) => MapEntry(k, _toInt(v)),
          ),
        );
      }
      if (data.containsKey('perkCosts')) {
        _perkManager.perkCosts.addAll(
          Map<String, dynamic>.from(data['perkCosts']).map(
            (k, v) => MapEntry(k, _toInt(v)),
          ),
        );
      }

      // Load Rigs (Still local)
      if (data.containsKey('rigs')) {
        final List<dynamic> decoded = data['rigs'];
        for (var jsonItem in decoded) {
          final id = jsonItem['id'];
          final amount = _toInt(jsonItem['amount']);
          final index = rigs.indexWhere((r) => r.id == id);
          if (index != -1) rigs[index].amount = amount;
        }
      }

      // Load Research Manager Data
      if (data.containsKey('research')) {
        final List<dynamic> decoded = data['research'];
        for (var jsonItem in decoded) {
          final id = jsonItem['id'];
          final isUnlocked = jsonItem['isUnlocked'] ?? false;
          final isCompleted = jsonItem['isCompleted'] ?? false;
          final index = _researchManager.researchNodes.indexWhere(
            (r) => r.id == id,
          );
          if (index != -1) {
            _researchManager.researchNodes[index].isUnlocked = isUnlocked;
            _researchManager.researchNodes[index].isCompleted = isCompleted;
          }
        }
      }
      // Unlock any node whose prerequisites are already completed — covers nodes
      // added by a content update after this save was written (else they stay
      // stuck as "???" and the LAB soft-locks).
      _researchManager.refreshUnlocks();

      // The load has succeeded far enough to be authoritative; saves are now
      // safe to persist (and the offline sim below relies on this).
      _isLoaded = true;

      // Migration — MUST run before the offline sim below: it recovers
      // spentGovTokens from purchased perks for legacy saves, which feeds the
      // prestige multiplier. Running it after the offline sim would accrue the
      // one-time offline payout with an understated multiplier (under-credit).
      if (spentGovTokens == 0 && _perkManager.perks.values.any((v) => v > 0)) {
        spentGovTokens = _economy.recalculateSpentTokens(_perkManager.perks);
        // The tier-3 "ever minted" accumulator must be at least what the player
        // currently holds + has spent. The repository seed for legacy saves runs
        // BEFORE this recompute, so top it up here rather than stranding the
        // recovered spend below the tier-3 baseline.
        final minEver = (govTokens + spentGovTokens).toDouble();
        if (_prestige.totalGovTokensEver < minEver) {
          _prestige.totalGovTokensEver = minEver;
        }
        _saveGame();
      }

      // Offline Earnings — reads the ORIGINAL loaded timestamp (the migration's
      // _saveGame above writes to disk, not to this local `data` map), and now
      // accrues with the migrated prestige multiplier.
      final lastSaveTime = data['last_save_time'];
      if (lastSaveTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final diffSeconds = (now - lastSaveTime) ~/ 1000;

        if (diffSeconds > 10) {
          _simulateOfflineMining(diffSeconds);
        }
      }

      // Grandfather achievements already satisfied by the loaded state: unlock
      // them SILENTLY (no toast flood) so returning players and newly-added
      // achievements don't spam notifications on launch.
      final grandfathered = _achievements.evaluate(_buildAchStats());
      if (grandfathered.isNotEmpty) _saveGame();
    } catch (e, st) {
      // A failed load must not brick the game: log, keep the in-code defaults,
      // and still mark the game loaded so timers start and play can continue.
      debugPrint('GameLogic.loadGame failed, using defaults: $e\n$st');
    } finally {
      _isLoaded = true;
    }

    notifyListeners();
  }

  static double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
  static int _toInt(dynamic v) => v is num ? v.toInt() : 0;

  void _simulateOfflineMining(int totalSeconds, {bool announce = true}) {
    if (totalSeconds <= 0) return;
    if (totalSeconds > 31536000) totalSeconds = 31536000; // 1-year cap
    if (globalHashRate <= 0) return;

    // Chunk long absences to bound the loop; income AND blocks both scale by
    // timePerTick through the SAME accrual helpers the live tick uses, so the
    // offline path can't drift from online play.
    double timePerTick = 1.0;
    int iterations = totalSeconds;
    if (totalSeconds > 5000) {
      iterations = 5000;
      timePerTick = totalSeconds / 5000.0;
    }

    double accrued = 0;
    for (int i = 0; i < iterations; i++) {
      accrued += _accrueMining(timePerTick, chaosMultiplier: 1.0); // no chaos offline
      _advanceBlocks(timePerTick);
      if (lifetimeEarnings >= GameConstants.maxSupplySats) break;
    }

    if (accrued > 0) {
      if (announce) offlineEarningsAmount = accrued;
      _saveGame();
    }
  }
}
