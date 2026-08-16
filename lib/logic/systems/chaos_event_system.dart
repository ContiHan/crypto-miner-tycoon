import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/news_event.dart';
import '../../content/news_flavor.dart';

/// Random market "chaos" events and the news-ticker banner.
///
/// Extracted from the GameLogic god-object. Owns the chaos income/cost
/// multipliers and the current news event on independent cancellable timers
/// (so a halving banner can't strand a multiplier, and back-to-back same-type
/// events don't cancel each other early). GameLogic supplies the callbacks.
class ChaosEventSystem {
  double incomeMultiplier = 1.0;
  double costMultiplier = 1.0;
  NewsEvent? currentNews;

  Timer? _scheduleTimer;
  // Income and cost buffs expire on INDEPENDENT timers so orthogonal events
  // (e.g. a Bull Run and Cheap Energy) don't cut each other short.
  Timer? _incomeResetTimer;
  Timer? _costResetTimer;
  Timer? _newsTimer;
  final _random = Random();

  final void Function() onChanged; // notifyListeners
  final double Function() onHackLoss; // deduct wallet, return loss amount
  final double Function() onAirdropGain; // credit wallet, return gain amount
  final void Function(bool good) onEventSound;

  /// Volatility factor (>=1 raises event frequency, <1 lowers it) read at each
  /// reschedule. Default 1.0 keeps the original cadence. (Sources arrive with
  /// classes: e.g. Pool Member lowers it, others raise it.)
  final double Function()? volatilityFactor;

  /// Applies resistances to a rolled event, returning the mitigated
  /// (income, cost, durationSeconds). Supplied by GameLogic (owns the channels +
  /// the combined-mitigation cap). Null = no mitigation (raw event).
  final (double, double, int) Function(
      EventType type, double income, double cost, int durationSeconds)? applyResistances;

  ChaosEventSystem({
    required this.onChanged,
    required this.onHackLoss,
    required this.onAirdropGain,
    required this.onEventSound,
    this.volatilityFactor,
    this.applyResistances,
  });

  void start() {
    // Higher volatility => shorter gap between events. Clamped so it never
    // spams or stalls.
    final double v = (volatilityFactor?.call() ?? 1.0).clamp(0.5, 3.0);
    final int next =
        ((60 + _random.nextInt(240)) / v).round().clamp(20, 600);
    _scheduleTimer = Timer(Duration(seconds: next), () {
      triggerRandom();
      start(); // reschedule
    });
  }

  void stop() {
    _scheduleTimer?.cancel();
    _incomeResetTimer?.cancel();
    _costResetTimer?.cancel();
    _newsTimer?.cancel();
    // A cancelled reset timer must not strand an active chaos multiplier — and
    // the banner must not outlive it (else a stale "BULL RUN +100%" lingers on
    // resume while the multiplier is already back to 1.0).
    incomeMultiplier = 1.0;
    costMultiplier = 1.0;
    currentNews = null;
  }

  // The random-event pool. EventType.info is EXCLUDED — it's a neutral banner
  // type used only for manual notices (e.g. the halving), never a rolled event.
  static const List<EventType> _randomTypes = [
    EventType.bullRun,
    EventType.marketCrash,
    EventType.airdrop,
    EventType.hack,
    EventType.cheapEnergy,
    EventType.costSpike,
  ];

