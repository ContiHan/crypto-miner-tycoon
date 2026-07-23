import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/news_event.dart';

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
  Timer? _chaosResetTimer;
  Timer? _newsTimer;
  final _random = Random();

  final void Function() onChanged; // notifyListeners
  final double Function() onHackLoss; // deduct wallet, return loss amount
  final void Function(bool good) onEventSound;

  ChaosEventSystem({
    required this.onChanged,
    required this.onHackLoss,
    required this.onEventSound,
  });

  void start() {
    final next = 60 + _random.nextInt(240);
    _scheduleTimer = Timer(Duration(seconds: next), () {
      triggerRandom();
      start(); // reschedule
    });
  }

  void stop() {
    _scheduleTimer?.cancel();
    _chaosResetTimer?.cancel();
    _newsTimer?.cancel();
    // A cancelled reset timer must not strand an active chaos multiplier — and
    // the banner must not outlive it (else a stale "BULL RUN +100%" lingers on
    // resume while the multiplier is already back to 1.0).
    incomeMultiplier = 1.0;
    costMultiplier = 1.0;
    currentNews = null;
  }

  void triggerRandom() {
    final type = EventType.values[_random.nextInt(EventType.values.length)];
    double income = 1.0, cost = 1.0, value = 0;
    String message = '';
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
        income = 0.5;
        value = -50;
        color = Colors.redAccent;
        duration = 90 + _random.nextInt(60);
        break;
      case EventType.bullRun:
        message = "BULL RUN: Institutional investors entering!";
        income = 2.0;
        value = 100;
        color = Colors.greenAccent;
        duration = 90 + _random.nextInt(60);
        break;
      case EventType.hack:
        message = "SECURITY BREACH: Hot wallet compromised!";
        value = -onHackLoss();
        color = Colors.red;
        duration = 45;
        break;
      case EventType.cheapEnergy:
        message = "Surplus Energy: Electricity costs drop significantly.";
        cost = 0.7;
        value = -30;
        color = Colors.cyanAccent;
        duration = 120;
        break;
    }

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
    onEventSound(type != EventType.marketCrash && type != EventType.hack);
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
    incomeMultiplier = income;
    costMultiplier = cost;
    _chaosResetTimer?.cancel();
    if (income != 1.0 || cost != 1.0) {
      _chaosResetTimer = Timer(Duration(seconds: durationSeconds), () {
        incomeMultiplier = 1.0;
        costMultiplier = 1.0;
        onChanged();
      });
    }
  }
}
