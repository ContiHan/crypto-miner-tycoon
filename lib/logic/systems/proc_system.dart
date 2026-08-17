import 'dart:math';
import '../channels.dart';
import '../managers/class_manager.dart';

/// Events a proc can trigger on. The TIER (below) sets the ICD floor + effect
/// size band. A `synthetic` event (one a proc itself produced, or an auto-tap)
/// fires NO triggers — the GOLDEN RULE that breaks every proc→proc loop.
enum ProcEvent {
  onTap,
  onBlockFound,
  onCrit,
  onCritStreak, // N consecutive crit taps
  onAnomalyCollect,
  onGoodChaos,
  onBadChaos,
  onAbilityCast,
  onCrateOpen,
  onSoftFork,
  onHardFork,
  onHalving,
  onBreach,
  onGenesis,
}

enum ProcTier { hot, crit, warm, cold }

ProcTier _tierOf(ProcEvent e) {
  switch (e) {
    case ProcEvent.onTap:
    case ProcEvent.onBlockFound:
      return ProcTier.hot;
    case ProcEvent.onCrit:
    case ProcEvent.onCritStreak:
      return ProcTier.crit;
    case ProcEvent.onAnomalyCollect:
    case ProcEvent.onGoodChaos:
    case ProcEvent.onBadChaos:
    case ProcEvent.onAbilityCast:
      return ProcTier.warm;
    case ProcEvent.onCrateOpen:
    case ProcEvent.onSoftFork:
    case ProcEvent.onHardFork:
    case ProcEvent.onHalving:
    case ProcEvent.onBreach:
    case ProcEvent.onGenesis:
      return ProcTier.cold;
  }
}

/// ICD floor per tier (ms). HOT/CRIT are frequent so they get real cooldowns;
/// COLD events are already rare so they aren't extra-gated.
int _icdFloorMs(ProcTier t) {
  switch (t) {
    case ProcTier.hot:
      return 8000;
    case ProcTier.crit:
      return 6000;
    case ProcTier.warm:
      return 20000;
    case ProcTier.cold:
      return 0;
  }
}

/// The kinds of proc payoff. A GRANT is instant + supply-safe (never a permanent
/// stat/prestige currency). A BUFF is a short temp multiplier on the MERGED temp
/// axis (shared with abilities, aggregate-capped).
///   grantSats     — magnitude seconds of BASE income (spendable wallet only)
///   grantUtxo     — magnitude chips (bounded by the per-window UTXO cap #25)
///   grantCrateRoll— one free STANDARD crate (a bonus roll; still a chip SINK)
///   grantAnomaly  — force-spawn magnitude anomalies (chips gated by the cap)
///   grantCdRefund — shave magnitude (fraction) off ability cooldowns
///   buff          — temp channel multiplier on the merged axis
enum ProcEffectKind {
  grantSats,
  grantUtxo,
  grantCrateRoll,
  grantAnomaly,
  grantCdRefund,
  buff,
}

/// A single proc "signal": fires [effect] with [chance] on [event], no more than
/// once per [icdMs] (>= its tier floor).
class ProcSignal {
  final String id;
  final String name;
  final BtcClass? btcClass; // null = universal; else only while that class
  final ProcEvent event;
  final double chance; // 0..1
  final int icdMs;
  final ProcEffectKind kind;
  final double magnitude; // grantSats: seconds of BASE income; grantUtxo: chips
  final Channel? buffChannel; // for kind == buff
  final int buffDurationMs;

  const ProcSignal({
    required this.id,
    required this.name,
    required this.event,
    required this.chance,
    required this.kind,
    this.btcClass,
    int? icdMs,
    this.magnitude = 0,
    this.buffChannel,
    this.buffDurationMs = 0,
  }) : icdMs = icdMs ?? 0;

  int effectiveIcdMs() {
    final floor = _icdFloorMs(_tierOf(event));
    return icdMs < floor ? floor : icdMs;
  }
}

/// The result of a fired proc, applied by GameLogic.
class ProcResult {
  final ProcSignal signal;
  const ProcResult(this.signal);
}

