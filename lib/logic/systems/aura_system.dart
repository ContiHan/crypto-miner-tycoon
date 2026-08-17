import '../channels.dart';
import '../managers/class_manager.dart';

/// Auras & stances (CHAOS_DEPTH System B). An aura is a STATELESS conditional
/// passive — `WHILE <condition>: <bonus>` — applied live while true, banking
/// nothing. Because it's persistent it is ON-CHANNEL: it adds into the same
/// channel sums as TECH/STASH and obeys the base softcaps (no outside lane).
///
/// A build equips ONE exclusive STANCE (bigger, may carry a cost) + up to three
/// small AURAS, with a 60s switch lockout (anti-flicker). Progressive unlock:
/// stance + first aura available on class pick, +1 aura at Mastery 1 and 2.

enum AuraKind { stance, aura }

/// The live conditions an aura can key off. Evaluated each buildChannels() from
/// a cheap [AuraContext] snapshot.
enum AuraCondition {
  always, // structural (must carry a cost)
  whileBadEvent, // a crash / cost-spike / breach threat is active
  whileGoodEvent, // a bull run / airdrop / cheap-energy is active
  whileCalm, // no chaos event active
  whileNearCap, // > 75% of the 21M supply mined this era
  whileBreachPending, // a breach threat is telegraphing
}

/// Cheap snapshot of the world used to evaluate aura conditions.
class AuraContext {
  final bool goodEvent;
  final bool badEvent;
  final bool breachPending;
  final double supplyProgress;
  const AuraContext({
    required this.goodEvent,
    required this.badEvent,
    required this.breachPending,
    required this.supplyProgress,
  });

  bool matches(AuraCondition c) {
    switch (c) {
      case AuraCondition.always:
        return true;
      case AuraCondition.whileBadEvent:
        return badEvent || breachPending;
      case AuraCondition.whileGoodEvent:
        return goodEvent;
      case AuraCondition.whileCalm:
        return !goodEvent && !badEvent && !breachPending;
      case AuraCondition.whileNearCap:
        return supplyProgress > 0.75;
      case AuraCondition.whileBreachPending:
        return breachPending;
    }
  }
}

class AuraDef {
  final String id;
  final String name;
  final String description;
  final AuraKind kind;
  final BtcClass? btcClass; // null = universal
  final AuraCondition condition;
  final Map<Channel, double> bonuses; // positive = boon, negative = cost
  final int unlockMastery; // 0 = on class pick

  const AuraDef({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.condition,
    required this.bonuses,
    this.btcClass,
    this.unlockMastery = 0,
  });
}

/// The starter stance + aura set. Everything is ON-CHANNEL and stays within the
/// per-kind ceilings (see [AuraSystem.contributeChannels]).
const List<AuraDef> kAuras = [
  // --- Stances (exclusive; bigger, carry a cost) ---
  AuraDef(
    id: 'stance_overclock_protocol',
    name: 'Overclock Protocol',
    description: 'Always: +30% hash, +20% click — but −15% income (heat).',
    kind: AuraKind.stance,
    condition: AuraCondition.always,
    bonuses: {Channel.hash: 0.30, Channel.click: 0.20, Channel.income: -0.15},
  ),
  AuraDef(
    id: 'stance_storm_rigging',
    name: 'Storm Rigging',
    description: 'While a bad event hits: +50% income and +10% crash resist.',
    kind: AuraKind.stance,
    condition: AuraCondition.whileBadEvent,
    bonuses: {Channel.income: 0.50, Channel.crashResist: 0.10},
  ),
  AuraDef(
    id: 'stance_bull_rider',
    name: 'Bull Rider',
    description: 'While a good event runs: +40% income, +15% luck.',
    kind: AuraKind.stance,
    condition: AuraCondition.whileGoodEvent,
    bonuses: {Channel.income: 0.40, Channel.luck: 0.15},
  ),
  // --- Auras (small; up to 3) ---
  AuraDef(
    id: 'aura_calm_waters',
    name: 'Calm Waters',
    description: 'While no event is active: +10% income.',
    kind: AuraKind.aura,
    condition: AuraCondition.whileCalm,
    bonuses: {Channel.income: 0.10},
  ),
  AuraDef(
    id: 'aura_long_tail',
    name: 'The Long Tail',
    description: 'Past 75% of the supply mined: +15% hash, +10% income.',
    kind: AuraKind.aura,
    condition: AuraCondition.whileNearCap,
    unlockMastery: 1,
    bonuses: {Channel.hash: 0.15, Channel.income: 0.10},
  ),
  AuraDef(
    id: 'aura_vault_guard',
    name: 'Vault Guard',
    description: 'Always: +10% breach resistance.',
    kind: AuraKind.aura,
    condition: AuraCondition.always,
    unlockMastery: 2,
    bonuses: {Channel.theftResist: 0.10},
  ),
];

