import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../channels.dart';
import '../managers/class_manager.dart';

/// Which of a class's three ability slots. Progressive unlock: [basic1] on class
/// pick, [basic2] at Mastery 1, [ultimate] at Mastery 2.
enum AbilitySlot { basic1, basic2, ultimate }

/// Static definition of an active ability (RPG Phase 4). Effects are declarative:
/// a set of temporary channel multipliers ([tempMult]) applied on the outside-
/// softcap temp lane while active, plus optional bespoke effect fields. Numbers
/// come from ATTRIBUTES_AND_ABILITIES.md §2c.
class AbilityDef {
  final String id;
  final BtcClass btcClass;
  final AbilitySlot slot;
  final String name;
  final String description;
  final IconData icon;
  final int cooldownMs;
  final int durationMs; // 0 = instant (no active-buff window)

  /// Temp multipliers applied WHILE ACTIVE (income/hash/click on the aggregate-
  /// capped temp lane; luck read separately).
  final Map<Channel, double> tempMult;

  // --- bespoke effect fields ---
  final double instantIncomeSeconds; // Corp lumps: bank N seconds of income now
  final double rigCostMult; // <1 = cheaper rigs while active (1.0 = none)
  final double prestigeGainMult; // >1 = more CX/GT gain while active (1.0 = none)
  final double guaranteedCritMult; // >0 = every real tap crits at this payout
  final bool forceBullRun; // instantly start a Bull Run
  final bool freeCrate; // open one free luck-weighted crate
  final int spawnAnomalies; // spawn N anomalies
  final double luckBuffMult; // temp luck ×N while active (1.0 = none)
  final bool resetBasicCooldowns; // SATOSHI MODE
  final bool suppressNegatives; // crash/hack/spike suppressed while active
  final bool costFreeze; // rig cost frozen while active
  final bool luckPinSweep; // SWEEP luck pinned to the EV ceiling while active
  final bool autoTaps; // auto-fire taps while active

  const AbilityDef({
    required this.id,
    required this.btcClass,
    required this.slot,
    required this.name,
    required this.description,
    required this.icon,
    required this.cooldownMs,
    required this.durationMs,
    this.tempMult = const {},
    this.instantIncomeSeconds = 0,
    this.rigCostMult = 1.0,
    this.prestigeGainMult = 1.0,
    this.guaranteedCritMult = 0,
    this.forceBullRun = false,
    this.freeCrate = false,
    this.spawnAnomalies = 0,
    this.luckBuffMult = 1.0,
    this.resetBasicCooldowns = false,
    this.suppressNegatives = false,
    this.costFreeze = false,
    this.luckPinSweep = false,
    this.autoTaps = false,
  });
}