/// Starter class-signature procs (always active for the matching class). STASH
/// firmware affixes socketed into the loadout are added on top (Slice 7b).
const List<ProcSignal> kProcSignals = [
  ProcSignal(
    id: 'proc_lucky_strike',
    name: 'Lucky Strike',
    btcClass: BtcClass.soloMiner,
    event: ProcEvent.onCrit,
    chance: 0.15,
    kind: ProcEffectKind.grantUtxo,
    magnitude: 2, // +2 UTXO on a lucky crit
  ),
  ProcSignal(
    id: 'proc_thermal_runaway',
    name: 'Thermal Runaway',
    btcClass: BtcClass.corporation,
    event: ProcEvent.onBlockFound,
    chance: 0.10,
    kind: ProcEffectKind.buff,
    buffChannel: Channel.hash,
    magnitude: 1.5, // hash ×1.5
    buffDurationMs: 8000,
  ),
  ProcSignal(
    id: 'proc_market_whisper',
    name: 'Market Whisper',
    btcClass: BtcClass.btcOg,
    event: ProcEvent.onGoodChaos,
    chance: 0.5,
    kind: ProcEffectKind.buff,
    buffChannel: Channel.income,
    magnitude: 1.3, // income ×1.3
    buffDurationMs: 10000,
  ),
  ProcSignal(
    id: 'proc_hedge_payout',
    name: 'Hedge Payout',
    btcClass: BtcClass.poolMember,
    event: ProcEvent.onBadChaos,
    chance: 0.5,
    kind: ProcEffectKind.grantSats,
    magnitude: 30, // 30s of base income banked when a bad event hits
  ),
];

class _ActiveProcBuff {
  final ProcSignal signal;
  final int expiryMs;
  _ActiveProcBuff(this.signal, this.expiryMs);
}

/// The trigger engine. Pure roll logic (takes nowMs + rng) with every
/// anti-runaway brake from CHAOS_DEPTH: Golden Rule, per-signal ICD, a global
/// token-bucket limiter (~8 resolutions / 10s), a per-tick cap (~3), and
/// offline-off (the caller simply never rolls offline).
class ProcSystem {
  static const int limiterWindowMs = 10000;
  static const int limiterMax = 8; // resolutions per window
  static const int perTickCap = 3;

  final Map<String, int> _lastFiredMs = {}; // per-signal ICD state
  final List<int> _recentResolutions = []; // token-bucket timestamps
  final List<_ActiveProcBuff> _activeBuffs = [];

  List<ProcSignal> signalsFor(BtcClass c) =>
      kProcSignals.where((s) => s.btcClass == null || s.btcClass == c).toList();

  /// Roll every eligible signal for [event]. Returns the effects that fired.
  /// [synthetic] events (proc-produced or auto-tap) fire NOTHING (Golden Rule).
  List<ProcResult> roll(
    ProcEvent event, {
    required BtcClass currentClass,
    required bool synthetic,
    required int nowMs,
    required Random rng,
  }) {
    if (synthetic) return const [];
    _pruneLimiter(nowMs);
    final results = <ProcResult>[];
    for (final s in signalsFor(currentClass)) {
      if (s.event != event) continue;
      if (results.length >= perTickCap) break; // per-tick cap
      if (_recentResolutions.length >= limiterMax) break; // token bucket
      // ICD.
      final last = _lastFiredMs[s.id];
      if (last != null && nowMs - last < s.effectiveIcdMs()) continue;
      // Chance.
      if (rng.nextDouble() >= s.chance) continue;
      // Fire.
      _lastFiredMs[s.id] = nowMs;
      _recentResolutions.add(nowMs);
      if (s.kind == ProcEffectKind.buff && s.buffDurationMs > 0) {
        _activeBuffs.add(_ActiveProcBuff(s, nowMs + s.buffDurationMs));
      }
      results.add(ProcResult(s));
    }
    return results;
  }

  void _pruneLimiter(int nowMs) {
    _recentResolutions
        .removeWhere((t) => nowMs - t >= limiterWindowMs);
  }

  void _pruneBuffs(int nowMs) =>
      _activeBuffs.removeWhere((b) => b.expiryMs <= nowMs);

  /// Product of active proc BUFFs on [channel] (1.0 if none) — merged with the
  /// ability temp axis by GameLogic under the shared aggregate ceiling.
  double tempMult(Channel channel, int nowMs) {
    _pruneBuffs(nowMs);
    double m = 1.0;
    for (final b in _activeBuffs) {
      if (b.signal.buffChannel == channel) m *= b.signal.magnitude;
    }
    return m;
  }

  bool get hasActiveBuff => _activeBuffs.isNotEmpty;

  /// Foreground buffs cleared on reset; ICD state is transient (short, session-
  /// scoped) so it isn't persisted.
  void clear() {
    _lastFiredMs.clear();
    _recentResolutions.clear();
    _activeBuffs.clear();
  }
}
