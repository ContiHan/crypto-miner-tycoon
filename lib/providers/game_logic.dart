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
import '../logic/systems/ability_system.dart';
import '../logic/systems/proc_system.dart';
import '../logic/systems/aura_system.dart';
import '../logic/systems/keystone_system.dart';
import '../logic/systems/firmware_system.dart';
import '../logic/systems/breach_system.dart';
import '../logic/systems/speed_run_system.dart';
import '../logic/systems/rig_reveal_system.dart';
import '../logic/systems/casino_manager.dart';
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

/// A one-shot "a proc just fired" signal for a transient MINE-tab float. Procs
/// fire on the tick (not on a tap), so the UI can't learn about them from a
/// return value — it listens to [GameLogic.procFeedback] instead. A fresh
/// instance is pushed each fire so two identical labels still notify.
class ProcFeedback {
  final String label; // the proc/firmware affix name that fired
  final ProcEffectKind kind; // what it granted (for colour/icon)
  const ProcFeedback(this.label, this.kind);
}

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;

  // --- Endgame (THE LAST SATOSHI) ---
  // Cosmetic cumulative sats mined across ALL eras/chains; NEVER reset by any
  // prestige (only a full Wipe Save clears it). Purely a lifetime stat now — the
  // win is per-era (lifetimeEarnings reaching the 21M cap), not cumulative.
  double lifetimeEverSats = 0;
  // Persisted once-only win latch: set the first time a single era mines a full
  // 21M supply (lifetimeEarnings >= maxSupplySats). Gates Back in Time + credits.
  bool hasWonGame = false;
  // Transient (NOT persisted): drives the one-shot THE LAST SATOSHI overlay,
  // drained by clearWinCelebration() — mirrors offlineEarningsAmount so a
  // relaunch never replays the ending.
  bool pendingWinCelebration = false;

  // --- Speed Run (Genesis Sprint) ---
  // An optional timed challenge: from a deep (New-Blockchain-style) reset that
  // keeps your permanent progression (Genesis Blocks, Mastery, achievements /
  // Notoriety, Stash), race to mine one full 21M-BTC supply (maxSupplySats) as
  // fast as possible. The clock is WALL-CLOCK (persisted start timestamp) so
  // backgrounding/closing the app can't pause or cheat it.
  // Back-in-Time Speed Run state + record-keeping (extracted subsystem). The
  // public API below is preserved as thin proxies so the UI + tests are unchanged.
  final SpeedRunSystem _speedRun = SpeedRunSystem(
      nowMs: () => DateTime.now().millisecondsSinceEpoch);

  bool get speedRunActive => _speedRun.active;
  int get speedRunStartMs => _speedRun.startMs;
  set speedRunStartMs(int v) => _speedRun.startMs = v; // test seam
  double get speedRunMinedSats => _speedRun.minedSats;
  int get speedRunBestMs => _speedRun.bestMs;
  int get speedRunLastMs => _speedRun.lastMs;
  Map<String, int> get speedRunBestByClass => _speedRun.bestByClass;
  set speedRunBestByClass(Map<String, int> v) => _speedRun.bestByClass = v; // test seam
  bool get pendingSpeedRunCelebration => _speedRun.pendingCelebration;

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

  /// BLUEPRINTS: permanent re-tech count for a TECH node (0 if never researched).
  int blueprintCount(String id) => _researchManager.researchCount[id] ?? 0;
  Map<String, int> get perks => _perkManager.perks;
  Map<String, int> get perkCosts => _perkManager.perkCosts;

  // Data-driven PERKS UI: the screen iterates these defs and reveals each perk
  // once its unlock threshold (totalGovTokensEver) is reached.
  Map<String, PerkDef> get perkDefs => PerkManager.defs;
  bool isPerkUnlocked(String id) =>
      _perkManager.isAvailable(id, _classManager.current);
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

  /// Cosmetic conversion of a sat value into the "astronomical fiat" display
  /// used by the $/₿ toggle. Purely visual — no gameplay effect.
  double toFiat(double sats) => sats * GameConstants.cosmeticUsdPerSat;

  // Runtime rigs are built from the data-driven catalog (lib/content/rig_defs).
  List<Rig> rigs = createRigs();

  /// Progressive rig reveal (milestone unlocks) — extracted subsystem. Reads live
  /// counters via suppliers; GameLogic keeps thin proxies for the public API.
  late final RigRevealSystem _rigReveal = RigRevealSystem(
    rigs: () => rigs,
    cratesOpened: () => cratesOpened,
    casinoSpins: () => casinoSpins,
    globalHashRate: () => globalHashRate,
  );

  /// Lifetime count of market events witnessed (owned by the reveal system;
  /// incremented in the ChaosEventSystem.onEventSound hook). Kept settable for
  /// tests.
  int get eventsSeen => _rigReveal.eventsSeen;
  set eventsSeen(int v) => _rigReveal.eventsSeen = v;

  /// The locked-rig teaser hint (with live progress) for the next rig.
  String rigUnlockHint(String id) => _rigReveal.hint(id);

  /// Rigs the player should currently SEE (start with the first; reveal in order).
  List<Rig> get visibleRigs => _rigReveal.visibleRigs;

  /// The next still-locked rig (a "???" teaser), or null if all revealed.
  Rig? get nextLockedRig => _rigReveal.nextLockedRig;

  int govTokens = 0;
  int chips = 0;
  int spentGovTokens = 0; // Track spent tokens

  // Lifetime action counters (for achievements; persisted, never reset by prestige).
  int hardForkCount = 0;
  int softForkCount = 0;
  int newChainCount = 0;
  int cratesOpened = 0;

  // --- Progressive disclosure (Phase: locked nav tabs) ---
  // Bottom-nav tabs reveal gradually so a new player isn't shown everything at
  // once. STICKY: once a tab unlocks it stays unlocked forever (a New Blockchain
  // wiping rigs must not re-lock TECH). MINE + GOAL are always available.
  bool unlockedTech = false; // after the first rig
  bool unlockedStash = false; // after some earnings / a chip / a crate
  bool unlockedSkill = false; // after the first Hard Fork (first GovTokens)
  bool unlockedGoal = false; // after the first achievement is earned
  /// Tab names newly unlocked this session, drained by the UI for a toast.
  final List<String> pendingTabUnlockToasts = [];
  void clearTabUnlockToasts() => pendingTabUnlockToasts.clear();

  // SIMULATED "SWEEP" minigame (in-game UTXO only). Player-favoured (EV>1),
  // bounded by a per-real-time-window net-gain cap. `chips` IS the persisted UTXO
  // (kept here — the crate shop spends it too). The SWEEP economy (window cap +
  // resolve/commit split) lives in CasinoManager; GameLogic keeps thin proxies so
  // the STASH screen + casino_test are unchanged.
  final Random _casinoRng; // injectable so tests can force deterministic spins
  late final CasinoManager _casinoManager = CasinoManager(
    rng: _casinoRng,
    chips: () => chips,
    setChips: (v) => chips = v,
    sweepLuck: () => sweepLuckMultiplier,
    onWinSound: () => _soundService.playCoin(),
    onWinHaptic: _hapticLight,
    onJackpotHaptic: _hapticHeavy,
    evaluateAchievements: _evaluateAchievements,
    save: _saveGame,
    notify: notifyListeners,
  );

  // Persisted SWEEP counters (owned by the manager; proxied for achievements, the
  // rig-reveal supplier, and serialization).
  int get casinoSpins => _casinoManager.spins;
  int get casinoJackpots => _casinoManager.jackpots;

  /// Net UTXO gained in the CURRENT window (0 once it has elapsed). Pure read.
  double get casinoNetThisWindow => _casinoManager.netThisWindow;

  /// True when the per-window net-gain cap is reached — sweeps are blocked until
  /// the window resets. Pure read (no mutation), safe to call during build.
  bool get casinoCapped => _casinoManager.capped;

  /// Milliseconds until the current window resets (0 if none open / already up).
  int get casinoWindowResetInMs => _casinoManager.windowResetInMs;

  // The raw window accumulators — proxied get/set (persisted; casino_test drives
  // them directly to simulate a capped / expired window).
  double get casinoWindowNet => _casinoManager.windowNet;
  set casinoWindowNet(double v) => _casinoManager.windowNet = v;
  int get casinoWindowStartMs => _casinoManager.windowStartMs;
  set casinoWindowStartMs(int v) => _casinoManager.windowStartMs = v;

  /// Bet [bet] UTXO on the slots (one-shot). Null if unaffordable or capped.
  SlotSpin? playSlots(int bet) => _casinoManager.playSlots(bet);

  /// Deduct the stake and roll a slots spin WITHOUT committing it (see
  /// [commitSweep]). Null if unaffordable or the per-window cap blocks play.
  SlotSpin? resolveSlots(int bet) => _casinoManager.resolveSlots(bet);

  /// Hash Flip on [bet] UTXO — the high-variance game (mostly busts, rare 30x
  /// jackpot), one-shot. Null if unaffordable or capped.
  FlipResult? playDoubleOrNothing(int bet) =>
      _casinoManager.playDoubleOrNothing(bet);

  /// Deduct the stake and roll a Hash Flip WITHOUT committing it (see
  /// [commitSweep]). Null if unaffordable or the per-window cap blocks play.
  FlipResult? resolveFlip(int bet) => _casinoManager.resolveFlip(bet);

  /// Relay a packet for [bet] UTXO (one-shot). Null if unaffordable or capped.
  PlinkoDrop? playPlinko(int bet) => _casinoManager.playPlinko(bet);

  /// Deduct the stake and roll a relay drop WITHOUT committing it (see
  /// [commitSweep]). Null if unaffordable or the per-window cap blocks play.
  PlinkoDrop? resolvePlinko(int bet) => _casinoManager.resolvePlinko(bet);

  /// Commit a RESOLVED sweep outcome (see [CasinoManager.commit]). [silent] skips
  /// the reveal feedback + notify (teardown/backgrounding); currency still commits
  /// exactly once and persists.
  void commitSweep(SweepOutcome outcome, {bool silent = false}) =>
      _casinoManager.commit(outcome, silent: silent);

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

  /// Aggregate (shared) Luck factor (>=1, softcapped). Kept for the STASH readout;
  /// the three effect sites use the decoupled facet getters below.
  double get luckMultiplier =>
      buildChannels().multiplier(Channel.luck, softStart: 1.5, power: 0.5);

  /// Combined luck for one facet: shared `luck` + the facet's own sources, run
  /// through the luck softcap. Shared luck (classes/perks) lifts all three facets;
  /// facet sources (TECH/TALENT/STASH) let a build specialise crit / SWEEP /
  /// anomaly luck independently (the "luck decouple").
  /// LUCKY NONCE temp luck ×N while active (foreground only), 1.0 otherwise.
  double get abilityLuckBuff =>
      _inOfflineSim ? 1.0 : _abilities.luckBuffMult(_nowMs());

  /// True while an ability grants crash-immunity (STEADY HANDS / CONSENSUS RALLY),
  /// foreground only. Drives the chaos suppress-negatives steering and the bar's
  /// shield indicator.
  bool get abilityCrashImmune =>
      !_inOfflineSim && _abilities.anyActive(_nowMs(), (d) => d.suppressNegatives);

  double _combinedLuck(Channel facet) {
    final ch = buildChannels();
    final raw = 1 + ch.sum(Channel.luck) + ch.sum(facet);
    // DEGENERATE GAMBLER ×2 / ASIC MONOCULTURE ×0.4 — keystone luck lever, and
    // LUCKY NONCE's temp luck buff — both applied outside the softcap so they can
    // genuinely swing crit chance / loot / SWEEP odds.
    return softcap(raw < 0.01 ? 0.01 : raw, 1.5, 0.5) *
        keystoneMods.luckMult *
        abilityLuckBuff;
  }

  /// NONCE PRECISION — luck applied to crit CHANCE (clamped to the 25% cap).
  double get critLuckMultiplier => _combinedLuck(Channel.nonce);

  /// WHALE'S FAVOR — luck applied to SWEEP payouts (bounded by the EV ceiling;
  /// the 400/24h net cap is immutable and never touched here). POOL LUCK pins it
  /// to the EV ceiling while active: a huge value that CasinoService.effectiveLuck
  /// clamps to the ceiling factor (so realized SWEEP return sits at the cap).
  double get sweepLuckMultiplier {
    if (!_inOfflineSim && _abilities.anyActive(_nowMs(), (d) => d.luckPinSweep)) {
      return double.maxFinite;
    }
    return _combinedLuck(Channel.sweepLuck);
  }

  /// UTXO MAGNETISM — luck applied to anomaly spawn chance (clamped to 30%/tick).
  double get anomalyLuckMultiplier => _combinedLuck(Channel.magnetism);

  /// IDLE CAPACITY — the offline-accrual WINDOW in seconds. Base 8h + `idle`
  /// sources (in hours), hard-capped at 24h (#16). A longer absence still only
  /// banks this many hours of offline mining.
  double get idleCapacitySeconds {
    // COLD-WALLET DISCIPLINE ×2 (or Sweat Equity ×0.5) scales the window, but the
    // 24h FINAL cap still binds (#16).
    final hours = ((GameConstants.offlineWindowBaseHours +
                buildChannels().sum(Channel.idle)) *
            keystoneMods.idleMult)
        .clamp(0.0, GameConstants.offlineWindowMaxHours);
    return hours * 3600.0;
  }

  // --- Resistances (Phase 2) ---------------------------------------------
  // Each resistance is a `[0, per-lever cap]` value summed from its channel, then
  // scaled by any keystone resist lever (FORT KNOX ×1.3 toward the cap / MARKET
  // MAKER ×0.5), still clamped to its per-lever cap so the ≤0.70 rail holds.
  double _resist(Channel ch, double cap) =>
      (buildChannels().sum(ch) * keystoneMods.resistMult).clamp(0.0, cap);
  double get crashResistance =>
      _resist(Channel.crashResist, GameConstants.resistCapMagnitude);
  double get costResistance =>
      _resist(Channel.costResist, GameConstants.resistCapMagnitude);
  double get halvingResistance =>
      _resist(Channel.halvingResist, GameConstants.resistCapHalving);
  double get durationResistance =>
      _resist(Channel.durationResist, GameConstants.resistCapDuration);
  double get theftResistance =>
      _resist(Channel.theftResist, GameConstants.resistCapMagnitude);

  /// THE POWER BILL: the fraction of GROSS income skimmed before it reaches the
  /// spendable wallet (0..upkeepCap). Scales with the OWNED fleet's load, reduced
  /// by Fee Hedge, nudged by class, and swung by the energy chaos events. Only the
  /// wallet is affected — lifetime/supply/Mastery always credit the gross.
  double get upkeepRate {
    // FURNACE FARM pins upkeep to the cap (Fee Hedge/Efficiency do nothing).
    if (keystoneMods.upkeepPinned) return GameConstants.upkeepCap;
    double load = 0;
    for (var i = 0; i < rigs.length; i++) {
      load += rigs[i].amount * (i + 1); // tierWeight = ladder position
    }
    double raw = GameConstants.upkeepCap *
        (1 - 1 / (1 + load / GameConstants.upkeepK));
    // Fee Hedge (and future Energy Efficiency) reduce it.
    raw *= (1 - costResistance.clamp(0.0, GameConstants.upkeepReductionCap));
    // Class nudge.
    if (currentClass == BtcClass.corporation) {
      raw *= GameConstants.upkeepClassCorp;
    } else if (currentClass == BtcClass.poolMember ||
        currentClass == BtcClass.soloMiner) {
      raw *= GameConstants.upkeepClassLean;
    }
    // Energy chaos events swing it (cheap energy softens, cost spike bites twice).
    if (chaosCostMultiplier < 0.999) {
      raw *= GameConstants.cheapEnergyUpkeepFactor;
    } else if (chaosCostMultiplier > 1.001) {
      raw *= GameConstants.costSpikeUpkeepFactor;
    }
    return raw.clamp(0.0, GameConstants.upkeepCap);
  }

  /// Spendable fraction of gross income (1 − upkeep), shown as "NET x%".
  double get netIncomeFraction => 1.0 - upkeepRate;

  // --- THE BREACH (theft, Phase 5) — state machine extracted to BreachSystem ---
  late final BreachSystem _breach = BreachSystem(
    onChanged: notifyListeners,
    onSave: _saveGame,
    playThreatCue: () {
      _soundService.playEventBad();
      _hapticHeavy();
    },
    // COLD MINER treats a breach as a negative event it's simply immune to; the
    // telegraph is a foreground-only event (never while offline).
    blocked: () => _inOfflineSim || keystoneMods.immuneNegatives,
    // Steals the HOT WALLET ONLY, scaled by the tier (DUST ×0.3 / BREACH ×1.0 /
    // 51% ×2.5): FORT KNOX ×0.2 / JUNKYARD RIGS ×1.5 also apply. Lifetime/supply/
    // GovTokens/Consensus/Genesis/Mastery/Stash/chips are NEVER touched. A 51%
    // attack also leaves a brief bounded market dip.
    applyLoss: () {
      final loss = wallet *
          GameConstants.breachBaseLoss *
          _breach.tier.lossMult *
          (1 - theftResistance) *
          keystoneMods.breachLossMult;
      if (loss > 0) {
        wallet -= loss;
        _fireProcs(ProcEvent.onBreach); // firmware "insurance" hooks
        if (_breach.tier == BreachTier.fiftyOne) {
          _events.forceMarketDip(); // the 51% aftermath (never stacks a real crash)
        }
      }
      return loss;
    },
    nowMs: _nowMs,
    // Cold Storage buys reaction time: up to +breachTelegraphBonusMaxSec at the
    // 0.70 theft-resist cap.
    extraTelegraphSeconds: () =>
        (theftResistance / GameConstants.resistCapMagnitude *
                GameConstants.breachTelegraphBonusMaxSec)
            .round(),
  );

  /// True while a breach threat is telegraphing (the SECURE window is open).
  bool get breachPending => _breach.pending;
  double get lastBreachLoss => _breach.lastLoss;

  /// The telegraphing breach's tier label (DUST / SECURITY BREACH / 51% ATTACK).
  String get breachTierLabel => _breach.tier.label;

  /// Seconds left in the SECURE window (0 when none pending).
  int get breachSecondsRemaining => _breach.secondsRemaining();

  void _startBreachThreat() => _breach.startThreat();
  void resolveBreach({required bool secured}) => _breach.resolve(secured: secured);

  /// Player tapped SECURE within the telegraph window — vault the wallet (0 loss).
  void secureBreach() => _breach.secure();

  /// Test seam: begin a breach threat without waiting for the random chaos roll.
  /// Forces [tier] (default the normal BREACH) and bypasses the frequency floor so
  /// tests are deterministic.
  @visibleForTesting
  void debugStartBreach({BreachTier tier = BreachTier.breach}) {
    _breach.clearFrequencyFloor();
    _breach.startThreat();
    _breach.tier = tier;
  }

  /// Applies this run's resistances to a chaos event (thin wrapper over the pure
  /// [applyEventResistances] using the live channel-derived resistance values).
  (double, double, int) resistEvent(
      EventType type, double income, double cost, int duration) {
    // Keystone steering happens FIRST (COLD MINER immunity/suppression, MARKET
    // MAKER ±50% amplification), THEN the normal resistance mitigation.
    final s = _steerEventByKeystones(type, income, cost, duration);
    return applyEventResistances(type, s.$1, s.$2, s.$3,
        crashR: crashResistance,
        costR: costResistance,
        durR: durationResistance);
  }

  /// Folds the equipped keystones' chaos levers into a raw (income, cost, duration)
  /// event tuple. COLD MINER nullifies negatives / suppresses positives; MARKET
  /// MAKER deepens both a crash's drop and a bull's boost by ±50%.
  (double, double, int) _steerEventByKeystones(
      EventType type, double income, double cost, int duration) {
    final k = keystoneMods;
    switch (type) {
      case EventType.marketCrash:
        if (k.immuneNegatives) return (1.0, cost, duration);
        return (1.0 - (1.0 - income) * k.chaosNegativeMult, cost, duration);
      case EventType.costSpike:
        if (k.immuneNegatives) return (income, 1.0, duration);
        return (income, 1.0 + (cost - 1.0) * k.chaosNegativeMult, duration);
      case EventType.bullRun:
        if (k.suppressPositives) return (1.0, cost, duration);
        return (1.0 + (income - 1.0) * k.chaosPositiveMult, cost, duration);
      case EventType.cheapEnergy:
        if (k.suppressPositives) return (income, 1.0, duration);
        return (income, 1.0 - (1.0 - cost) * k.chaosPositiveMult, duration);
      case EventType.airdrop:
      case EventType.hack:
      case EventType.info:
        return (income, cost, duration); // handled at their own callbacks
    }
  }

  /// Pure, testable resistance math. DIAMOND HANDS softens a market crash's
  /// magnitude; FEE HEDGE softens a cost spike's surcharge; STEEL NERVES shortens
  /// their DURATION (never hack/breach). The AUTHORITATIVE combined cap (#8) keeps
  /// magnitude×duration mitigation ≤ combinedResistCap per event, so a crash/spike
  /// always lands at ≥ 30% of its base impact.
  static (double, double, int) applyEventResistances(
      EventType type, double income, double cost, int duration,
      {required double crashR, required double costR, required double durR}) {
    final double minProduct = 1.0 - GameConstants.combinedResistCap; // 0.30
    if (type == EventType.marketCrash && income < 1.0) {
      final double remainMag = 1.0 - crashR;
      double remainDur = 1.0 - durR;
      if (remainMag * remainDur < minProduct) {
        remainDur = (minProduct / remainMag).clamp(0.0, 1.0);
      }
      final double drop = 1.0 - income; // e.g. 0.50
      return (1.0 - drop * remainMag, cost, (duration * remainDur).round());
    }
    if (type == EventType.costSpike && cost > 1.0) {
      final double remainSur = 1.0 - costR;
      double remainDur = 1.0 - durR;
      if (remainSur * remainDur < minProduct) {
        remainDur = (minProduct / remainSur).clamp(0.0, 1.0);
      }
      final double surcharge = cost - 1.0; // e.g. 0.50
      return (income, 1.0 + surcharge * remainSur, (duration * remainDur).round());
    }
    return (income, cost, duration); // hack/airdrop/bull/cheap-energy untouched
  }

  /// Aggregate Volatility factor (1.0 with no sources) — scales chaos-event
  /// frequency. Sources arrive with classes (Pool lowers it, others raise it).
  double get volatilityMultiplier =>
      buildChannels().multiplier(Channel.volatility, softStart: 1.5, power: 0.5);

  /// BULL BIAS attribute — tilts chaos-event selection toward positives (never
  /// zeroes negatives). Summed from Channel.bullBias, capped.
  double get bullBiasStrength =>
      buildChannels().sum(Channel.bullBias).clamp(0.0, GameConstants.bullBiasCap);

  /// OVERCHARGE attribute — scales active ability BUFF magnitude and grant-seconds
  /// (NOT durations/cooldowns). 1.0 with no sources; +overchargeCap (0.50) at most.
  double get overchargeFactor =>
      1.0 +
      buildChannels().sum(Channel.overcharge).clamp(0.0, GameConstants.overchargeCap);

  /// Amplifies an ability temp multiplier's BONUS by [overchargeFactor]
  /// (a neutral 1.0 buff stays 1.0).
  double _overcharged(double abilityMult) =>
      abilityMult <= 1.0 ? abilityMult : 1.0 + (abilityMult - 1.0) * overchargeFactor;

  /// OFFLINE YIELD fraction: the share of the live per-second rate earned while
  /// the app is closed. Base 0.70 + additive `offline` sources (TECH/class/etc.),
  /// hard-capped at 1.0 so offline can never out-earn active play.
  double get offlineFraction {
    // LOW TIME PREFERENCE / COLD-WALLET DISCIPLINE force full offline parity.
    if (keystoneMods.offlineForceParity) return GameConstants.offlineFractionCap;
    return (GameConstants.offlineBaseFraction +
            buildChannels().sum(Channel.offline))
        .clamp(0.0, GameConstants.offlineFractionCap);
  }

  /// BLOCK REWARD: the crit PAYOUT multiplier. Base 5x, raised (concavely) by the
  /// `special` channel and hard-capped at critPayoutMax so stacked crit-power can
  /// never produce an absurd per-tap payout (#11). With no sources it is exactly
  /// the base 5x.
  double get critPayoutMultiplier => ((GameConstants.clickCritMultiplier +
              GameConstants.clickCritPayoutSpecialScale *
                  softcap(buildChannels().sum(Channel.special), 1.0, 0.5)) *
          keystoneMods.critPayoutMult) // LASER EYES ×2
      .clamp(0.0, GameConstants.critPayoutMax);

  /// PROSPECTOR'S EYE: the per-crate-roll chance to bump the rolled rarity up one
  /// step. Additive `fortune` sources, hard-capped at fortuneMaxTierShiftChance
  /// (#22) so loot can never be dominated (and never a guaranteed top rarity).
  double get fortuneBonus => buildChannels()
      .sum(Channel.fortune)
      .clamp(0.0, GameConstants.fortuneMaxTierShiftChance);

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
    _soundService.playCoin(); // collecting a reward
    _hapticMedium();
    notifyListeners();
    _saveGame();
    return true;
  }

  /// Claim every claimable achievement at once. Returns how many were claimed.
  int claimAllAchievements() {
    final n = _achievements.claimAll();
    if (n > 0) {
      _soundService.playCoin(); // collecting rewards
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
  // Per-screen first-visit tips already dismissed (e.g. 'tab_skill'). Persisted
  // in settings like [onboardingComplete] so each screen's intro shows only once.
  final Set<String> _seenTips = {};
  bool hasSeenTip(String id) => _seenTips.contains(id);

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
    _soundService.playClick(); // light UI click on the currency toggle
    await _persistSettings();
    notifyListeners();
  }

  Future<void> _persistSettings() => _settingsRepo.saveSettings(
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
        showFiatPrices: showFiatPrices,
        onboardingComplete: onboardingComplete,
        seenTips: _seenTips.toList(),
      );

  /// Marks the first-run onboarding as seen so it never shows again.
  Future<void> completeOnboarding() async {
    if (onboardingComplete) return;
    onboardingComplete = true;
    await _persistSettings();
    notifyListeners();
  }

  /// Marks a per-screen first-visit tip [id] as seen so it never shows again.
  Future<void> markTipSeen(String id) async {
    if (!_seenTips.add(id)) return; // already seen — no write, no rebuild
    await _persistSettings();
    notifyListeners();
  }

  /// A light click for generic UI interactions (e.g. bottom-nav tab switches)
  /// that have no dedicated effect of their own.
  void playUiClick() => _soundService.playClick();

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
    _respecUsed = false; // fresh save → the free respec refreshes
    _researchManager.wipeBlueprints(); // full wipe ONLY: clears permanent blueprints
    _researchManager.wipePresets(); // full wipe ONLY: clears saved TECH presets
    _abilities.wipeCooldowns(); // full wipe ONLY: clears ability cooldowns + buffs
    _procs.clear(); // clears proc ICDs + active buffs
    _auras.reset(); // full wipe: unequip stance + auras
    _keystones.reset(); // full wipe: unequip keystones
    _firmware.reset(); // full wipe: clear the firmware loadout
    _miningManager.reset();
    _prestige.reset();
    _classManager.reset(); // full wipe: back to Prospector, no Mastery
    _achievements.reset(); // full wipe clears achievements + Notoriety

    hardForkCount = 0;
    softForkCount = 0;
    newChainCount = 0;
    cratesOpened = 0;
    _casinoManager.reset();
    // Endgame spine — cleared ONLY by a full Wipe Save (never by any prestige).
    lifetimeEverSats = 0;
    hasWonGame = false;
    _breach.reset(); // fresh save → the next breach is a drill again
    pendingWinCelebration = false;
    // Progressive-disclosure tabs re-lock on a full wipe (fresh-start feel).
    unlockedTech = false;
    unlockedStash = false;
    unlockedSkill = false;
    unlockedGoal = false;
    pendingTabUnlockToasts.clear();
    pendingAchievementToasts.clear();

    for (var rig in rigs) {
      rig.amount = 0;
    }
    _rigReveal.resetAndSnapshot(); // re-progress rig reveals from the first rig

    notifyListeners();
  }

  int _autoClickCounter = 0;
  int _critStreak = 0; // consecutive real crit taps → onCritStreak proc hook

  void buyResearch(String researchId) {
    double cost = _researchManager.tryBuy(
      researchId,
      wallet,
    );

    if (cost > 0) {
      wallet -= cost;
      _soundService.playResearch();
      _evaluateAchievements();
      notifyListeners();
      _saveGame();
    }
  }

  bool isResearched(String id) => _researchManager.isResearched(id);

  // ---- TECH doctrines (Phase 3) -----------------------------------------
  Doctrine researchDoctrine(String id) => _researchManager.doctrineOf(id);
  bool isResearchDoctrineLocked(String id) =>
      _researchManager.isDoctrineLocked(id);
  int get committedDoctrinePairs => _researchManager.committedPairCount();
  Set<Doctrine> committedDoctrines() => _researchManager.committedDoctrines();
  static const int doctrineCommitmentBudget = ResearchManager.commitmentBudget;

  // ---- One free respec per run (BUILD_DEPTH) ----------------------------
  // Clears the TECH tree (uncommitting doctrines) once per era, so a mis-committed
  // doctrine can be re-picked WITHOUT waiting for a fork. Blueprints (the permanent
  // re-tech discount) survive, so re-teching is cheaper. Refreshed by every fork
  // (which resets research anyway).
  bool _respecUsed = false;

  /// True when the one-per-era respec is available (something is completed to clear).
  bool get respecAvailable =>
      !_respecUsed && researchNodes.any((n) => n.isCompleted);

  /// True once the free respec has been spent this era (UI shows a dim hint).
  bool get respecSpent => _respecUsed;

  /// Spend the free respec: clear the TECH tree + uncommit doctrines. No-op if
  /// already used this era or nothing is completed.
  void respecTech() {
    if (!respecAvailable) return;
    _researchManager.reset(); // clears completed nodes + re-locks (keeps blueprints)
    _respecUsed = true;
    _soundService.playPrestige();
    _hapticHeavy();
    notifyListeners();
    _saveGame();
  }

  // ---- Keystones (Phase 8) ----------------------------------------------
  final KeystoneSystem _keystones = KeystoneSystem();

  /// The aggregate modifier of the equipped keystones (neutral when none). Cached
  /// per access — it folds a Set of <=2, cheap.
  KeystoneModifiers get keystoneMods => _keystones.aggregate();

  List<KeystoneDef> availableKeystones() =>
      _keystones.availableOrEquipped(committedDoctrines());
  bool isKeystoneEquipped(String id) => _keystones.isEquipped(id);
  int get equippedKeystoneCount => _keystones.equipped.length;

  void toggleKeystone(String id) {
    _keystones.toggle(id, committedDoctrines());
    notifyListeners();
    _saveGame();
  }

  // ---- Rig Firmware (Phase 6 / Slice 7b) --------------------------------
  final FirmwareSystem _firmware = FirmwareSystem();

  /// True once a CO-PROCESSOR keystone is equipped (8 sockets at −40% chance).
  /// No such keystone ships yet, so this is currently always false (the capability
  /// is wired and dormant).
  bool get _hasCoProcessor => false;

  /// Live Rig Firmware socket count: base 3 + Firmware Bay (META node) + current-
  /// class Mastery 2 + 2 committed doctrine pairs, capped at 6 — or 8 under a
  /// CO-PROCESSOR keystone.
  int get firmwareCapacity {
    final bonus = (_researchManager.isResearched(ResearchIds.firmwareBay) ? 1 : 0) +
        (currentClassMasteryLevel >= 2 ? 1 : 0) +
        (committedDoctrinePairs >= 2 ? 1 : 0);
    return FirmwareSystem.capacity(
        bonusSlots: bonus, coProcessor: _hasCoProcessor);
  }

  List<FirmwareAffix> availableFirmware() => kFirmwareAffixes;
  bool isFirmwareEquipped(String id) => _firmware.isEquipped(id);
  int get equippedFirmwareCount => _firmware.equipped.length;
  List<String> get equippedFirmware => List.unmodifiable(_firmware.equipped);

  void toggleFirmware(String id) {
    _firmware.toggle(id, firmwareCapacity);
    notifyListeners();
    _saveGame();
  }

  // ---- TECH presets (Phase 3 QoL) ---------------------------------------
  List<TechPreset> get techPresets => _researchManager.presets;
  int get activeTechPreset => _researchManager.activePreset;
  bool get autoApplyPresets => _researchManager.autoApplyPresets;

  /// Snapshot the current TECH build into a preset (auto-named), cap 3.
  void saveTechPreset() {
    final p = _researchManager.savePreset();
    if (p == null) return;
    notifyListeners();
    _saveGame();
  }

  void renameTechPreset(int index, String name) {
    _researchManager.renamePreset(index, name);
    notifyListeners();
    _saveGame();
  }

  /// Overwrite an existing preset slot with the current TECH build (re-named).
  /// Lets the player update ANY slot, not only append a new one. Returns true if
  /// it overwrote (false = out of range or nothing researched to save).
  bool overwriteTechPreset(int index) {
    final p = _researchManager.overwritePreset(index);
    if (p == null) return false;
    notifyListeners();
    _saveGame();
    return true;
  }

  /// Delete a preset slot.
  void deleteTechPreset(int index) {
    _researchManager.deletePreset(index);
    notifyListeners();
    _saveGame();
  }

  void setAutoApplyPresets(bool value) {
    _researchManager.autoApplyPresets = value;
    notifyListeners();
    _saveGame();
  }

  /// One-tap re-tech: makes [index] the active preset and buys toward it as far
  /// as the wallet allows (dependency-ordered). Returns how many nodes bought.
  int applyTechPreset(int index) {
    if (index < 0 || index >= _researchManager.presets.length) return 0;
    _researchManager.activePreset = index;
    final bought = _rebuildFromPreset(_researchManager.presets[index]);
    notifyListeners();
    _saveGame();
    return bought;
  }

  /// Buys every affordable, unlocked, still-incomplete node in [preset], cheapest
  /// first, repeating until a full pass buys nothing (so deeper nodes unlock as
  /// their prereqs complete). Batches one save/notify (unlike per-node buyResearch).
  int _rebuildFromPreset(TechPreset preset) {
    int bought = 0;
    final ids = preset.nodeIds.toList()
      ..sort((a, b) => getResearchCost(a).compareTo(getResearchCost(b)));
    bool progress = true;
    while (progress) {
      progress = false;
      for (final id in ids) {
        final cost = _researchManager.tryBuy(id, wallet);
        if (cost > 0) {
          wallet -= cost;
          bought++;
          progress = true;
        }
      }
    }
    return bought;
  }

  // Auto-apply spends real (blueprint-discounted) BTC re-teching after a fork —
  // it's just tiny vs. a built-up wallet, so it looks free. We accumulate the
  // spend across the (possibly multi-tick) rebuild and flush it once the batch
  // settles, so the UI can flash a "RE-TECH · −X" toast that makes the cost
  // visible without changing the economy.
  double _retechSpendAccum = 0;
  double _pendingRetechSpend = 0;

  /// BTC the last settled auto-apply batch spent (0 = nothing to show). The UI
  /// drains it with [clearReTechToast] after toasting it.
  double get pendingReTechSpend => _pendingRetechSpend;
  void clearReTechToast() => _pendingRetechSpend = 0;

  void _flushRetechSpend() {
    if (_retechSpendAccum <= 0) return;
    _pendingRetechSpend += _retechSpendAccum; // += so an undrained batch isn't lost
    _retechSpendAccum = 0;
  }

  /// AUTO-APPLY: on the tick / after a reset, rebuild the active preset as income
  /// allows (owner: default ON, opt-out). Fast-exits once the build is complete.
  void _maybeAutoApplyPreset() {
    if (!_researchManager.autoApplyPresets) return _flushRetechSpend();
    final i = _researchManager.activePreset;
    if (i < 0 || i >= _researchManager.presets.length) return _flushRetechSpend();
    final preset = _researchManager.presets[i];
    final anyIncomplete = preset.nodeIds.any((id) {
      final n = _researchManager.researchNodes
          .firstWhere((r) => r.id == id, orElse: () => ResearchNode(id: ''));
      return n.id.isNotEmpty && !n.isCompleted;
    });
    if (!anyIncomplete) return _flushRetechSpend();
    final before = wallet;
    if (_rebuildFromPreset(preset) > 0) {
      _retechSpendAccum += (before - wallet); // BTC spent this tick
      notifyListeners();
      _saveGame();
    } else {
      _flushRetechSpend(); // couldn't afford more this tick — the batch settled
    }
  }

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
    return _researchManager.getCostInSats(node);
  }

  // RPG class + Mastery (Phase 3). Prospector until the first New Blockchain.
  final ClassManager _classManager = ClassManager();
  BtcClass get currentClass => _classManager.current;
  ClassDef get currentClassDef => _classManager.currentDef;
  bool get hasChosenClass => _classManager.hasChosenClass;
  int masteryLevel(BtcClass c) => _classManager.masteryLevel(c);
  double masteryXp(BtcClass c) => _classManager.masteryXp[c] ?? 0;
  int get totalMasteryLevel => _classManager.totalMasteryLevel;
  int get masteredClassCount => _classManager.masteredCount;
  int classMasteryLevelByName(String name) =>
      _classManager.masteryLevelByName(name);

  /// Mastery level of the class currently being played (0 for Prospector).
  int get currentClassMasteryLevel =>
      _classManager.masteryLevel(_classManager.current);

  // --- Abilities (Phase 4) -------------------------------------------------
  final AbilitySystem _abilities = AbilitySystem();
  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// RIG COOLING (Haste/CDR): fraction shaved off ability cooldowns, capped.
  double get abilityHaste =>
      buildChannels().sum(Channel.haste).clamp(0.0, GameConstants.hasteCap);

  List<AbilityDef> get currentClassAbilities =>
      _abilities.abilitiesFor(_classManager.current);
  bool isAbilityUnlocked(AbilityDef def) =>
      _abilities.isUnlocked(def, _classManager.current, currentClassMasteryLevel);
  bool isAbilityReady(AbilityDef def) =>
      _abilities.isReady(def, _nowMs(), abilityHaste);
  int abilityCooldownRemainingMs(AbilityDef def) =>
      _abilities.cooldownRemainingMs(def, _nowMs(), abilityHaste);

  /// Full (haste-adjusted) cooldown of an ability — the denominator for the bar's
  /// radial cooldown sweep.
  int abilityEffectiveCooldownMs(AbilityDef def) =>
      _abilities.effectiveCooldownMs(def, abilityHaste);

  /// Currently-active ability buffs with remaining ms (bar ticker chips).
  List<({AbilityDef def, int remainingMs})> activeAbilityBuffs() =>
      _abilities.activeBuffs(_nowMs());

  /// Fires an ability by id. No-op (returns false) if not the owning class, not
  /// unlocked, or still on cooldown. Buffs are foreground-only.
  bool castAbility(String id) {
    final def = _abilities.byId(id);
    if (def == null) return false;
    if (!isAbilityUnlocked(def)) return false;
    if (!isAbilityReady(def)) return false;
    final now = _nowMs();
    _abilities.activate(def, now);

    // Instant bespoke effects.
    if (def.forceBullRun) _events.forceBullRun(); // OG WHALE ORDER
    if (def.freeCrate) {
      _stash.openCrate(tier: CrateTier.standard, fortune: fortuneBonus);
      cratesOpened++;
      _soundService.playCrate();
    }
    if (def.spawnAnomalies > 0) _anomaly.forceSpawn(def.spawnAnomalies); // LUCKY NONCE
    // Crash-immunity turning on also CLEARS any in-progress crash/spike.
    if (def.suppressNegatives) _events.clearActiveNegative();

    // Instant income lump (Corp): snapshot the live per-second rate and bank it,
    // supply-clamped. Credits wallet + lifetime only (never speedRunMinedSats).
    if (def.instantIncomeSeconds > 0) {
      final perSec = _baseIncomePerSecond();
      // OVERCHARGE lengthens the banked grant-seconds (magnitude, not duration).
      double lump = perSec * def.instantIncomeSeconds * overchargeFactor;
      final room = GameConstants.maxSupplySats - lifetimeEarnings;
      if (room > 0) {
        if (lump > room) lump = room;
        wallet += lump;
        lifetimeEarnings += lump;
        _creditLifetimeEver(lump);
      }
    }
    _soundService.playUnlock();
    _hapticHeavy();
    _fireProcs(ProcEvent.onAbilityCast);
    notifyListeners();
    _saveGame();
    return true;
  }

  /// The current per-second passive income at the BASE rate (no ability temp
  /// buffs) — used to size instant lumps so a lump can't compound a buff.
  double _baseIncomePerSecond() {
    final hashRate = _baseGlobalHashRate();
    if (hashRate <= 0) return 0;
    return _miningManager.calculateMiningIncome(
      hashRate: hashRate,
      difficulty: networkDifficulty,
      prestigeMultiplier: prestigeMultiplier,
      chaosMultiplier: 1.0,
      lifetimeEarnings: lifetimeEarnings,
      incomeMultiplier: buildChannels().multiplier(Channel.income,
              softStart: GameConstants.incomeSoftStart,
              power: GameConstants.channelSoftPower) *
          notorietyMultiplier,
      halvingResist: halvingResistance,
    );
  }

  /// Outside-softcap temp income multiplier from active ability buffs, foreground
  /// only (offline sim excludes it). Capped as part of the aggregate ceiling.
  // --- Procs / triggers (Phase 6) ----------------------------------------
  final ProcSystem _procs = ProcSystem();

  /// One-shot signal that a proc fired, for the MINE-tab float (F-D). The UI
  /// listens; a fresh [ProcFeedback] is pushed per proc so repeats still notify.
  final ValueNotifier<ProcFeedback?> procFeedback =
      ValueNotifier<ProcFeedback?>(null);

  /// Roll the proc engine for [event] and apply whatever fires. FOREGROUND-ONLY
  /// (never rolls in the offline sim); [synthetic] events (proc-produced or an
  /// auto-tap) fire nothing (GOLDEN RULE). GRANTs are wallet/UTXO only (never
  /// touch lifetime/supply/prestige — safe by construction); BUFFs feed the
  /// merged temp axis (see the temp*Mult getters).
  // Per-window UTXO cap (#25): rolling real-time budget of proc/anomaly chips.
  int _utxoWindowStartMs = 0;
  int _utxoWindowGranted = 0;

  /// Grants up to [want] chips, bounded by the per-window UTXO cap so procs +
  /// forced anomalies can't farm UTXO. Returns the amount actually granted.
  int _grantUtxoCapped(int want) {
    if (want <= 0) return 0;
    final now = _nowMs();
    if (now - _utxoWindowStartMs >= GameConstants.procUtxoWindowMs) {
      _utxoWindowStartMs = now;
      _utxoWindowGranted = 0;
    }
    final room = GameConstants.procUtxoWindowCap - _utxoWindowGranted;
    if (room <= 0) return 0;
    final grant = want < room ? want : room;
    chips += grant;
    _utxoWindowGranted += grant;
    return grant;
  }

  void _fireProcs(ProcEvent event, {bool synthetic = false}) {
    if (_inOfflineSim) return;
    final results = _procs.roll(event,
        currentClass: _classManager.current,
        synthetic: synthetic,
        nowMs: _nowMs(),
        rng: _clickRng,
        extraSignals: _firmware.equippedSignals(
            coProcessor: _hasCoProcessor, cap: firmwareCapacity));
    if (results.isEmpty) return;
    for (final r in results) {
      switch (r.signal.kind) {
        case ProcEffectKind.grantSats:
          // Spendable-only bonus: wallet, not lifetime → can't touch the win.
          wallet += _baseIncomePerSecond() * r.signal.magnitude;
          break;
        case ProcEffectKind.grantUtxo:
          _grantUtxoCapped(r.signal.magnitude.toInt());
          break;
        case ProcEffectKind.grantCrateRoll:
          // A free STANDARD crate — a bonus roll, still a chip SINK (#25).
          _stash.openCrate(tier: CrateTier.standard, fortune: fortuneBonus);
          cratesOpened++;
          break;
        case ProcEffectKind.grantAnomaly:
          // Spawns collectables; their chips route through the capped grant.
          _anomaly.forceSpawn(r.signal.magnitude.toInt());
          break;
        case ProcEffectKind.grantCdRefund:
          _abilities.refundCooldowns(
              r.signal.magnitude.clamp(0.0, GameConstants.procCdRefundMax),
              _nowMs(),
              abilityHaste);
          break;
        case ProcEffectKind.buff:
          break; // applied live via _procs.tempMult in the temp getters
      }
      // Surface the fire so the player can SEE the (otherwise silent) proc —
      // the MINE tab floats a brief "⚡ <name>" (F-D). Skip in the offline sim.
      if (!_inOfflineSim) {
        procFeedback.value = ProcFeedback(r.signal.name, r.signal.kind);
      }
    }
  }

  // OVERCHARGE amplifies the ability buff's magnitude (its bonus above 1.0), not
  // the proc buff; the aggregate temp ceiling (#10) still clamps the product.
  double get abilityIncomeMult => _inOfflineSim
      ? 1.0
      : _overcharged(_abilities.tempMult(Channel.income, _nowMs())) *
          _procs.tempMult(Channel.income, _nowMs());
  double get abilityHashMult => _inOfflineSim
      ? 1.0
      : _overcharged(_abilities.tempMult(Channel.hash, _nowMs())) *
          _procs.tempMult(Channel.hash, _nowMs());
  double get abilityClickMult => _inOfflineSim
      ? 1.0
      : _overcharged(_abilities.tempMult(Channel.click, _nowMs())) *
          _procs.tempMult(Channel.click, _nowMs());

  /// Combined live income temp lane (chaos market × ability buffs) clamped to the
  /// aggregate income ceiling (#10). Debuffs below 1 (a crash) pass through.
  double _liveIncomeTempMult() {
    final p = chaosIncomeMultiplier * abilityIncomeMult;
    return p > GameConstants.incomeTempMax ? GameConstants.incomeTempMax : p;
  }

  /// Pick the active class from the SKILL tab. Available as the FIRST choice as
  /// soon as SKILL unlocks (the first Hard Fork), so the player doesn't wait for
  /// a far-off New Blockchain. But the choice is a COMMITMENT: once a real class
  /// is picked you are LOCKED to it for the whole run and can only re-pick at a
  /// New Blockchain (through that flow's class picker). So this is a no-op after
  /// the first real choice — mid-chain switching is deliberately not allowed.
  void chooseClass(BtcClass c) {
    if (hasChosenClass) return; // locked until the next New Blockchain
    if (_classManager.current == c) return;
    _classManager.select(c);
    _evaluateAchievements(); // may satisfy class_first once a class is played
    _saveGame();
    notifyListeners();
  }

  /// Test seams: set the active class / grant Mastery XP without needing to reach
  /// a New Blockchain first.
  @visibleForTesting
  void debugSelectClass(BtcClass c) => _classManager.select(c);
  @visibleForTesting
  void debugUnlockAllTabs() {
    unlockedTech = unlockedStash = unlockedSkill = unlockedGoal = true;
    notifyListeners();
  }
  @visibleForTesting
  void debugCreditMastery(BtcClass c, double xp) =>
      _classManager.creditMastery(c, xp);

  /// The current class's multiplier on Consensus + GovToken GAIN (1.0 neutral).
  double get classPrestigeGainMultiplier =>
      _classManager.prestigeGainMultiplier;

  /// CONSENSUS WEIGHT: a buildable multiplier on prestige gain from the `prestige`
  /// channel (softcapped, params pinned 1.0/0.5). 1.0 with no sources.
  double get consensusWeightMultiplier =>
      buildChannels().multiplier(Channel.prestige, softStart: 1.0, power: 0.5);

  /// Total multiplier applied to Consensus + GovToken gain: the class scalar ×
  /// CONSENSUS WEIGHT × any active DEEP FREEZE buff, clamped at prestigeGainMax so
  /// the prestige feedback loop can never diverge (#17). (The NG+ trophy
  /// multiplier was retired with the endgame pivot.)
  double get prestigeGainMultiplier =>
      (classPrestigeGainMultiplier *
              consensusWeightMultiplier *
              keystoneMods.prestigeGainMult * // LOW TIME PREFERENCE ×1.5
              (_inOfflineSim ? 1.0 : _abilities.activePrestigeGainMult(_nowMs())))
          .clamp(0.0, GameConstants.prestigeGainMax);

  // Tier-1 prestige (Soft Fork / Consensus). GovTokens/Hard Fork remain below.
  final PrestigeSystem _prestige = PrestigeSystem();
  int get consensus => _prestige.consensus;
  int get pendingConsensus => _prestige.pendingConsensus(
        lifetimeEarnings,
        gainMultiplier: prestigeGainMultiplier,
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
      gainMultiplier: prestigeGainMultiplier,
    );
    _researchManager.reset();
    _respecUsed = false; // fresh era → the free respec refreshes
    softForkCount++;
    _soundService.playPrestige();
    _hapticHeavy();
    _fireProcs(ProcEvent.onSoftFork); // COLD-tier firmware hooks
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
    procFeedback.dispose();
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
        _grantUtxoCapped(1); // routes through the per-window UTXO cap (#25)
        _soundService.playCoin();
        _evaluateAchievements();
        _saveGame();
      },
      luckFactor: () => anomalyLuckMultiplier,
    );

    _events = ChaosEventSystem(
      onChanged: notifyListeners,
      onBreach: _startBreachThreat, // THE BREACH: telegraphed hot-wallet theft
      onAirdropGain: () {
        // COLD MINER suppresses the airdrop entirely; MARKET MAKER swells it +50%.
        final k = keystoneMods;
        if (k.suppressPositives) return 0.0;
        final gain = wallet * 0.15 * k.chaosPositiveMult; // opposite of the hack
        wallet += gain;
        return gain;
      },
      onEventSound: (good) {
        good ? _soundService.playEventGood() : _soundService.playEventBad();
        // Any market event (good or bad) counts toward the "witness any event"
        // rig milestone — fires here regardless of the open tab.
        eventsSeen++;
        // Chaos procs (OG Market Whisper / Pool Hedge Payout) fire off the real
        // event's good/bad polarity.
        _fireProcs(good ? ProcEvent.onGoodChaos : ProcEvent.onBadChaos);
      },
      volatilityFactor: () => volatilityMultiplier,
      applyResistances: resistEvent, // DIAMOND HANDS / FEE HEDGE / STEEL NERVES
      chaosSteering: () => (
        suppressNegatives: abilityCrashImmune, // STEADY HANDS / CONSENSUS RALLY
        bullBias: bullBiasStrength, // BULL BIAS attribute (Slice 72b)
      ),
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
    _breach.stop(); // drop any in-flight breach threat on background (no offline theft)
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
  void clickAnomaly() {
    _anomaly.collect();
    _fireProcs(ProcEvent.onAnomalyCollect);
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

  /// Aggregates all channel bonuses (research + perks + stash) into one place —
  /// the single source of truth for the economy's multipliers (channel model).
  Channels buildChannels() {
    final ch = Channels();
    _researchManager.contributeChannels(ch);
    _perkManager.contributeChannels(ch, _classManager.current);
    _stash.contributeChannels(ch);
    _classManager.contributeChannels(ch); // class weightings + permanent Mastery
    // Auras/stances are ON-CHANNEL: active (condition-true) equipped ones add here
    // and get softcapped with everything else (no outside lane).
    _auras.contributeChannels(
        ch, _auraContext(), _classManager.current, currentClassMasteryLevel);
    return ch;
  }

  // --- Auras / stances (Phase 7) -----------------------------------------
  final AuraSystem _auras = AuraSystem();

  /// Live snapshot for aura conditions (cheap; reads flags, not buildChannels).
  AuraContext _auraContext() => AuraContext(
        goodEvent: chaosIncomeMultiplier > 1.001 || chaosCostMultiplier < 0.999,
        badEvent: chaosIncomeMultiplier < 0.999 || chaosCostMultiplier > 1.001,
        breachPending: _breach.pending,
        supplyProgress: supplyProgress,
      );

  List<AuraDef> availableAuras() =>
      _auras.availableFor(_classManager.current, currentClassMasteryLevel);

  /// True while [auraId]'s WHILE-condition is currently satisfied — drives the
  /// aura panel's live LIT/dim indicator so a conditional passive doesn't read as
  /// a permanent bonus (a while-system's whole point). `always` auras are always lit.
  bool auraConditionHolds(String auraId) {
    final def = _auras.byId(auraId);
    return def != null && _auraContext().matches(def.condition);
  }

  String? get equippedStance => _auras.equippedStance;
  List<String> get equippedAuras => List.unmodifiable(_auras.equippedAuras);
  int auraSwitchCooldownMs() => _auras.switchCooldownRemainingMs(_nowMs());

  /// Returns false if the switch was blocked (the 60s anti-flicker lockout) so
  /// the UI can flash feedback instead of the tap silently doing nothing.
  bool equipStance(String? id) {
    if (_auras.setStance(id, _nowMs())) {
      notifyListeners();
      _saveGame();
      return true;
    }
    return false;
  }

  bool toggleAura(String id) {
    if (_auras.toggleAura(id, _nowMs())) {
      notifyListeners();
      _saveGame();
      return true;
    }
    return false;
  }

  /// Hash rate from rigs × the softcapped HASH channel — WITHOUT ability temp
  /// buffs (used to size instant lumps and as the base for [globalHashRate]).
  double _baseGlobalHashRate() {
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

  double get globalHashRate {
    // Ability hash buffs (SPIN UP / SATOSHI MODE / CONSENSUS RALLY) apply on the
    // outside-softcap temp lane, clamped to the aggregate hash ceiling (#10).
    final temp = abilityHashMult;
    final capped = temp > GameConstants.hashTempMax
        ? GameConstants.hashTempMax
        : temp;
    // Keystone hash lever (permanent build state; e.g. ASIC Monoculture ×2,
    // Sweat Equity ×0.5) applies on top of everything, offline included.
    return _baseGlobalHashRate() * capped * keystoneMods.hashMult;
  }

  // Fractional block accumulator, shared by the live tick and offline catch-up.
  double _blockCarry = 0;

  // True only while _simulateOfflineMining is running its catch-up loop. While
  // set, a win crossing mid-loop sets the latches but does NOT notify/save/cue —
  // otherwise the ending overlay would be pushed BEFORE offlineEarningsAmount is
  // assigned and end up buried under the WELCOME BACK dialog. The single trailing
  // notify after the loop lets the offline dialog open first and the ending defer.
  bool _inOfflineSim = false;

  /// Applies [seconds] of passive mining at the CURRENT hash rate and returns
  /// the income earned. Single source of truth for both the 1-second live tick
  /// and the chunked offline catch-up so the two can never diverge.
  double _accrueMining(double seconds,
      {required double chaosMultiplier, double yieldFactor = 1.0}) {
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
      halvingResist: halvingResistance,
    );
    // [yieldFactor] is the OFFLINE YIELD fraction (<=1.0) for offline catch-up;
    // the live tick passes 1.0. Applied before the supply clamp so offline still
    // fills — just slower — up to the inviolable per-era cap. The keystone income
    // lever (e.g. Low Time Preference ×0.70) is a real permanent income change.
    double income = perSecond * seconds * yieldFactor * keystoneMods.incomeMult;
    // The per-era 21M supply cap is now INVIOLABLE (sandbox removed): income is
    // always clamped to the room left this era, so an era mines at most one full
    // 21,000,000-BTC supply.
    final room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) return 0;
    if (income > room) income = room;
    // THE POWER BILL: upkeep skims the spendable WALLET only. The gross still
    // credits lifetime + the 21M drawdown + Mastery XP in full (via
    // _creditLifetimeEver), so upkeep slows buying — never the win/supply/Mastery.
    // (Manual taps are deliberately NOT taxed — they stay the full-value active
    // reward.)
    final double net = income * netIncomeFraction;
    wallet += net;
    lifetimeEarnings += income;
    _creditLifetimeEver(income); // cumulative-ever stat + LAST SATOSHI win check
    return net; // the spendable gain (what "WELCOME BACK" announces)
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

    // BLOCK RACE auto-taps (works even before any rig — clicks aren't gated on hash).
    _fireAutoTaps();

    if (globalHashRate <= 0) return;
    _accrueMining(1, chaosMultiplier: _liveIncomeTempMult());
    if (_advanceBlocks(1)) {
      _triggerHalving();
      _soundService.playHalving();
      _hapticHeavy();
      _fireProcs(ProcEvent.onHalving);
    }
    _fireProcs(ProcEvent.onBlockFound); // HOT tier (ICD-gated to ~once/8s)
    // AUTO-APPLY: rebuild the active TECH preset as income allows (fast no-op once
    // the build is complete or if auto-apply is off / no preset).
    _maybeAutoApplyPreset();
    _evaluateAchievements();
    notifyListeners();
  }

  /// Test-only: advance [seconds] of real passive mining (full channel model +
  /// income multiplier + halving) without the 1-second timer. Lets the economy
  /// simulation drive the REAL accrual path — including research/perk/stash
  /// bonuses — in fast chunks. Returns income earned.
  @visibleForTesting
  double advanceForTest(double seconds, {double yieldFactor = 1.0}) {
    final earned =
        _accrueMining(seconds, chaosMultiplier: 1.0, yieldFactor: yieldFactor);
    if (_advanceBlocks(seconds)) _triggerHalving();
    return earned;
  }

  /// Test seam: run one real 1-second tick (auto-clicker, BLOCK RACE auto-taps,
  /// accrual, halving, procs) — the foreground path advanceForTest deliberately
  /// skips.
  @visibleForTesting
  void debugTick() => _mine();

  /// Test seam: request [n] proc/anomaly UTXO through the per-window cap (#25);
  /// returns the amount actually granted.
  @visibleForTesting
  int debugGrantUtxo(int n) => _grantUtxoCapped(n);

  /// Test seam: re-evaluate achievements (normally driven by tick/actions).
  @visibleForTesting
  void debugEvaluateAchievements() => _evaluateAchievements();

  /// Test seam: persist the current state now.
  @visibleForTesting
  Future<void> debugSave() => _saveGame();

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
      lifetimeEverSats: lifetimeEverSats,
      hasWonGame: hasWonGame,
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
      // RPG class / Mastery + endgame (Phase 6 role achievements).
      totalMasteryLevel: totalMasteryLevel,
      masteredClassCount: masteredClassCount,
      classMasteryLevel: classMasteryLevelByName,
      speedRunBestMs: speedRunBestMs,
      speedRunClassCount: speedRunClassCount,
    );
  }

  /// The single chokepoint that grows the cumulative-ever endgame counter and
  /// checks the win. Called from EVERY income-crediting site (passive tick,
  /// click, offline catch-up) with the sats just credited. Fires the "GENESIS
  /// COMPLETE" ending exactly once — the persisted [hasWonGame] latch makes
  /// every later call a cheap no-op, so it's safe to call every tick.
  void _creditLifetimeEver(double amount) {
    if (!amount.isFinite || amount <= 0) return;
    // Mastery is earned by MINING — credited live to the class you're playing
    // (passive tick, click, offline catch-up, Back-in-Time run all flow here).
    // One full 21M supply mined = exactly one Mastery unit; un-farmable by
    // rapid resetting since only mining grants it.
    _classManager.creditMasteryFromMining(_classManager.current, amount);
    lifetimeEverSats += amount; // cosmetic lifetime stat (survives all resets)
    if (!lifetimeEverSats.isFinite) lifetimeEverSats = double.maxFinite;
    // Speed Run: accumulate this run's mined total and finish at one full supply.
    // Runs before the win latch's early-return so a run can complete post-win too.
    if (_speedRun.credit(amount, _classManager.current.name)) {
      _onSpeedRunFinished();
    }
    // THE LAST SATOSHI: the win is the FIRST time a single era mines the full
    // 21,000,000-BTC supply (lifetimeEarnings reaches the inviolable per-era cap).
    if (hasWonGame) return;
    if (lifetimeEarnings < GameConstants.maxSupplySats) return;
    hasWonGame = true;
    pendingWinCelebration = true; // drained once by the UI (not persisted)
    // During offline catch-up, defer ALL UI side effects: the loop assigns
    // offlineEarningsAmount only after it finishes, so a notify here would show
    // the ending before the WELCOME BACK dialog and stack it underneath. The
    // caller's trailing notify (+ end-of-loop _saveGame) surfaces both in order.
    if (_inOfflineSim) return;
    _soundService.playEnding(); // dramatic cue for the ending
    _hapticHeavy();
    _saveGame();
    notifyListeners();
  }

  /// Linear progress (0..1) of THIS era toward the full 21M supply — honest,
  /// tops out at exactly 100% the moment the era mines out (which, the first
  /// time, is THE LAST SATOSHI win). Replaces the old log-scaled "ALL BITCOIN"
  /// bar that read ~56% after a single era.
  double get supplyProgress =>
      (lifetimeEarnings / GameConstants.maxSupplySats).clamp(0.0, 1.0);

  /// Drain the one-shot ending trigger after the UI has shown it.
  void clearWinCelebration() {
    if (!pendingWinCelebration) return;
    pendingWinCelebration = false;
    notifyListeners();
  }

  // --- Speed Run (Genesis Sprint) ----------------------------------------

  /// Unlocks only AFTER the win (mining one full 21M supply). BACK IN TIME is the
  /// post-credits replay loop, so gating it on hasWonGame — not the first Hard
  /// Fork — keeps the normal prestige CTA and the Back-in-Time CTA from colliding
  /// pre-win (ENDGAME_REDESIGN Review #1). The permanent spine (Genesis / Mastery /
  /// Notoriety / Stash / chips) a winner carries in makes the sprint meaningful.
  bool get speedRunUnlocked => hasWonGame;

  /// Fraction (0..1) of one full 21M-BTC supply mined in the current run.
  double get speedRunProgress => _speedRun.progress;

  /// Live elapsed milliseconds of the active run (0 when none is running).
  /// Wall-clock, so it keeps counting across a background/close.
  int get speedRunElapsedMs => _speedRun.elapsedMs;

  /// Whether the most recently completed run set a new best time.
  bool get speedRunWasRecord => _speedRun.wasRecord;

  /// Distinct REAL classes (not Prospector) with a recorded Back-in-Time best —
  /// drives THE TIMECHAIN capstone.
  int get speedRunClassCount =>
      _speedRun.classCount(BtcClass.prospector.name);

  /// Best Back-in-Time time (ms) recorded as [className], or 0 if none.
  int speedRunBestForClass(String className) =>
      _speedRun.bestForClass(className);

  /// Begin a Speed Run: a deep New-Blockchain-style reset (keeps Genesis Blocks,
  /// Mastery, achievements/Notoriety and Stash; wipes wallet/rigs/TECH/TALENTS/
  /// GovTokens/era) with the stopwatch started. Restarting while a run is active
  /// abandons the current attempt. No-op until [speedRunUnlocked].
  void startSpeedRun({BtcClass? chosenClass}) {
    if (!speedRunUnlocked) return;
    _speedRun.begin();
    _newChainInternal(chosenClass: chosenClass); // deep reset + save + notify
  }

  /// Finish side-effects after [_speedRun.credit] records a completed run (from
  /// the income chokepoint at one full supply). The record-keeping already ran in
  /// the system; here we fire the UI/achievement effects (deferred in offline sim).
  void _onSpeedRunFinished() {
    if (_inOfflineSim) return; // defer UI during offline catch-up
    _evaluateAchievements(); // unlock the time medals + THE TIMECHAIN on completion
    _soundService.playEnding();
    _hapticHeavy();
    _saveGame();
    notifyListeners();
  }

  /// Abandon the active run without recording a time. The current (already
  /// reset-and-partly-rebuilt) state stays; the player just leaves the timer.
  void abortSpeedRun() {
    if (!speedRunActive) return;
    _speedRun.abort();
    _saveGame();
    notifyListeners();
  }

  /// Drain the one-shot SPEED RUN COMPLETE trigger after the UI has shown it.
  void clearSpeedRunCelebration() {
    if (_speedRun.clearCelebration()) notifyListeners();
  }

  /// Test seam: credit cumulative-ever (and thus advance an active Speed Run)
  /// directly, without driving the whole mining tick.
  @visibleForTesting
  void debugCreditEver(double amount) => _creditLifetimeEver(amount);

  /// Evaluate achievements; queue toasts + save on any new unlock. Cheap enough
  /// to run every tick and after each discrete action.
  void _evaluateAchievements() {
    final newly = _achievements.evaluate(_buildAchStats());
    final playedAchievementCue = newly.isNotEmpty;
    if (playedAchievementCue) {
      pendingAchievementToasts.addAll(newly);
      _soundService.playAchievement();
      _saveGame();
    }
    // If an achievement chime just fired, let any simultaneous tab reveal (e.g.
    // the first achievement unlocking GOAL) happen WITHOUT its own overlapping
    // cue — one celebratory sound per frame, not a double-chime.
    _refreshTabUnlocks(suppressSound: playedAchievementCue);
    _rigReveal.refresh();
  }

  /// Reveal bottom-nav tabs as the player progresses (sticky — never re-locks).
  /// [silent] sets the flags without queuing a toast (used on load so returning
  /// players / newly-added gates don't spam notifications). Conditions are
  /// deliberately gentle so content unfolds instead of arriving all at once:
  ///   TECH  after 10k sats mined (a bit of play, not the very first rig);
  ///   STASH after 1M sats / a chip / a crate;
  ///   SKILL after the first Hard Fork (when GovTokens first exist to spend).
  void _refreshTabUnlocks({bool silent = false, bool suppressSound = false}) {
    final newly = <String>[];
    var changed = false;
    if (!unlockedTech && lifetimeEarnings >= 10000) {
      unlockedTech = true;
      changed = true;
      newly.add('TECH');
    }
    if (!unlockedStash &&
        (lifetimeEarnings >= 1e6 || chips >= 1 || cratesOpened >= 1)) {
      unlockedStash = true;
      changed = true;
      newly.add('STASH');
    }
    if (!unlockedSkill && hardForkCount >= 1) {
      unlockedSkill = true;
      changed = true;
      newly.add('SKILL');
    }
    if (!unlockedGoal && achievementsUnlocked >= 1) {
      unlockedGoal = true;
      changed = true;
      newly.add('GOAL');
    }
    if (!changed) return;
    if (!silent) {
      pendingTabUnlockToasts.addAll(newly);
      if (!suppressSound) _soundService.playUnlock();
      _saveGame();
      notifyListeners();
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
  // prestige-gain multiplier (class: BTC OG boosts / Corporation reduces; plus
  // the permanent NG+ trophy multiplier). All applied to the raw root inside the
  // economy service so partial token progress is preserved, matching Consensus.
  int get pendingGovTokens => _economy.calculatePendingGovTokens(
    lifetimeEarnings,
    // PAPER HANDS ×2 applies only to the GovToken (Hard Fork) yield, not to the
    // Tier-1 Consensus gain, so it lives here rather than in prestigeGainMultiplier.
    gainMultiplier: _prestige.genesisGainMultiplier *
        prestigeGainMultiplier *
        keystoneMods.govTokenGainMult,
  );

  // Injectable so tests can force a crit / no-crit deterministically.
  Random _clickRng = Random();
  @visibleForTesting
  set clickRng(Random r) => _clickRng = r;

  /// Pre-crit sats for ONE tap at the current click power: perks + Channel.click
  /// (softcapped) × the ability temp lane (capped to the click ceiling #10) × the
  /// keystone click lever, run through the income channel + chaos + notoriety +
  /// halving. Shared by [clickMine] and the BLOCK RACE auto-tap so the two paths
  /// can never diverge.
  double _clickSatsBase() {
    final ch = buildChannels();
    double clickPower = _economy.calculateClickPower(_perkManager.perks);
    // Stash click power is folded into Channel.click (see stash.contributeChannels)
    // so it shares the click softcap instead of being a raw out-of-band multiplier.
    clickPower *= ch.multiplier(
      Channel.click,
      softStart: GameConstants.clickSoftStart,
      power: GameConstants.channelSoftPower,
    );
    // Ability click buffs (OVERCLOCK / BLOCK RACE) on the outside-softcap temp
    // lane, clamped to the aggregate click ceiling (#10).
    final double clickTemp = abilityClickMult;
    clickPower *= clickTemp > GameConstants.clickTempMax
        ? GameConstants.clickTempMax
        : clickTemp;
    // SWEAT EQUITY ×2.5 / LASER EYES ×0.5 — keystone click lever (outside softcap).
    clickPower *= keystoneMods.clickMult;
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
      halvingResist: halvingResistance,
    );
  }

  /// BLOCK RACE (Solo ultimate): while active, auto-fire a burst of guaranteed-crit
  /// taps each 1-second tick. Synthetic → fires NO procs/sound/haptic (GOLDEN
  /// RULE), credits wallet + lifetime + cumulative-ever, and is supply-clamped.
  /// The whole burst is one _clickSatsBase() evaluation ×gCrit ×taps (all taps in
  /// a tick are identical) so it stays cheap.
  void _fireAutoTaps() {
    if (_inOfflineSim) return;
    if (!_abilities.anyActive(_nowMs(), (d) => d.autoTaps)) return;
    final double gCrit = _abilities.activeGuaranteedCritMult(_nowMs());
    if (gCrit <= 0 || keystoneMods.noCrits) return;
    double sats = _clickSatsBase() * gCrit * GameConstants.blockRaceTapsPerTick;
    final double room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) return;
    if (sats > room) sats = room;
    if (sats <= 0) return;
    wallet += sats;
    lifetimeEarnings += sats;
    _creditLifetimeEver(sats);
  }

  /// Result of a single [clickMine] tap, for the UI (float text + juice).
  ClickResult clickMine({bool playSound = true}) {
    double clickSats = _clickSatsBase();

    // Critical tap: rare multiplied payout (game feel). Only a *real* tap can
    // crit — the silent auto-clicker never rolls, so it can't secretly pump.
    // Luck scales the crit chance up to a hard cap.
    final double critChance = (GameConstants.clickCritChance * critLuckMultiplier)
        .clamp(0.0, GameConstants.clickCritChanceCap);
    // OVERCLOCK / BLOCK RACE: every REAL tap is a guaranteed crit at the ability's
    // payout (auto-taps never crit — loop safety). Otherwise roll the chance and
    // pay the BLOCK REWARD crit multiplier.
    final double gCrit =
        _inOfflineSim ? 0 : _abilities.activeGuaranteedCritMult(_nowMs());
    // ASIC MONOCULTURE / COLD WALLET / FORT KNOX forbid crits entirely — the
    // taps-never-crit half of their bargain.
    final bool isCrit = !keystoneMods.noCrits &&
        playSound &&
        (gCrit > 0 || _clickRng.nextDouble() < critChance);
    if (isCrit) {
      clickSats *= (gCrit > 0 ? gCrit : critPayoutMultiplier);
    }

    // Re-clamp to the inviolable per-era supply cap AFTER the crit multiply
    // (mirrors _accrueMining) so a crit near the cap can't push lifetimeEarnings
    // over maxSupplySats and flip networkDifficulty to Infinity.
    final double room = GameConstants.maxSupplySats - lifetimeEarnings;
    if (room <= 0) {
      clickSats = 0;
    } else if (clickSats > room) {
      clickSats = room;
    }

    lifetimeEarnings += clickSats;
    wallet += clickSats;
    _creditLifetimeEver(clickSats); // cumulative-ever stat + LAST SATOSHI win
    // Only a real tap makes the click sound; the AI auto-clicker stays silent
    // so it doesn't emit a click every 5 seconds on its own.
    if (playSound) {
      if (isCrit) {
        _soundService.playCrit();
        _hapticHeavy();
      } else {
        _soundService.playMine();
      }
    }

    // Procs: only a REAL tap triggers (auto-taps are synthetic → GOLDEN RULE).
    if (playSound) {
      _fireProcs(ProcEvent.onTap);
      if (isCrit) {
        _fireProcs(ProcEvent.onCrit);
        // A run of consecutive crits fires the streak hook, then resets.
        if (++_critStreak >= GameConstants.critStreakThreshold) {
          _fireProcs(ProcEvent.onCritStreak);
          _critStreak = 0;
        }
      } else {
        _critStreak = 0;
      }
    }

    _evaluateAchievements();
    notifyListeners();
    return ClickResult(clickSats, isCrit);
  }

  double get estimatedClickValue {
    final ch = buildChannels();
    double clickPower =
        _economy.calculateClickPower(_perkManager.perks) *
        ch.multiplier(
          Channel.click,
          softStart: GameConstants.clickSoftStart,
          power: GameConstants.channelSoftPower,
        );

    // Difficulty is ∞ once this era hits the per-era cap (income clamped to 0),
    // so the click readout shows 0 there.
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

    _soundService.playPrestige(); // dramatic cue for the prestige reset
    _hapticHeavy();

    govTokens += tokensToClaim;
    // Feed tier-3 progress: every GovToken ever minted counts toward the next
    // New Blockchain / Genesis Block.
    _prestige.recordGovTokensMinted(tokensToClaim);
    // (Mastery is no longer credited here — it now accrues live from MINING in
    // _creditLifetimeEver, per mined supply, so it can't be farmed by forking.)
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
    _rigReveal.resetAndSnapshot(); // re-progress rig reveals from the first rig

    // Reset Research (ResearchManager)
    _researchManager.reset();
    _respecUsed = false; // fresh era → the free respec refreshes

    // Consensus is an era currency wiped by a Hard Fork.
    _prestige.onHardFork();

    hardForkCount++;
    _fireProcs(ProcEvent.onHardFork); // COLD-tier firmware hooks (UTXO survives)
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
  /// When null the current class carries over (used by sims/tests). Mastery is
  /// credited per MINED supply live in [_creditLifetimeEver] (not at forks), so
  /// nothing needs to be credited here.
  void newBlockchain({BtcClass? chosenClass}) {
    if (pendingGenesis <= 0) return;
    _newChainInternal(chosenClass: chosenClass);
  }

  /// The New-Blockchain reset body (Tier-3 deep reset). Order is load-bearing:
  /// applyNewBlockchain -> select -> wipe -> count -> evaluate -> save. Do NOT
  /// reset any endgame field here (they are the permanent spine that survives
  /// every prestige). Mastery is NOT credited here — it accrues per MINED supply
  /// in [_creditLifetimeEver]. (The old New Genesis / NG+ trophy path that also
  /// called this was retired with THE LAST SATOSHI endgame pivot.)
  void _newChainInternal({BtcClass? chosenClass}) {
    _soundService.playPrestige(); // dramatic cue for the deepest reset
    _hapticHeavy();

    // Bank Genesis Blocks, snapshot the chain baseline, wipe Consensus.
    _prestige.applyNewBlockchain();

    // Lock in the class for the new chain (if the player picked one).
    if (chosenClass != null) _classManager.select(chosenClass);

    // Wipe the run. Stash artifacts are deliberately preserved (permanent
    // collection); Genesis Blocks were just banked above. CHIPS (UTXO) are now
    // PERMANENT too — they only buy crates that fill the permanent Stash, so
    // wiping them would destroy convertible-to-permanent value (only a full
    // Wipe Save clears them, in resetGame).
    wallet = 0;
    lifetimeEarnings = 0;
    govTokens = 0;
    spentGovTokens = 0;
    _miningManager.hardForkReset();
    for (var rig in rigs) {
      rig.amount = 0;
    }
    _rigReveal.resetAndSnapshot(); // re-progress rig reveals from the first rig
    _researchManager.reset();
    _respecUsed = false; // fresh era → the free respec refreshes
    _perkManager.reset();

    newChainCount++;
    _fireProcs(ProcEvent.onGenesis); // COLD-tier firmware hooks (deepest reset)
    _evaluateAchievements();
    _saveGame();
    notifyListeners();
  }

  // (New Genesis+ and the "break the chain" sandbox were retired with the
  // endgame pivot — the 21M/era cap is now inviolable and the post-credits loop
  // is Back in Time. Post-win deep resets go through the normal newBlockchain /
  // Back-in-Time paths.)

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

  /// The live sat cost of the next unit of [rig] (rig-cost discount channel +
  /// keystone/ability cost mods, capped + floored by calculateRigCost).
  double getRigCostInSats(Rig rig) {
    // Total rig-cost discount (perks + cooling/solar research + stash) comes
    // from the RIG_COST channel; calculateRigCost applies the 95% channel cap and
    // the 5% final-product floor. Ability cost buffs (HOSTILE TAKEOVER ×0.5) feed
    // abilityCostMultiplier; a COST FREEZE (Pool) pins to the sticker price.
    final bool frozen =
        !_inOfflineSim && _abilities.anyActive(_nowMs(), (d) => d.costFreeze);
    if (frozen) return rig.currentCost;
    // JUNKYARD RIGS adds +0.95 into the rig-cost discount channel, slamming rigs to
    // the −95% floor; calculateRigCost still enforces that cap + the 5% floor.
    return _economy.calculateRigCost(
      rig,
      buildChannels().sum(Channel.rigCost) + keystoneMods.rigCostBonus,
      chaosCostMultiplier,
      abilityCostMultiplier: _inOfflineSim ? 1.0 : _abilities.rigCostMult(_nowMs()),
    );
  }

  void buyPerk(String perkId) {
    int cost = _perkManager.tryBuy(perkId, govTokens, _classManager.current);
    if (cost > 0) {
      govTokens -= cost;

      spentGovTokens += cost;
      _soundService.playSkill();
      _evaluateAchievements();
      _saveGame();
      notifyListeners();
    }
  }

  /// Opens a crate of [tier] and returns the artifact won (null if unaffordable),
  /// so the UI can show a reveal of exactly what dropped.
  Artifact? buyCrate(CrateTier tier) {
    final int cost = crateDef(tier).cost;
    if (chips < cost) return null;
    chips -= cost;
    final won = _stash.openCrate(tier: tier, fortune: fortuneBonus);
    cratesOpened++;
    _soundService.playCrate();
    _fireProcs(ProcEvent.onCrateOpen);
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
      researchCount: _researchManager.researchCountJson(), // BLUEPRINTS
      techPresets: _researchManager.presetsJson(), // PRESETS
      activeTechPreset: _researchManager.activePreset,
      autoApplyPresets: _researchManager.autoApplyPresets,
      abilityCooldowns: _abilities.lastUsedJson(), // ability cooldowns (wall-clock)
      firstBreachDone: _breach.firstBreachDone, // THE BREACH drill spent
      respecUsed: _respecUsed, // free respec spent this era
      auras: _auras.toJson(), // equipped stance + auras
      keystones: _keystones.toJson(), // equipped keystones (≤2)
      firmware: _firmware.toJson(), // equipped Rig Firmware loadout
      // economy
      networkDifficulty: networkDifficulty,
      blockReward: _miningManager.blockReward,
      blocksMined: _miningManager.blocksMined,
      nextHalvingThreshold: _miningManager.nextHalvingThreshold,
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
      casinoSpins: _casinoManager.spins,
      casinoJackpots: _casinoManager.jackpots,
      casinoWindowNet: _casinoManager.windowNet,
      casinoWindowStartMs: _casinoManager.windowStartMs,
      currentClass: _classManager.current.name,
      mastery: _classManager.masteryJson(),
      lifetimeEverSats: lifetimeEverSats,
      hasWonGame: hasWonGame,
      unlockedTech: unlockedTech,
      unlockedStash: unlockedStash,
      unlockedSkill: unlockedSkill,
      unlockedGoal: unlockedGoal,
      eventsSeen: eventsSeen,
      unlockedRigs: _rigReveal.unlockedRigs.toList(),
      rigSnap: {
        'rigs': _rigReveal.snapRigs,
        'crates': _rigReveal.snapCrates,
        'spins': _rigReveal.snapSpins,
        'events': _rigReveal.snapEvents,
        'hash': _rigReveal.snapHash,
      },
      speedRunActive: _speedRun.active,
      speedRunStartMs: _speedRun.startMs,
      speedRunMinedSats: _speedRun.minedSats,
      speedRunBestMs: _speedRun.bestMs,
      speedRunBestByClass: _speedRun.bestByClass,
      speedRunLastMs: _speedRun.lastMs,
    );
  }

  /// Minimum time the branded splash stays up, so a fast local load (prefs read
  /// in a few ms) doesn't skip past the splash before its first frame even paints
  /// — otherwise the loading screen / its flavour line is never actually seen.
  static const int _minSplashMs = 1700;

  Future<void> _holdSplash(int startMs) async {
    // Only in the real app (timers auto-start). Tests build with startTimers:false
    // and must not eat a 1.7s delay on every loadGame().
    if (!_autoStartTimers) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    if (elapsed < _minSplashMs) {
      await Future.delayed(Duration(milliseconds: _minSplashMs - elapsed));
    }
  }

  Future<void> loadGame() async {
    final splashStartMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final settings = await _settingsRepo.loadSettings();
      soundEnabled = settings['sound_enabled'] ?? true;
      hapticsEnabled = settings['haptics_enabled'] ?? true;
      showFiatPrices = settings['show_fiat_prices'] ?? false;
      onboardingComplete = settings['onboarding_complete'] ?? false;
      _seenTips
        ..clear()
        ..addAll(
            (settings['seen_tips'] as List?)?.cast<String>() ?? const []);
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
      // (The old 'bitcoinExchangeRate' mechanic was fully neutralised — always 1.0
      // — and has been removed; any legacy key in old saves is simply ignored.)

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

      // Endgame (Phase 5). MUST load before the offline sim below so an
      // already-won returning player has hasWonGame=true first and the offline
      // catch-up can't falsely re-fire the ending. `lifetimeEverSats` is now just
      // a cosmetic lifetime stat.
      lifetimeEverSats = _toDouble(data['lifetimeEverSats']);
      hasWonGame = data['hasWonGame'] == true;
      // Migration: THE LAST SATOSHI win now latches when a single era fills the
      // 21M cap. Silently latch (no replayed credits) for any legacy save already
      // sitting at the cap. Dropped fields (sandboxNoCap, winCount) are ignored.
      if (lifetimeEarnings >= GameConstants.maxSupplySats) hasWonGame = true;

      // Speed Run (wall-clock timed challenge). The start timestamp keeps the
      // clock running across a close; a missing/garbage start with an active
      // flag would read as an absurd elapsed, so drop the run in that case.
      _speedRun.active = data['speedRunActive'] == true;
      _speedRun.startMs = _toInt(data['speedRunStartMs']);
      _speedRun.minedSats = _toDouble(data['speedRunMinedSats']);
      _speedRun.bestMs = _toInt(data['speedRunBestMs']);
      final byClass = data['speedRunBestByClass'];
      _speedRun.bestByClass = {};
      if (byClass is Map) {
        byClass.forEach((k, v) {
          if (k is String && v is num) _speedRun.bestByClass[k] = v.toInt();
        });
      }
      _speedRun.lastMs = _toInt(data['speedRunLastMs']);
      if (_speedRun.active && _speedRun.startMs <= 0) _speedRun.active = false;

      // Progressive-disclosure tab unlocks (sticky). Defaults false for saves
      // predating this; the silent refresh below re-derives them from loaded
      // progress so returning players keep already-earned tabs without a toast.
      unlockedTech = data['unlockedTech'] == true;
      unlockedStash = data['unlockedStash'] == true;
      unlockedSkill = data['unlockedSkill'] == true;
      unlockedGoal = data['unlockedGoal'] == true;

      // Achievements + action counters (persist across all prestige tiers).
      hardForkCount = _toInt(data['hardForkCount']);
      softForkCount = _toInt(data['softForkCount']);
      newChainCount = _toInt(data['newChainCount']);
      cratesOpened = _toInt(data['cratesOpened']);
      _casinoManager.restore(
        spins: _toInt(data['casinoSpins']),
        jackpots: _toInt(data['casinoJackpots']),
        windowNet: _toDouble(data['casinoWindowNet']),
        windowStartMs: _toInt(data['casinoWindowStartMs']),
      );
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

      // Rig progression (milestone system) — restored AFTER rigs so the
      // grandfather can read them and globalHashRate is computable.
      // Fall back to the old 'bullRunsSeen' key so a pre-rename save keeps its
      // event baseline.
      eventsSeen = _toInt(data['eventsSeen'] ?? data['bullRunsSeen']);
      _rigReveal.unlockedRigs
        ..clear()
        ..addAll((data['unlockedRigs'] as List?)?.cast<String>() ?? const []);
      final rigSnap = data['rigSnap'];
      if (rigSnap is Map) {
        _rigReveal.snapRigs = _toInt(rigSnap['rigs']);
        _rigReveal.snapCrates = _toInt(rigSnap['crates']);
        _rigReveal.snapSpins = _toInt(rigSnap['spins']);
        _rigReveal.snapEvents = _toInt(rigSnap['events'] ?? rigSnap['bullRuns']);
        _rigReveal.snapHash = _toDouble(rigSnap['hash']);
      } else {
        // Save predates the milestone system: reveal everything up to the
        // highest-owned rig and baseline the snapshot to NOW, so the next rig's
        // milestone is measured from here (no cascade / pre-satisfaction).
        var highestOwned = 0;
        for (var i = 0; i < rigs.length; i++) {
          if (rigs[i].amount > 0) highestOwned = i;
        }
        for (var i = 1; i <= highestOwned; i++) {
          _rigReveal.unlockedRigs.add(rigs[i].id);
        }
        _rigReveal.snapshotTarget();
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
      // BLUEPRINTS: permanent per-node re-tech counts (survive every reset).
      _researchManager.loadResearchCounts(data['researchCount']);
      // PRESETS: saved TECH builds + active index + auto-apply flag.
      _researchManager.loadPresets(data['techPresets'],
          data['activeTechPreset'], data['autoApplyPresets']);
      // Ability cooldowns (wall-clock; persist across resets, wiped on full wipe).
      _abilities.loadLastUsed(data['abilityCooldowns']);
      // THE BREACH: whether the one-time 0-loss drill has been spent.
      _breach.loadFrom(data['firstBreachDone'] == true);
      // The one-per-era free respec: whether it's been spent this era.
      _respecUsed = data['respecUsed'] == true;
      // Auras/stances loadout (persists across resets; full wipe clears).
      _auras.loadFrom(data['auras']);
      // Keystones loadout (persists across resets; full wipe clears).
      _keystones.loadFrom(data['keystones']);
      // Rig Firmware loadout (Time-Capsule: persists across resets; wipe clears).
      _firmware.loadFrom(data['firmware']);
      // Unlock any node whose prerequisites are already completed — covers nodes
      // added by a content update after this save was written (else they stay
      // stuck as "???" and the LAB soft-locks).
      _researchManager.refreshUnlocks();

      // The load has succeeded far enough to be authoritative; saves are now
      // safe to persist (and the offline sim below relies on this). Hold the
      // splash to its minimum first so the loading screen is actually seen.
      await _holdSplash(splashStartMs);
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

      // Same for tab unlocks: derive from loaded progress without a toast.
      _refreshTabUnlocks(silent: true);
    } catch (e, st) {
      // A failed load must not brick the game: log, keep the in-code defaults,
      // and still mark the game loaded so timers start and play can continue.
      debugPrint('GameLogic.loadGame failed, using defaults: $e\n$st');
    } finally {
      await _holdSplash(splashStartMs); // no-op if the success path already held
      _isLoaded = true;
    }

    notifyListeners();
  }

  static double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
  static int _toInt(dynamic v) => v is num ? v.toInt() : 0;

  void _simulateOfflineMining(int totalSeconds, {bool announce = true}) {
    if (totalSeconds <= 0) return;
    // IDLE CAPACITY: an absence banks at most the offline WINDOW (base 8h, up to
    // 24h with `idle` sources), not the full time away.
    final int windowCap = idleCapacitySeconds.floor();
    if (totalSeconds > windowCap) totalSeconds = windowCap;
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
    _inOfflineSim = true;
    try {
      for (int i = 0; i < iterations; i++) {
        accrued += _accrueMining(timePerTick,
            chaosMultiplier: 1.0, // no chaos offline
            yieldFactor: offlineFraction); // OFFLINE YIELD attribute
        _advanceBlocks(timePerTick);
        // Stop early once the per-era supply is exhausted (income is 0 past the
        // inviolable 21M/era cap).
        if (lifetimeEarnings >= GameConstants.maxSupplySats) break;
      }
    } finally {
      _inOfflineSim = false;
    }

    if (accrued > 0) {
      if (announce) offlineEarningsAmount = accrued;
      _saveGame();
    }
  }
}