/// The 12 abilities (3 per real class). [TUNE] against the build matrix.
const List<AbilityDef> kAbilities = [
  // --- Solo Miner: clicks / crit / luck ---
  AbilityDef(
    id: 'solo_overclock',
    btcClass: BtcClass.soloMiner,
    slot: AbilitySlot.basic1,
    name: 'Overclock the GPU',
    description: '45s: every tap is a guaranteed ×8 crit, click ×2.5.',
    icon: Icons.bolt,
    cooldownMs: GameConstants.abilityCdBasic1Ms,
    durationMs: 45 * 1000,
    tempMult: {Channel.click: 2.5},
    guaranteedCritMult: 8,
  ),
  AbilityDef(
    id: 'solo_lucky_nonce',
    btcClass: BtcClass.soloMiner,
    slot: AbilitySlot.basic2,
    name: 'Lucky Nonce',
    description: 'Open 1 free crate, luck ×3 for 5 min, spawn 3 anomalies.',
    icon: Icons.auto_awesome,
    cooldownMs: GameConstants.abilityCdBasic2Ms,
    durationMs: 5 * 60 * 1000,
    luckBuffMult: 3.0,
    freeCrate: true,
    spawnAnomalies: 3,
  ),
  AbilityDef(
    id: 'solo_block_race',
    btcClass: BtcClass.soloMiner,
    slot: AbilitySlot.ultimate,
    name: 'Block Race',
    description: '90s: auto-fire ~12 guaranteed-crit taps/s, click ×3.',
    icon: Icons.rocket_launch,
    cooldownMs: GameConstants.abilityCdUltimateMs,
    durationMs: 90 * 1000,
    tempMult: {Channel.click: 3.0},
    guaranteedCritMult: 8,
    autoTaps: true,
  ),

  // --- Corporation: raw hash / income / buy-power ---
  AbilityDef(
    id: 'corp_spin_up',
    btcClass: BtcClass.corporation,
    slot: AbilitySlot.basic1,
    name: 'Spin Up the Farm',
    description: '90s: hash ×2.5.',
    icon: Icons.dns,
    cooldownMs: GameConstants.abilityCdBasic1Ms,
    durationMs: 90 * 1000,
    tempMult: {Channel.hash: 2.5},
  ),
  AbilityDef(
    id: 'corp_capital_injection',
    btcClass: BtcClass.corporation,
    slot: AbilitySlot.basic2,
    name: 'Capital Injection',
    description: 'Instantly bank 30 minutes of income.',
    icon: Icons.savings,
    cooldownMs: GameConstants.abilityCdBasic2Ms,
    durationMs: 0,
    instantIncomeSeconds: 30 * 60,
  ),
  AbilityDef(
    id: 'corp_hostile_takeover',
    btcClass: BtcClass.corporation,
    slot: AbilitySlot.ultimate,
    name: 'Hostile Takeover',
    description: '10 min: income ×4 and rig cost ×0.5, plus a 2h income lump.',
    icon: Icons.corporate_fare,
    cooldownMs: GameConstants.abilityCdUltimateMs,
    durationMs: 10 * 60 * 1000,
    tempMult: {Channel.income: 4.0},
    rigCostMult: 0.5,
    instantIncomeSeconds: 2 * 60 * 60,
  ),

  // --- BTC OG: market / prestige / time ---
  AbilityDef(
    id: 'og_whale_order',
    btcClass: BtcClass.btcOg,
    slot: AbilitySlot.basic1,
    name: 'Whale Order',
    description: 'Force a Bull Run (income ×3 for 3 min).',
    icon: Icons.trending_up,
    cooldownMs: GameConstants.abilityCdBasic1Ms,
    durationMs: 0,
    forceBullRun: true,
  ),
  AbilityDef(
    id: 'og_deep_freeze',
    btcClass: BtcClass.btcOg,
    slot: AbilitySlot.basic2,
    name: 'Deep Freeze',
    description: '6 min: prestige gain ×1.75 on any fork you cash in.',
    icon: Icons.ac_unit,
    cooldownMs: GameConstants.abilityCdBasic2Ms,
    durationMs: 6 * 60 * 1000,
    prestigeGainMult: 1.75,
  ),
  AbilityDef(
    id: 'og_satoshi_mode',
    btcClass: BtcClass.btcOg,
    slot: AbilitySlot.ultimate,
    name: 'Satoshi Mode',
    description: 'Reset both basic cooldowns, then income ×2 & hash ×2 for 8 min.',
    icon: Icons.workspace_premium,
    cooldownMs: GameConstants.abilityCdUltimateMs,
    durationMs: 8 * 60 * 1000,
    tempMult: {Channel.income: 2.0, Channel.hash: 2.0},
    resetBasicCooldowns: true,
  ),

  // --- Pool Member: stability / SWEEP / steady ---
  AbilityDef(
    id: 'pool_steady_hands',
    btcClass: BtcClass.poolMember,
    slot: AbilitySlot.basic1,
    name: 'Steady Hands',
    description: '5 min: income ×2 and total crash immunity.',
    icon: Icons.pan_tool,
    cooldownMs: GameConstants.abilityCdBasic1Ms,
    durationMs: 5 * 60 * 1000,
    tempMult: {Channel.income: 2.0},
    suppressNegatives: true,
  ),
  AbilityDef(
    id: 'pool_pool_luck',
    btcClass: BtcClass.poolMember,
    slot: AbilitySlot.basic2,
    name: 'Pool Luck',
    description: '10 min: SWEEP luck pinned to the EV ceiling.',
    icon: Icons.groups,
    cooldownMs: GameConstants.abilityCdBasic2Ms,
    durationMs: 10 * 60 * 1000,
    luckPinSweep: true,
  ),
  AbilityDef(
    id: 'pool_consensus_rally',
    btcClass: BtcClass.poolMember,
    slot: AbilitySlot.ultimate,
    name: 'Consensus Rally',
    description: '10 min: income ×3, hash ×1.5, negatives suppressed, cost frozen.',
    icon: Icons.diversity_3,
    cooldownMs: GameConstants.abilityCdUltimateMs,
    durationMs: 10 * 60 * 1000,
    tempMult: {Channel.income: 3.0, Channel.hash: 1.5},
    suppressNegatives: true,
    costFreeze: true,
  ),
];

/// One active buff window (an ability whose duration hasn't elapsed).
class _Active {
  final AbilityDef def;
  final int expiryMs; // wall-clock
  _Active(this.def, this.expiryMs);
}

/// Owns ability cooldown state (wall-clock) + the active-buff windows. Pure
/// methods take `nowMs` so tests control time; GameLogic passes DateTime.now().
class AbilitySystem {
  /// Last-cast wall-clock time per ability id (drives cooldowns; persisted).
  final Map<String, int> lastUsedMs = {};
  final List<_Active> _active = [];

  List<AbilityDef> abilitiesFor(BtcClass c) =>
      kAbilities.where((a) => a.btcClass == c).toList();

  AbilityDef? byId(String id) {
    for (final a in kAbilities) {
      if (a.id == id) return a;
    }
    return null;
  }

  int _masteryGate(AbilitySlot slot) {
    switch (slot) {
      case AbilitySlot.basic1:
        return 0;
      case AbilitySlot.basic2:
        return GameConstants.abilityMasteryForBasic2;
      case AbilitySlot.ultimate:
        return GameConstants.abilityMasteryForUltimate;
    }
  }