/// Owns the equipped stance + auras (persisted) with the 60s switch lockout, and
/// folds the ACTIVE ones' bonuses into the channel model.
class AuraSystem {
  // Per-kind ON-CHANNEL ceilings (routed into the existing shared softcaps).
  static const double stanceChannelCap = 0.75;
  static const double auraChannelCap = 0.20;
  static const double offChannelResistCap = 0.10;
  static const int maxAuras = 3;
  static const int switchLockoutMs = 60000;

  String? equippedStance;
  final List<String> equippedAuras = [];
  // Start "un-locked" (a fresh loadout can switch immediately); a real switch
  // stamps wall-clock time and the 60s lockout applies from there.
  int lastSwitchMs = -switchLockoutMs;

  AuraDef? byId(String id) {
    for (final a in kAuras) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<AuraDef> availableFor(BtcClass c, int masteryLevel) => kAuras
      .where((a) =>
          (a.btcClass == null || a.btcClass == c) &&
          masteryLevel >= a.unlockMastery)
      .toList();

  bool canSwitch(int nowMs) => nowMs - lastSwitchMs >= switchLockoutMs;
  int switchCooldownRemainingMs(int nowMs) {
    final r = switchLockoutMs - (nowMs - lastSwitchMs);
    return r < 0 ? 0 : r;
  }

  /// Equip/unequip a stance (toggle). FILLING an empty stance slot is free;
  /// SWAPPING to a different stance or CLEARING one is a real switch and honors
  /// the 60s anti-flicker lockout. Returns success.
  bool setStance(String? id, int nowMs) {
    final filling = equippedStance == null && id != null;
    if (!filling) {
      // Changing or clearing an equipped stance = a switch → rate-limited.
      if (!canSwitch(nowMs)) return false;
      lastSwitchMs = nowMs;
    }
    equippedStance = (equippedStance == id) ? null : id;
    return true;
  }

  /// Toggle an aura in/out of the (max 3) aura slots. ADDING into a free slot is
  /// free (so you can assemble a fresh loadout instantly); REMOVING one is the
  /// switch that arms the 60s lockout (anti-flicker). Adding at cap needs a free
  /// slot first, so it returns false until you remove one.
  bool toggleAura(String id, int nowMs) {
    if (equippedAuras.contains(id)) {
      // Removing = a switch → rate-limited + stamps the lockout.
      if (!canSwitch(nowMs)) return false;
      equippedAuras.remove(id);
      lastSwitchMs = nowMs;
      return true;
    }
    // Adding into a free slot is free (no lockout, no stamp).
    if (equippedAuras.length >= maxAuras) return false;
    equippedAuras.add(id);
    return true;
  }

  double _cap(AuraKind kind, Channel ch, double v) {
    // Off-channel resist/prestige lanes get the tighter cap; production channels
    // use the per-kind ceiling. Costs (negative) pass through unclamped.
    if (v <= 0) return v;
    final resistLike = ch == Channel.crashResist ||
        ch == Channel.costResist ||
        ch == Channel.halvingResist ||
        ch == Channel.durationResist ||
        ch == Channel.theftResist;
    final cap = resistLike
        ? offChannelResistCap
        : (kind == AuraKind.stance ? stanceChannelCap : auraChannelCap);
    return v > cap ? cap : v;
  }

  /// Adds the ACTIVE (condition-true) equipped stance + auras into [ch], each
  /// clamped to its per-kind on-channel ceiling. Purely additive — everything is
  /// then softcapped at the normal consumption sites (no outside lane).
  void contributeChannels(
      Channels ch, AuraContext ctx, BtcClass currentClass, int masteryLevel) {
    void apply(AuraDef? def) {
      if (def == null) return;
      if (def.btcClass != null && def.btcClass != currentClass) return;
      if (masteryLevel < def.unlockMastery) return;
      if (!ctx.matches(def.condition)) return;
      def.bonuses.forEach((channel, v) {
        ch.add(channel, _cap(def.kind, channel, v));
      });
    }

    apply(equippedStance == null ? null : byId(equippedStance!));
    for (final id in equippedAuras) {
      apply(byId(id));
    }
  }

  // ---- persistence -------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'stance': equippedStance,
        'auras': List<String>.from(equippedAuras),
        'lastSwitchMs': lastSwitchMs,
      };

  void loadFrom(dynamic data) {
    equippedStance = null;
    equippedAuras.clear();
    lastSwitchMs = 0;
    if (data is Map) {
      final s = data['stance'];
      if (s is String) equippedStance = s;
      final a = data['auras'];
      if (a is List) {
        equippedAuras.addAll(a.whereType<String>().take(maxAuras));
      }
      final t = data['lastSwitchMs'];
      if (t is num) lastSwitchMs = t.toInt();
    }
  }

  void reset() {
    equippedStance = null;
    equippedAuras.clear();
    lastSwitchMs = 0;
  }
}