  void triggerRandom() {
    final type = _randomTypes[_random.nextInt(_randomTypes.length)];
    double income = 1.0, cost = 1.0, value = 0;
    String message = '';
    int duration = 30;
    Color color = Colors.white;

    switch (type) {
      case EventType.airdrop:
        value = onAirdropGain(); // +wallet (opposite of hack)
        color = Colors.amberAccent;
        duration = 45;
        break;
      case EventType.marketCrash:
        income = 0.5;
        value = -50;
        color = Colors.redAccent;
        duration = 90 + _random.nextInt(60);
        break;
      case EventType.bullRun:
        income = 2.0;
        value = 100;
        color = Colors.greenAccent;
        duration = 90 + _random.nextInt(60);
        break;
      case EventType.hack:
        value = -onHackLoss();
        color = Colors.red;
        duration = 45;
        break;
      case EventType.cheapEnergy:
        cost = 0.7; // rigs 30% cheaper
        value = -30;
        color = Colors.cyanAccent;
        duration = 120;
        break;
      case EventType.costSpike:
        cost = 1.5; // rigs 50% pricier (opposite of cheap energy)
        value = 50;
        color = Colors.deepOrangeAccent;
        duration = 120;
        break;
      case EventType.info:
        break; // never rolled (excluded above); here only for exhaustiveness
    }

    // Apply resistances (Diamond Hands / Fee Hedge / Steel Nerves) before the
    // event lands — softens crash magnitude / cost surcharge and shortens their
    // duration, always leaving >= 30% of the base impact (combined cap).
    if (applyResistances != null) {
      final r = applyResistances!(type, income, cost, duration);
      income = r.$1;
      cost = r.$2;
      duration = r.$3;
    }

    // Pick a random flavour line for this event type.
    final pool = NewsFlavor.byType[type]!;
    message = pool[_random.nextInt(pool.length)];

    _applyChaos(income, cost, duration);
    showNews(
      NewsEvent(
        message: message,
        type: type,
        value: value,
        durationSeconds: duration,
        color: color,
      ),
    );
    // Positive jingle only for the player-FAVOURABLE events; every debuff
    // (marketCrash, hack, AND costSpike) plays the bad cue.
    onEventSound(type == EventType.bullRun ||
        type == EventType.airdrop ||
        type == EventType.cheapEnergy);
  }

  /// Shows a ticker event and schedules its expiry. The identity guard means a
  /// later event replacing this one cannot clear the wrong banner.
  void showNews(NewsEvent event) {
    currentNews = event;
    onChanged();
    _newsTimer?.cancel();
    _newsTimer = Timer(Duration(seconds: event.durationSeconds), () {
      if (identical(currentNews, event)) {
        currentNews = null;
        onChanged();
      }
    });
  }

  void _applyChaos(double income, double cost, int durationSeconds) {
    // Apply and expire each axis independently. A value of 1.0 means "this event
    // doesn't touch this axis" — so a no-op/flavour event (info) or a wallet-only
    // event (hack) leaves any active buff/debuff running instead of wiping it,
    // and an income event never resets an active cost buff (or vice-versa). On
    // the same axis, the newer event wins (its timer replaces the old one).
    if (income != 1.0) {
      incomeMultiplier = income;
      _incomeResetTimer?.cancel();
      _incomeResetTimer = Timer(Duration(seconds: durationSeconds), () {
        incomeMultiplier = 1.0;
        onChanged();
      });
    }
    if (cost != 1.0) {
      costMultiplier = cost;
      _costResetTimer?.cancel();
      _costResetTimer = Timer(Duration(seconds: durationSeconds), () {
        costMultiplier = 1.0;
        onChanged();
      });
    }
  }

  /// Force a Bull Run (OG WHALE ORDER ability): income ×3 for 3 min, with the
  /// ticker banner + positive cue. Resistances don't apply to a positive event.
  void forceBullRun() {
    const income = 3.0;
    const duration = 180;
    _applyChaos(income, 1.0, duration);
    final pool = NewsFlavor.byType[EventType.bullRun]!;
    showNews(NewsEvent(
      message: pool[_random.nextInt(pool.length)],
      type: EventType.bullRun,
      value: 200,
      durationSeconds: duration,
      color: Colors.greenAccent,
    ));
    onEventSound(true);
  }

  /// Test seam for the per-axis apply/expiry logic (avoids relying on the random
  /// event roll). Not used in production.
  @visibleForTesting
  void applyChaosForTest(double income, double cost, int durationSeconds) =>
      _applyChaos(income, cost, durationSeconds);
}