  /// Unlocked once the player is that class AND has the required Mastery level.
  bool isUnlocked(AbilityDef def, BtcClass currentClass, int masteryLevel) =>
      def.btcClass == currentClass && masteryLevel >= _masteryGate(def.slot);

  /// Cooldown after RIG COOLING haste (capped + floored per slot).
  int effectiveCooldownMs(AbilityDef def, double haste) {
    final h = haste.clamp(0.0, GameConstants.hasteCap);
    final reduced = (def.cooldownMs * (1 - h)).round();
    final floor = def.slot == AbilitySlot.ultimate
        ? GameConstants.abilityCdFloorUltMs
        : GameConstants.abilityCdFloorBasicMs;
    return reduced < floor ? floor : reduced;
  }

  int cooldownRemainingMs(AbilityDef def, int nowMs, double haste) {
    final last = lastUsedMs[def.id];
    if (last == null) return 0;
    final remaining = effectiveCooldownMs(def, haste) - (nowMs - last);
    return remaining < 0 ? 0 : remaining;
  }

  bool isReady(AbilityDef def, int nowMs, double haste) =>
      cooldownRemainingMs(def, nowMs, haste) <= 0;

  /// Records the cast + opens the active-buff window (if durational). Caller must
  /// have validated unlock + readiness. [resetBasicCooldowns] clears the two
  /// basic cooldowns for the same class (SATOSHI MODE).
  void activate(AbilityDef def, int nowMs) {
    lastUsedMs[def.id] = nowMs;
    if (def.resetBasicCooldowns) {
      for (final a in abilitiesFor(def.btcClass)) {
        if (a.slot != AbilitySlot.ultimate) lastUsedMs.remove(a.id);
      }
    }
    if (def.durationMs > 0) {
      _active.add(_Active(def, nowMs + def.durationMs));
    }
  }

  void _prune(int nowMs) => _active.removeWhere((a) => a.expiryMs <= nowMs);

  /// Product of active abilities' temp multipliers on [channel] (1.0 if none).
  double tempMult(Channel channel, int nowMs) {
    _prune(nowMs);
    double m = 1.0;
    for (final a in _active) {
      final v = a.def.tempMult[channel];
      if (v != null) m *= v;
    }
    return m;
  }

  /// Temp luck multiplier from active buffs (Lucky Nonce) — 1.0 if none.
  double luckBuffMult(int nowMs) {
    _prune(nowMs);
    double m = 1.0;
    for (final a in _active) {
      if (a.def.luckBuffMult != 1.0) m *= a.def.luckBuffMult;
    }
    return m;
  }

  /// True if any active ability sets [test] (e.g. suppressNegatives).
  bool anyActive(int nowMs, bool Function(AbilityDef) test) {
    _prune(nowMs);
    return _active.any((a) => test(a.def));
  }

  /// Highest active prestige-gain multiplier (DEEP FREEZE), 1.0 if none.
  double activePrestigeGainMult(int nowMs) {
    _prune(nowMs);
    double m = 1.0;
    for (final a in _active) {
      if (a.def.prestigeGainMult > m) m = a.def.prestigeGainMult;
    }
    return m;
  }

  /// Rig-cost multiplier from active abilities (HOSTILE TAKEOVER ×0.5), 1.0 if
  /// none. A cost freeze is handled by the caller (returns the sticker price).
  double rigCostMult(int nowMs) {
    _prune(nowMs);
    double m = 1.0;
    for (final a in _active) {
      if (a.def.rigCostMult != 1.0) m *= a.def.rigCostMult;
    }
    return m;
  }

  /// Guaranteed-crit payout from an active ability (0 if none) — Solo abilities.
  double activeGuaranteedCritMult(int nowMs) {
    _prune(nowMs);
    double best = 0;
    for (final a in _active) {
      if (a.def.guaranteedCritMult > best) best = a.def.guaranteedCritMult;
    }
    return best;
  }

  bool get hasAnyActiveBuff => _active.isNotEmpty;

  /// Active buff windows with remaining ms (for the bar's ticker chips), soonest
  /// to expire first.
  List<({AbilityDef def, int remainingMs})> activeBuffs(int nowMs) {
    _prune(nowMs);
    final out = _active
        .map((a) => (def: a.def, remainingMs: a.expiryMs - nowMs))
        .where((e) => e.remainingMs > 0)
        .toList()
      ..sort((a, b) => a.remainingMs.compareTo(b.remainingMs));
    return out;
  }

  // ---- persistence -------------------------------------------------------
  Map<String, int> lastUsedJson() => Map<String, int>.from(lastUsedMs);

  void loadLastUsed(dynamic data) {
    lastUsedMs.clear();
    if (data is Map) {
      data.forEach((k, v) {
        if (k is String && v is num) lastUsedMs[k] = v.toInt();
      });
    }
  }

  /// Foreground buffs are cleared on reset (never persisted); cooldowns persist
  /// (wall-clock). A full Wipe clears cooldowns too.
  void clearActiveBuffs() => _active.clear();
  void wipeCooldowns() {
    lastUsedMs.clear();
    _active.clear();
  }
}
